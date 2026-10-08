extends Node
## Doc 05 section 19 "Bots", doc 01 "Testing > Bot teammates": one bot teammate, host only. A Player
## with a script instead of input: it streams `move` frames into the host's `Players` and asks for
## holds through `Net.request_received`, the path a client's RPC takes. So the speed check, footstep
## Noise, hold validation, stillness, death and the trap race treat it like any player.
## DD Phase 1 bots walk and do chores (P1-13). Playing clips waits for voice clips (DD Phase 2+).

const Route := preload("res://game/bots/bot_route.gd")
const Frame := preload("res://game/player/move_frame.gd")
const Plot := preload("res://game/farming/plot.gd")

const REFUEL_BELOW := 0.5  ## refuel when one can (fuel_can_pct 50%, doc 02 section 14) fits in the tank
const HOLD_SLACK_S := 4.0  ## wait past hold_s for the host's answer, as the QA autochore does
const REFUSED_WAIT_S := 1.0  ## placeholder: pause after a refusal so a bot never spins
const IDLE_S := Vector2(2.0, 6.0)  ## placeholder: idle pause range between strolls
## Where a bot stands to hold each target: inside `range_m` 2.0 (doc 05 section 7), outside walls.
const STAND := {"sell_box": Vector3(-1.6, 0, 0), "well": Vector3(1.6, 0, 0), "fuel_drum": Vector3(-1.5, 0, 0),
		"generator": Vector3(-1.5, 0, 0)}
const PLOT_STAND := Vector3(0, 0, 1.5)  ## between plot rows (rows 3 m apart, doc 04 section 9)
## Open ground to stroll to when there is no chore (doc 04 section 9: yard, field A's edges, the well).
const IDLE_SPOTS := [Vector3(0, 0, 6), Vector3(22, 0, 0), Vector3(30, 0, 1), Vector3(-20, 0, 8)]

var peer := 0
var players: Node
var farm: Node
var claims: Dictionary  ## shared by every bot (Bots): target id -> bot peer, so two bots never pick the same plot
var rng := RandomNumberGenerator.new()

var _pos := Vector3.ZERO
var _yaw := 0.0
var _path: Array = []
var _seq := 0
var _send_t := 0.0


func _ready() -> void:
	_pos = players.player(peer).global_position  # the spawn marker Players picked
	if not Game.full_farm:  # P2-07: bot_route.gd is Phase 1 only; on the full farm a bot spawns and stands
		_run.call_deferred()


func _physics_process(delta: float) -> void:
	if Game.is_ghost(peer):
		_path.clear()  # a dead bot stops where it fell
	if not _path.is_empty():
		var d: Vector3 = _path[0] - _pos
		d.y = 0.0
		var step := Data.speed(&"walk") * delta
		if d.length() <= step:
			_pos = Vector3(_path[0].x, _pos.y, _path[0].z)
			_path.pop_front()
		else:
			_pos += d.normalized() * step
			_yaw = atan2(-d.x, -d.z)
	_send_t += delta
	var ticks := floori(_send_t * players.SEND_HZ)
	if ticks >= 1:
		# seq counts send intervals of game time, so `--time-scale` (long physics steps) never reads
		# as a speed spike in the host's dt.
		_send_t -= ticks / players.SEND_HZ
		_seq += ticks
		# Same frame bytes a client's `move` packet carries, into the host's ingest.
		players.submit(peer, Frame.unpack(Frame.pack(_seq, _pos, _yaw, 0.0, false, false), 1))
		_pos = Game.players[peer].pos  # the host's kept position wins, as `apply_teleport` does for a client


func _run() -> void:
	await _wait(rng.randf_range(1.0, 3.0))  # stagger bots
	while is_inside_tree():
		if Game.is_ghost(peer):
			await _wait(1.0)
			continue
		var job := next_job()
		if job.is_empty():
			await _walk(IDLE_SPOTS[rng.randi() % IDLE_SPOTS.size()])
			await _wait(rng.randf_range(IDLE_S.x, IDLE_S.y))
			continue
		claims[job[1]] = peer
		await _do(job[0], job[1])
		claims.erase(job[1])


## Host state only, never positions of anything but the bot: [verb, target id], or [] for nothing to do.
func next_job() -> Array:
	var st: Dictionary = farm.pstate(peer)
	if Clock.phase in [&"dusk", &"night"] and farm.targets.has("generator") and _free("generator"):
		var gen: Node = farm.targets["generator"].gen
		if gen.damaged:
			return [&"repair_generator", "generator"]
		if gen.fuel_s < gen.tank_s * REFUEL_BELOW:
			return [&"refuel", "generator"] if bool(st.get("fuel_can", false)) else [&"fill_fuel", "fuel_drum"]
	var ripe := _plots(func(p: Node) -> bool: return p.state == &"ripe")
	var bag := int(st.get("bag", 0))
	if bag > 0 and (bag >= int(Data.value(&"labor", &"carry", &"capacity")) or ripe.is_empty()):
		return [&"sell", "sell_box"]
	if not ripe.is_empty():
		return [&"harvest", ripe[0].id]
	var empty := _plots(func(p: Node) -> bool: return p.state == &"empty")
	if not empty.is_empty():
		return [&"plant", empty[0].id]
	var dry := _plots(func(p: Node) -> bool: return p.state == &"growing" and not p.watered)
	if not dry.is_empty():
		return [&"water", dry[0].id] if int(st.get("can", 0)) > 0 else [&"fill_can", "well"]
	return []


## Unlocked plots no other bot has claimed that match `pick`, nearest first.
func _plots(pick: Callable) -> Array:
	var out: Array = farm.targets.values().filter(func(t: Node) -> bool:
		return t is Plot and not t.locked and _free(t.id) and pick.call(t))
	out.sort_custom(func(a: Node, b: Node) -> bool:
		return _pos.distance_squared_to(a.target_pos()) < _pos.distance_squared_to(b.target_pos()))
	return out


func _free(id: String) -> bool:
	return claims.get(id, peer) == peer


func _do(verb: StringName, id: String) -> void:
	var t: Node = farm.targets[id]
	await _walk(t.target_pos() + (PLOT_STAND if t is Plot else STAND.get(id, Vector3.ZERO)))
	if Game.is_ghost(peer):
		return
	Net.request_received.emit(&"hold", peer, [verb, id])  # what Net's `request_hold` RPC emits
	if not farm.registry.holds.has(peer):  # refused; the host logged `hold_refused` with the reason
		await _wait(REFUSED_WAIT_S)
		return
	var timeout := get_tree().create_timer(Data.hold_s(verb) + HOLD_SLACK_S)
	while farm.registry.holds.has(peer) and timeout.time_left > 0.0:
		await get_tree().physics_frame
	if farm.registry.holds.has(peer):
		Net.request_received.emit(&"hold_cancel", peer, [])


func _walk(to: Vector3) -> void:
	_path = Route.path(_pos, to)
	while not _path.is_empty() and not Game.is_ghost(peer):
		await get_tree().physics_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
