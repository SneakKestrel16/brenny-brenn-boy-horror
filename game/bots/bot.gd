extends Node
## Doc 05 section 19 "Bots", doc 01 "Testing > Bot teammates": one bot teammate, host only. A Player
## with a script instead of input: it streams `move` frames into the host's `Players` and asks for
## holds through `Net.request_received`, the path a client's RPC takes. So the speed check, footstep
## Noise, hold validation, stillness, death and the trap race treat it like any player.
## DD Phase 1 bots walk and do chores (P1-13). Playing clips waits for voice clips (DD Phase 2+).
## P3-06: a Tainted bot washes (Q-061), and bots fix sabotage (sabotage.gd `fix_jobs`). On the full farm
## bots stand unless `--bot-chores`: then they walk straight lines (no collision, no route) and do all of it.
## P4-11 (D-085): a damage fix spends scrap, so bots buy scrap when the team has none.
## P4-22 (D-093): planting uses a seed from the team's stock, so bots buy one seed when the team has none.
## P4-12: on the Harvest Moon a bot lifts the Prize Pumpkin, loads it on the cart and pushes, walking with the cart.
## P4-21: from dusk to dawn bots wait in the lit barn (generator jobs aside) and one waits at the town stand
## (safer, never safe: D-115), so the farm is never unattended; bots keep the first payment before buying
## seeds, plant and water the Prize Pumpkin, pry themselves out of a bear trap, and move only on send steps.
## P5-57 (CEO 2026-10-10 "improve overall AI"): on the full farm bots do chores by default, walk a grid around walls
## (bot_grid.gd), open any closed door with the `open_door` hold, ask the store before buying a seed and follow the
## moving cart. Each change has a flag in ai_director.json `bots` (false is the behaviour before P5-57).

const Route := preload("res://game/bots/bot_route.gd")
const Frame := preload("res://game/player/move_frame.gd")
const Plot := preload("res://game/farming/plot.gd")
const Crops := preload("res://game/farming/crops.gd")
const Interactable := preload("res://game/interaction/interactable.gd")

const REFUEL_BELOW := 0.5  ## refuel when one can (fuel_can_pct 50%, doc 02 section 14) fits in the tank
const SCRAP_JOBS := [&"repair_generator", &"bury", &"pull_seeds", &"repair_fence"]  ## D-085: each spends 1 scrap
const HOLD_SLACK_S := 4.0  ## wait past hold_s for the host's answer, as the QA autochore does
const REFUSED_WAIT_S := 1.0  ## placeholder: pause after a refusal so a bot never spins
const IDLE_S := Vector2(2.0, 6.0)  ## placeholder: idle pause range between strolls
## Where a bot stands to hold each target: inside `range_m` 2.0 (doc 05 section 7), outside walls.
const STAND := {"sell_box": Vector3(-1.6, 0, 0), "well": Vector3(1.6, 0, 0), "fuel_drum": Vector3(-1.5, 0, 0),
		"generator": Vector3(-1.5, 0, 0), "prize_pumpkin": Vector3(1.5, 0, 0)}
const PLOT_STAND := Vector3(0, 0, 1.5)  ## between plot rows (rows 3 m apart, doc 04 section 9)
const FIX_STAND := Vector3(1.2, 0, 0)  ## beside a dead crow or strange seeds, outside Taint's 0.8 m touch
## Open ground to stroll to when there is no chore (doc 04 section 9: yard, field A's edges, the well).
const IDLE_SPOTS := [Vector3(0, 0, 6), Vector3(22, 0, 0), Vector3(30, 0, 1), Vector3(-20, 0, 8)]
## P4-21: from dusk to dawn bots wait in the barn, lit while the generator runs (doc 03 s6: the creature never
## enters a lit building). Barn floor x -8..8, z -20..0, door at the origin facing +Z (farm.tscn, doc 04 s8).
const BARN := Rect2(-8, -20, 16, 20)
const BARN_DOOR_OUT := Vector3(0, 0, 2)
const SHELTER_SPOT := Vector3(0, 0, -5)
## P4-21 night trips, seconds (placeholders sized to doc 03 s18's 60 s scripted lurk, phase1.json `scripted_lurk_s`):
## ready the fuel can from FUEL_PREP_S before dusk, pour it from REFUEL_AT_S into the night (the tank is full until
## dusk: generator.gd refuses `tank_full`), and be back inside the barn by HOME_BY_S.
const FUEL_PREP_S := 30.0
const REFUEL_AT_S := 35.0
const HOME_BY_S := 50.0

var peer := 0
var players: Node
var farm: Node
var claims: Dictionary  ## shared by every bot (Bots): target id -> bot peer, so two bots never pick the same plot
var bots: Node  ## the Bots node: its shared walk grid (P5-57)
var rng := RandomNumberGenerator.new()

var _pos := Vector3.ZERO
var _yaw := 0.0
var _path: Array = []
var _seq := 0
var _send_t := 0.0
var _pin_t := 0.0


func _ready() -> void:
	_pos = players.player(peer).global_position  # the spawn marker Players picked
	# P2-07: bot_route.gd is Phase 1 only. P5-57 `chores_default`: never under a `-s` test script, whose bots stand still.
	if not Game.full_farm or OS.get_cmdline_user_args().has("--bot-chores") or (knob(&"chores_default") and get_tree().get_script() == null):
		_run.call_deferred()


## P5-57: a field of ai_director.json `bots`, false when the table is not loaded or with `--bot-knobs-off` (every flag
## off: the behaviour before P5-57, for a same-seed comparison) or `--bot-knob-off=a,b` (those flags off).
static func knob(field: StringName) -> Variant:
	if not Data.has_table(&"ai_director"):
		return false
	for a: String in OS.get_cmdline_user_args():
		if a == "--bot-knobs-off" or (a.begins_with("--bot-knob-off=") and field in a.trim_prefix("--bot-knob-off=").split(",")):
			return false
	return Data.record(&"ai_director", &"bots").get(field, false)


func _physics_process(delta: float) -> void:
	if Game.is_ghost(peer):
		_path.clear()  # a dead bot stops where it fell
	_pry(delta)
	_send_t += delta
	var ticks := floori(_send_t * players.SEND_HZ)
	if ticks >= 1:
		# seq counts send intervals of game time, so `--time-scale` (long physics steps) never reads
		# as a speed spike in the host's dt.
		_send_t -= ticks / players.SEND_HZ
		_seq += ticks
		# P4-21: move only on send steps, walk x ticks / SEND_HZ, so a frame never covers more than the
		# host's dt allows (moving every physics step outran it under `--time-scale 8`).
		_step(Data.speed(&"walk") * float(Game.players[peer].get("speed_mult", 1.0)) * ticks / players.SEND_HZ)
		# Same frame bytes a client's `move` packet carries, into the host's ingest.
		players.submit(peer, Frame.unpack(Frame.pack(_seq, _pos, _yaw, 0.0, false, false), 1))
		_pos = Game.players[peer].pos  # the host's kept position wins, as `apply_teleport` does for a client


## P4-21 (doc 03 s7): pinned in a bear trap, pry it at once, as hold_controller's `_autopry` does for a client.
## The trap id is in `trap_race.victims`, which every peer gets with the `trap_race` broadcast.
func _pry(delta: float) -> void:
	if not bool(Game.players[peer].get("pinned", false)) or Game.is_ghost(peer):
		_pin_t = 0.0
		return
	_pin_t += delta
	if _pin_t < 0.3 or farm.registry.holds.has(peer):  # after the spring cancels the chore hold
		return
	var race := get_tree().get_first_node_in_group(&"trap_race")
	for id: String in race.victims:
		if race.victims[id] == peer and farm.targets.has(id):
			Net.request_received.emit(&"hold", peer, [&"pry", id])
			_pin_t = -1000.0  # once per trap


## P5-55: a bot moves by position, not move_and_slide, so it honours the barn door itself (the door is at the origin, see BARN).
## A step across a closed doorway stops it at the threshold and it opens the door (host only, as a player's `open_door`).
## P5-57 `door_hold`: every door, in the door marker's frame (the gap runs along local x, the door plane is local z 0), and the
## bot holds `open_door` as a player does (range and sight checked by the host); the host's word alone only if refused.
func _door_stops(a: Vector3, b: Vector3) -> bool:
	var doors := get_tree().root.get_node_or_null(^"Main/Doors") as Doors
	if doors == null:
		return false
	if not knob(&"door_hold"):
		if (a.z > 0.0) == (b.z > 0.0) or absf((a.x + b.x) * 0.5) > Doors.GAP_M * 0.5 or doors.open.get("door_barn", true):
			return false
		doors.host_set("door_barn", true, peer)
		return true
	for id: String in doors.open:
		if doors.open[id] or not farm.targets.has(id):
			continue
		var frame := (farm.targets[id].get_parent() as Node3D).global_transform.affine_inverse()
		var la := frame * a
		var lb := frame * b
		if (la.z > 0.0) == (lb.z > 0.0) or absf((la.x + lb.x) * 0.5) > Doors.GAP_M * 0.5:
			continue
		var h: Dictionary = farm.registry.holds.get(peer, {})
		if h.is_empty():
			Net.request_received.emit(&"hold", peer, [&"open_door", id])  # what Net's `request_hold` RPC emits
			h = farm.registry.holds.get(peer, {})
		if h.get("verb", &"") != &"open_door":
			doors.host_set(id, true, peer)  # refused, or busy with another hold (pushing the cart)
		return true
	return false


## Walk `dist` metres along the path, turning at each point.
func _step(dist: float) -> void:
	while dist > 0.0 and not _path.is_empty():
		var d: Vector3 = _path[0] - _pos
		d.y = 0.0
		var to: Vector3 = _path[0] if d.length() <= dist else _pos + d.normalized() * dist
		if _door_stops(_pos, to):
			return  # the door is open next step
		if d.length() <= dist:
			dist -= d.length()
			_pos = Vector3(_path[0].x, _pos.y, _path[0].z)
			_path.pop_front()
		else:
			_pos += d.normalized() * dist
			_yaw = atan2(-d.x, -d.z)
			dist = 0.0


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
		if job[0] == &"shelter":
			var spot := SHELTER_SPOT + Vector3(2.0 * (absi(peer) % 4) - 3.0, 0, 0)  # side by side, never on one spot
			_path = [spot] if BARN.has_point(Vector2(_pos.x, _pos.z)) else [BARN_DOOR_OUT, spot]  # in by the door, not through a wall
			if bots and bots.grid():
				_path = bots.grid().path(_pos, spot)
			while not _path.is_empty() and not Game.is_ghost(peer):
				await get_tree().physics_frame
			await _wait(1.0)
			continue
		if job[0] == &"sentinel":  # 4 m inside the town stand's 10 m radius (farm.tscn `Sanctuary`, D-115)
			await _walk((get_tree().get_first_node_in_group(&"sanctuary") as Node3D).global_position + Vector3(-4, 0, 0))
			await _wait(1.0)
			continue
		claims[job[1]] = peer
		if job[0] == &"tend":  # P4-21: wait by the generator with the full fuel can, or by a moonflower
			await _walk(_stand(job[1]))
			await _wait(1.0)
		elif job[0] == &"push_cart":
			await _push()
		else:
			await _do(job[0], job[1])
		claims.erase(job[1])


## Host state only, never positions of anything but the bot: [verb, target id], or [] for nothing to do.
func next_job() -> Array:
	var st: Dictionary = farm.pstate(peer)
	if bool(st.get("tainted", false)) and _free("well") and Clock.phase != &"night":
		return [&"wash", "well"]  # Q-061: Taint ends with a wash at the well
	if Clock.phase == &"harvest_moon" and farm.get(&"cart"):  # P4-12: doc 03 s14 acts 1 to 3
		var cart: Node = farm.cart
		if bool(st.get("held_prize", false)):
			return [&"load_cart", "cart"]
		if cart.act == cart.LOADING and _free("prize_pumpkin") and farm.targets.has("prize_pumpkin") and &"lift_prize" in farm.targets["prize_pumpkin"].verbs_for(st):
			if int(st.get("held_can", -1)) >= 0:
				return [&"drop_can", "can_%d" % int(st.held_can)]  # P4-21: lifting needs both hands (`hands_full`)
			if bool(st.get("shovel", false)) and farm.targets.has("pegboard"):
				return [&"return_shovel", "pegboard"]
			return [&"lift_prize", "prize_pumpkin"]
		if cart.can_start(&"push_cart", st) == &"":
			return [&"push_cart", "cart"]  # every bot pushes: no claim on the cart
	if not Game.full_farm and Clock.phase in [&"dusk", &"night"] and farm.targets.has("generator") and _free("generator"):
		var gen: Node = farm.targets["generator"].gen
		var low: bool = gen.fuel_s < gen.tank_s * REFUEL_BELOW
		if gen.damaged and _scrap_ok():
			return [&"repair_generator", "generator"]
		if low and bool(st.get("fuel_can", false)):
			return [&"refuel", "generator"]
		if low:
			if st.get("held_kind", &"") != &"fuel":
				return _fetch(st, &"fuel")
			return [&"fill_fuel", "fuel_drum"]
	if Game.full_farm and (Clock.phase in [&"dusk", &"night"] or Clock.length_of(&"day") - Clock.t_phase < FUEL_PREP_S):
		var job := _night_job(st)
		if not job.is_empty():
			return job
	var pk: Node = farm.targets.get("prize_pumpkin")
	if pk and _free("prize_pumpkin") and not pk.judged:  # P4-21: plant and water it daily, so judging has a pumpkin
		if pk.can_start(&"plant", st) == &"":
			return [&"plant", "prize_pumpkin"]
		if pk.planted and not pk.watered:
			if st.get("held_kind", &"") != &"water":
				return _fetch(st, &"water")
			return [&"water_prize_pumpkin", "prize_pumpkin"] if int(st.get("can", 0)) > 0 else [&"fill_can", "well"]
	var sab := get_tree().get_first_node_in_group(&"sabotage")
	for job: Array in (sab.fix_jobs() if sab else []):
		if not _free(job[1]) or not farm.targets.has(job[1]) or (job[0] in SCRAP_JOBS and not _scrap_ok()):
			continue
		if job[0] == &"plant" and not (_keeps_payment(farm.targets[job[1]]) and _plantable(farm.targets[job[1]], st)):
			continue  # P4-18: a trampled plot with no coins for the seed; spinning on it starved the harvest
		if job[0] == &"bury" and not bool(st.get("shovel", false)) and farm.targets.has("pegboard"):
			return [&"take_shovel", "pegboard"]
		if job[0] == &"take_can" and int(st.get("held_can", -1)) >= 0:
			return [&"drop_can", "can_%d" % int(st.held_can)]
		return job
	var ripe := _plots(func(p: Node) -> bool: return p.state == &"ripe")
	var bag := int(st.get("bag", 0))
	if bag > 0 and (bag >= int(Data.value(&"labor", &"carry", &"capacity")) or ripe.is_empty()):
		return [&"sell", "sell_box"]
	if not ripe.is_empty():
		return [&"harvest", ripe[0].id]
	var empty := _plots(func(p: Node) -> bool: return p.state == &"empty" and _keeps_payment(p) and _plantable(p, st))  # P4-18: never spin on no_coins or locked_crop
	if not empty.is_empty():
		return [&"plant", empty[0].id]
	var dry := _plots(func(p: Node) -> bool: return p.state == &"growing" and not p.watered)
	if not dry.is_empty():
		if st.get("held_kind", &"") != &"water":
			return _fetch(st, &"water")
		return [&"water", dry[0].id] if int(st.get("can", 0)) > 0 else [&"fill_can", "well"]
	var gone := _plots(func(p: Node) -> bool: return p.state in [&"wilted", &"dead"])  # P4-21: a wilted plot blocks planting
	if not gone.is_empty():
		return [&"clear_plot", gone[0].id]
	return []


## P4-21 (doc 03 s6 and s18): from dusk to dawn bots wait in the barn, lit while the generator runs. The scripted
## night stalks whoever is outdoors once `scripted_lurk_s` (60 s) has passed, so after dusk a bot goes out only for a
## trip it ends inside the barn by HOME_BY_S: picking ripe moonflowers (they ripen at nightfall and wilt at dawn,
## doc 01 Crops) or pouring the fuel can. Either trip keeps someone outdoors for the first 30 s of the night
## (sabotage.json trample `nobody_outside_s`). Late in the day it only readies the fuel can.
# ponytail: one can lasts to about 250 s of the 300 s night (generator_tank_s 210, fuel_can_pct 50), so the generator
# still dies late; a second drum trip means being outdoors after 60 s.
func _night_job(st: Dictionary) -> Array:
	var day := Clock.phase == &"day"
	if Clock.phase == &"dusk" and int(st.get("bag", 0)) > 0:
		return [&"sell", "sell_box"]  # the dead lose what they carry (doc 02 s9 step 1)
	if not day and _sentinel():
		return [&"sentinel", "town_stand"]
	var room := int(st.get("bag", 0)) < int(Data.value(&"labor", &"carry", &"capacity"))
	if not day:
		for p: Node in _plots(func(p: Node) -> bool: return p.bed and (p.state == &"ripe" or (p.state == &"growing" and p.watered))):
			if p.state == &"ripe" and room and _home_by(_stand(p.id), Interactable.hold_seconds(&"harvest")):
				return [&"harvest", p.id]
			if p.state == &"growing" and _home_by(_stand(p.id), Interactable.hold_seconds(&"harvest")):
				return [&"tend", p.id]
	if farm.targets.has("generator") and _free("generator"):
		var gen: Node = farm.targets["generator"].gen
		var full := bool(st.get("fuel_can", false))
		if gen.damaged and Clock.phase == &"dusk" and _scrap_ok():
			return [&"repair_generator", "generator"]
		if full and (day or _home_by(_stand("generator"), Interactable.hold_seconds(&"refuel"))):
			if Clock.phase == &"night" and Clock.t_phase >= REFUEL_AT_S and gen.fuel_s < gen.tank_s:
				return [&"refuel", "generator"]
			return [&"tend", "generator"]
		if not full and Clock.phase != &"night" and _fuel_can_free():
			if st.get("held_kind", &"") != &"fuel":
				return _fetch(st, &"fuel")
			return [&"fill_fuel", "fuel_drum"]
	return [] if day else [&"shelter", "barn"]


## P4-21 (doc 03 s10 "Unattended farm", s11.5): one bot, the highest living bot peer, spends dusk to dawn outdoors at
## the town stand, where the creature's stalks and kills are less likely but possible (D-115, ai_director.json
## `town_stand`). Someone outdoors all night keeps the dawn trample to its base count (sabotage.json trample).
func _sentinel() -> bool:
	if get_tree().get_first_node_in_group(&"sanctuary") == null:
		return false
	for p: int in Game.players:
		if p < 0 and p > peer and not Game.is_ghost(p):
			return false
	return true


## P4-21: a trip to `at` with a `hold_s` hold there ends inside the barn by HOME_BY_S into the night. Game clock only.
func _home_by(at: Vector3, hold_s: float) -> bool:
	var t := Clock.t_phase - (Clock.length_of(&"dusk") if Clock.phase == &"dusk" else 0.0)
	var walk := Data.speed(&"walk") * float(Game.players[peer].get("speed_mult", 1.0))
	var metres := Vector2(_pos.x - at.x, _pos.z - at.z).length() + Vector2(at.x - BARN_DOOR_OUT.x, at.z - BARN_DOOR_OUT.z).length()
	return t + hold_s + 1.0 + (metres + BARN_DOOR_OUT.distance_to(SHELTER_SPOT)) / walk < HOME_BY_S


## Where a bot stands to hold target `id`.
func _stand(id: String) -> Vector3:
	var t: Node = farm.targets[id]
	return t.target_pos() + (PLOT_STAND if t is Plot else STAND.get(id, FIX_STAND if id.begins_with("dist_") else Vector3.ZERO))


## P4-21 (doc 02 s7): keep the first payment. A seed whose crop ripens after the first-payment dawn is bought only
## from coins above what that dawn takes. Dawn n comes before day n, so a crop sells in time if it ripens before day n.
# ponytail: the first payment only; the final dawn sells the ground before it takes the payment (doc 02 s9 step 2).
func _keeps_payment(p: Node) -> bool:
	var debt := get_tree().get_first_node_in_group(&"debt")
	var dawn := int(Data.value(&"season", &"first_payment_dawn"))
	if debt == null or debt.short_season() or Clock.day >= dawn:
		return true
	var r: Dictionary = Crops.rec(p.crop_for(&"plant"))
	if Clock.day + int(r.grow_days) < dawn and (int(r.grow_days) > 0 or _pickers() > 1):
		return true
	return farm.coins - int(r.seed) >= debt.first_of(debt.owed + debt.paid) - debt.paid


## Living bots. Moonflowers (0 grow days) ripen at nightfall and need a bot besides the sentinel to pick them, or
## they wilt at dawn and their seeds came out of the payment (P4-21 QA: s2p_1, s2p_2 foreclosed).
func _pickers() -> int:
	return Game.players.keys().filter(func(p: int) -> bool: return p < 0 and not Game.is_ghost(p)).size()


## D-085: a damage fix needs scrap; with none left the bot buys one (15 coins) if the team can pay.
# ponytail: buys from anywhere (`near` false) instead of walking to the store crate; add the walk when bots shop.
func _scrap_ok() -> bool:
	return farm.store.scrap_total() > 0 or farm.store.buy(peer, &"scrap", false) == &""


## D-093: planting uses a seed of the plot's crop (the bot's plain `plant`); with none left the bot buys one.
# ponytail: one at a time from anywhere (`near` false), as `_scrap_ok`; keeps the simulator's cash timing.
## P5-57 `seed_coin_check`: ask the store first, so a bot with no coins never logs `store_refused` every frame.
func _plantable(plot: Node, st: Dictionary) -> bool:
	var why: StringName = plot.can_start(&"plant", st)
	if why != &"no_seeds":
		return why == &""
	var crop: StringName = plot.crop_for(&"plant")
	if knob(&"seed_coin_check") and farm.store.seed_why_not(peer, crop, 1, false) != &"":
		return false
	return farm.store.buy_seeds(peer, crop, 1, false) == &""


## P2-27: the job that gets a can of `kind` into the hands: put down the wrong one, else pick up the nearest free one.
func _fetch(st: Dictionary, kind: StringName) -> Array:
	var held := int(st.get("held_can", -1))
	if held >= 0:
		return [&"drop_can", "can_%d" % held]
	var best := -1
	for id in farm.cans.cans:
		var c: Dictionary = farm.cans.cans[id]
		if c.kind == kind and c.holder == 0 and _free("can_%d" % id) and (best < 0 or _pos.distance_squared_to(c.pos) < _pos.distance_squared_to(farm.cans.cans[best].pos)):
			best = id
	return [&"take_can", "can_%d" % best] if best >= 0 else []


## P4-21: a fuel can lies free, or this bot holds it.
func _fuel_can_free() -> bool:
	for id in farm.cans.cans:
		var c: Dictionary = farm.cans.cans[id]
		if c.kind == &"fuel" and (c.holder == peer or (c.holder == 0 and _free("can_%d" % id))):
			return true
	return false


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
	await _walk(_stand(id))
	if Game.is_ghost(peer):
		return
	Net.request_received.emit(&"hold", peer, [verb, id])  # what Net's `request_hold` RPC emits
	if not farm.registry.holds.has(peer):  # refused; the host logged `hold_refused` with the reason
		await _wait(REFUSED_WAIT_S)
		return
	var timeout := get_tree().create_timer(Interactable.hold_seconds(verb) + HOLD_SLACK_S)
	while farm.registry.holds.has(peer) and timeout.time_left > 0.0:
		await get_tree().physics_frame
	if farm.registry.holds.has(peer):
		Net.request_received.emit(&"hold_cancel", peer, [])


## P4-12: hold `push_cart` and walk beside the cart until the hold ends (knocked off, cart out, dead).
func _push() -> void:
	var cart: Node = farm.cart
	await _walk(cart.target_pos())
	if knob(&"follow_cart"):  # P5-57: the cart rolls while others push; catch up with where it is now, not where it was
		var limit := get_tree().create_timer(30.0)
		while not Game.is_ghost(peer) and limit.time_left > 0.0 and Vector2(_pos.x - cart.target_pos().x, _pos.z - cart.target_pos().z).length() > cart.range_m - 0.5:
			_path = [Vector3(cart.target_pos().x, 0.0, cart.target_pos().z)]
			await get_tree().physics_frame
		_path.clear()
	if Game.is_ghost(peer):
		return
	Net.request_received.emit(&"hold", peer, [&"push_cart", "cart"])
	if not farm.registry.holds.has(peer):
		await _wait(REFUSED_WAIT_S)
		return
	while farm.registry.holds.has(peer) and not Game.is_ghost(peer):
		_path = [cart.body.global_position + cart.body.global_basis.z * 1.5]  # behind: the cart faces -Z
		await get_tree().physics_frame


func _walk(to: Vector3) -> void:
	_path = [Vector3(to.x, 0.0, to.z)] if Game.full_farm else Route.path(_pos, to)
	if bots and bots.grid():
		_path = bots.grid().path(_pos, to)  # P5-57: around walls, fences and props, through doorways
	elif Game.full_farm and BARN.has_point(Vector2(_pos.x, _pos.z)) != BARN.has_point(Vector2(to.x, to.z)):
		# P5-55: through the barn door, never the wall (the door guard in `_step` then opens it if closed)
		var door_in := Vector3(0, 0, -1.5)
		_path = ([door_in, BARN_DOOR_OUT] if BARN.has_point(Vector2(_pos.x, _pos.z)) else [BARN_DOOR_OUT, door_in]) + _path
	while not _path.is_empty() and not Game.is_ghost(peer):
		await get_tree().physics_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
