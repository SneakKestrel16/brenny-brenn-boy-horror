extends Node3D
## P4-08, doc 01 "Daytime Threats" and doc 02 section 10.1: the pen animals (chicken, pig, cow; 2 each, gray-box
## models from assets/models) and the breakable pen fence. Node `Animals`, a child of Main, on every peer.
## Host: simulates them. In the pen they wander. `break_fence` (called by Sabotage's `broken_fence`) opens a fence
## section and sends `animals_per_fence_break` of them through it to an escape spot at least `animal_escape_m` from
## the pen gate. A `round_up` hold on a loose animal walks it back to the pen. The fix for the fence is Sabotage's
## `repair_fence` hold (doc 03 section 10.1). At the end of dusk the animals still out are counted
## (`animals_out_at_dusk` log, D-082 item 2); at dawn `bill_dusk` bills them (Death calls it after the medical bill).
## Before the creature arrives near an animal, it panics (a P4-17 sound heard by everyone, no HUD marker).
## Every peer: draws them from the host's 5 Hz snapshot and the fence sections as the host opens and closes them.
## Logs `fence_broken`, `fence_fixed`, `animal_escaped`, `animal_rounded_up`, `animals_out_at_dusk`, `animal_dusk_bill`.

const Logic := preload("res://game/farming/animal_logic.gd")
const Interactable := preload("res://game/interaction/interactable.gd")

const WALK := 0.9  ## m/s in the pen; placeholder
const RUN := 3.2  ## m/s when escaping or being walked back; placeholder
const SEND_S := 0.2  ## host snapshot period
const ALERT_M := 35.0  ## placeholder: how near the creature gets before an animal panics (the Rancher's x1.5, roles.json)
const PANIC_GAP_S := 12.0  ## placeholder: at most one panic sound this often
const CALL_EVERY_S := Vector2(25.0, 50.0)  ## placeholder: an idle call by day, per the whole herd
const MODELS := "res://assets/models/animal_%s.glb"
const STATES := [&"pen", &"loose", &"home"]

## An animal's pick body: the round_up hold (host validates, doc 05 section 7).
class AnimalTarget extends "res://game/interaction/interactable.gd":
	var an: Node
	var idx := 0

	func verbs_for(_st: Dictionary) -> Array[StringName]:
		var out: Array[StringName] = []
		if an.is_loose(idx):
			out.append(&"round_up")
		return out

	func can_start(v: StringName, _st: Dictionary) -> StringName:
		if v != &"round_up":
			return &"no_such_verb"
		return &"" if an.is_loose(idx) else &"not_loose"

	func complete(_v: StringName, peer: int, _st: Dictionary) -> void:
		an.round_up_done(idx, peer)


var herd: Array = []  ## every peer: {sp, node, state, pos, path, wait, snap}
var broken: Dictionary = {}  ## every peer: fence section index -> true while broken
var out_at_dusk := 0  ## host: animals loose when the last dusk ended, billed at dawn

var _farm: Node
var _sections: Array = []  ## the fence_sections bodies, in scene order
var _gate := Vector3.ZERO
var _pen := Rect2()
var _rng := RandomNumberGenerator.new()
var _send_t := 0.0
var _check_t := 0.0
var _panic_t := 0.0
var _call_t := 20.0
var _breaks_today := 0


func _ready() -> void:
	add_to_group(&"animals")
	_gate = _first(&"pen_gates")
	_sections = get_tree().get_nodes_in_group(&"fence_sections")
	if _sections.is_empty() or _gate == Vector3.INF:
		return  # the Phase 1 gray-box farm has no breakable pen
	_pen = Rect2(_gate.x - 5.0, _gate.z - 9.0, 10.0, 8.0)  # inside the pen walls (build_farm.py: x -30..-18, z -38..-28)
	_rng.seed = Game.seed_value + 8
	_farm = get_tree().get_first_node_in_group(&"farm")
	var i := 0
	for sp: String in Data.value(&"season", &"animal_species"):
		for k in int(Data.value(&"season", &"animals_per_species")):
			_spawn(i, sp)
			i += 1
	Net.apply_received.connect(_on_apply)
	if not Game.is_host():
		return
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what == &"farm_state":  # a late joiner gets the herd and the open fence sections
			Net.to_peers(&"apply_animals", [&"fence", broken.keys()], [peer])
			Net.to_peers(&"apply_animals", [&"state", _snapshot()], [peer]))
	Clock.phase_changed.connect(_on_phase)


func _spawn(i: int, sp: String) -> void:
	var root := Node3D.new()
	root.name = "Animal%d" % i
	add_child(root)
	var scene := load(MODELS % sp) as PackedScene
	if scene:
		root.add_child(scene.instantiate())
	else:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.5, 0.5, 0.9)
		mi.mesh = b
		mi.position.y = 0.25
		root.add_child(mi)
	var pos := _pen_spot()
	root.global_position = pos
	var a := {"sp": sp, "node": root, "state": &"pen", "pos": pos, "path": [] as Array, "wait": _rng.randf_range(0.5, 3.0), "snap": pos}
	herd.append(a)
	if _farm:
		var t := AnimalTarget.new()
		t.an = self
		t.idx = i
		t.id = "animal_%d" % i
		t.farm = _farm
		root.add_child(t)
		t.add_pick_body(Vector3(1.4, 1.2, 1.4))
		_farm.targets[t.id] = t


func _first(group: StringName) -> Vector3:
	var n := get_tree().get_first_node_in_group(group)
	return (n as Node3D).global_position if n else Vector3.INF


func _pen_spot() -> Vector3:
	return Vector3(_rng.randf_range(_pen.position.x + 1.0, _pen.end.x - 1.0), 0.0, _rng.randf_range(_pen.position.y + 1.0, _pen.end.y - 1.0))


func is_loose(i: int) -> bool:
	return i < herd.size() and herd[i].state == &"loose"


# --- host -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if herd.is_empty():
		return
	if not Game.is_host():
		for a in herd:  # ease toward the last snapshot
			a.pos = (a.pos as Vector3).lerp(a.snap, 1.0 - exp(-12.0 * delta))
			_place(a, a.pos)
		return
	var held := _held()
	for i in herd.size():
		if not held.has(i):
			_move(herd[i], delta)
	_send_t += delta
	if _send_t >= SEND_S:
		_send_t = 0.0
		Net.to_peers(&"apply_animals", [&"state", _snapshot()])
	_check_t += delta
	if _check_t >= 0.5:
		_check_t = 0.0
		_sounds(0.5)


## Animals a player is rounding up right now stand still.
func _held() -> Dictionary:
	var out := {}
	if _farm and _farm.registry:
		for p in _farm.registry.holds:
			var t = _farm.registry.holds[p].target
			if is_instance_valid(t) and t is AnimalTarget:
				out[t.idx] = true
	return out


func _move(a: Dictionary, delta: float) -> void:
	var speed := WALK
	if not a.path.is_empty():
		speed = RUN if a.state != &"pen" else WALK
		var to: Vector3 = a.path[0]
		a.pos = Logic.step_toward(a.pos, to, speed * delta)
		_face(a, to)
		if Vector2(a.pos.x - to.x, a.pos.z - to.z).length() < 0.05:
			a.path.pop_front()
			if a.path.is_empty() and a.state == &"home":
				a.state = &"pen"
		_place(a, a.pos)
		return
	a.wait -= delta  # idle: wander a few metres, in the pen or around the escape spot
	if a.wait <= 0.0:
		a.wait = _rng.randf_range(2.0, 5.0)
		var c: Vector3 = a.pos
		var p := _pen_spot() if a.state == &"pen" else c + Vector3(_rng.randf_range(-3, 3), 0.0, _rng.randf_range(-3, 3))
		a.path = [p]
	_place(a, a.pos)


func _face(a: Dictionary, to: Vector3) -> void:
	var d: Vector3 = to - a.pos
	if Vector2(d.x, d.z).length() > 0.01:
		(a.node as Node3D).rotation.y = atan2(-d.x, -d.z)  # models face -Z (CONTRACTS section 3)


func _place(a: Dictionary, pos: Vector3) -> void:
	(a.node as Node3D).global_position = pos


func _snapshot() -> Array:
	var out: Array = []
	for a in herd:
		out.append([STATES.find(a.state), snappedf(a.pos.x, 0.01), snappedf(a.pos.z, 0.01), snappedf((a.node as Node3D).rotation.y, 0.01)])
	return out


## Host: section positions not broken yet, as [index, position], for Sabotage to pick one away from the players.
func fence_points() -> Array:
	var out: Array = []
	for i in _sections.size():
		if not broken.has(i):
			out.append([i, (_sections[i] as Node3D).global_position])
	return out


## Host: open section `i` and send the animals out. Returns how many escaped (0: none was in the pen, nothing done).
func break_fence(i: int) -> int:
	var inside: Array = []
	for k in herd.size():
		if herd[k].state == &"pen":
			inside.append(k)
	if inside.is_empty() or broken.has(i):
		return 0
	_breaks_today += 1
	broken[i] = true
	_set_fence(i, true)
	Net.to_peers(&"apply_animals", [&"fence", broken.keys()])
	var spots := Logic.far_spots(get_tree().get_nodes_in_group(&"animal_escape_spots").map(func(n: Node3D) -> Vector3: return n.global_position),
			_gate, float(Data.value(&"season", &"animal_escape_m")))
	var c: Vector3 = (_sections[i] as Node3D).global_position
	var d := c - Vector3(_pen.get_center().x, 0.0, _pen.get_center().y)
	var out_dir := Vector3(signf(d.x), 0, 0) if absf(d.x) > absf(d.z) else Vector3(0, 0, signf(d.z))  # the wall's outward side
	var outside := spots.filter(func(p: Vector3) -> bool: return (p - c).dot(out_dir) > 0.0)  # QA P4-08: not back through the pen
	if not outside.is_empty():
		spots = outside
	var n := mini(int(Data.value(&"season", &"animals_per_fence_break")), inside.size())
	var sent: Array = []
	for j in n:
		var k: int = inside.pop_at(_rng.randi() % inside.size())
		var spot: Vector3 = spots[_rng.randi() % spots.size()] if not spots.is_empty() else c + out_dir * 70.0
		herd[k].state = &"loose"
		herd[k].path = [c - out_dir * 1.5, c + out_dir * 2.0, spot]
		sent.append(k)
		Log.event(&"animal_escaped", {"animal": k, "species": String(herd[k].sp), "section": i, "to": [snappedf(spot.x, 0.1), snappedf(spot.z, 0.1)],
				"from_gate_m": snappedf(Vector2(spot.x - _gate.x, spot.z - _gate.z).length(), 0.1), "day": Clock.day})
	Log.event(&"fence_broken", {"section": i, "animals": sent, "day": Clock.day})
	return n


## Host: Sabotage's fix of `broken_fence` (the repair_fence hold) closes the section.
func fix_fence(i: int) -> void:
	if broken.erase(i):
		_set_fence(i, false)
		Net.to_peers(&"apply_animals", [&"fence", broken.keys()])
		Log.event(&"fence_fixed", {"section": i, "day": Clock.day})


## Host: the round_up hold finished: the animal walks to the gate and into the pen.
func round_up_done(i: int, peer: int) -> void:
	var a: Dictionary = herd[i]
	if a.state != &"loose":
		return
	a.state = &"home"
	a.path = _round_pen(a.pos) + [_gate + Vector3(0, 0, 2.5), _gate + Vector3(0, 0, -1.5), _pen_spot()]
	Log.event(&"animal_rounded_up", {"animal": i, "species": String(a.sp), "by": peer, "day": Clock.day,
			"role": String(Game.players.get(peer, {}).get("role", ""))})


## Corners outside the pen walls to walk round to the south gate, so an animal north of or beside the pen does
## not cut through it (QA P4-08: the walk is straight lines with no collision).
func _round_pen(from: Vector3) -> Array:
	var r := _pen.grow(2.0)
	var out: Array = []
	if from.z < r.end.y:
		var x := r.position.x if from.x < _pen.get_center().x else r.end.x
		if from.z < r.position.y:
			out.append(Vector3(x, 0.0, r.position.y))
		out.append(Vector3(x, 0.0, r.end.y))
	return out


func _on_phase(ph: StringName) -> void:
	if ph == &"day":
		_breaks_today = 0
	elif ph in [&"night", &"harvest_moon"]:  # dusk just ended (D-082 item 2: P4-10 measures how often animals are still out)
		out_at_dusk = herd.filter(func(a: Dictionary) -> bool: return a.state != &"pen").size()
		Log.event(&"animals_out_at_dusk", {"day": Clock.day, "out": out_at_dusk, "total": herd.size(), "breaks_today": _breaks_today,
				"fence_still_broken": broken.size(), "players": Game.player_count()})


## Host, dawn step 3b (doc 02 section 9 and 10.1): `out x scaled(10, payment pct)`, after the medical bill, never below
## the bank floor; the shortfall is not carried. The animals are back in the pen by morning.
func bill_dusk(farm: Node) -> void:
	if herd.is_empty():
		return
	var heads := clampi(Game.player_count(), 2, Game.max_players())
	var pct := int(Data.record(&"player_scaling", &"headcount").get("payment_pct_by_players", {}).get(str(heads), 100))
	var r := Logic.dusk_bill(out_at_dusk, int(Data.value(&"season", &"animal_out_at_dusk_coins")), pct, farm.coins, int(Data.value(&"season", &"bank_floor")))
	if out_at_dusk > 0:
		if r[1] > 0:
			farm.add_coins(-r[1], &"animals_out", 0)
		Log.event(&"animal_dusk_bill", {"day": Clock.day, "out": out_at_dusk, "cost": r[0], "paid": r[1], "players": Game.player_count()})
	out_at_dusk = 0
	for a in herd:
		if a.state != &"pen":
			a.state = &"pen"
			a.path = []
			a.pos = _pen_spot()


## Host: an idle call by day and the panic before the creature arrives (P4-17 sounds), heard by everyone.
func _sounds(delta: float) -> void:
	_panic_t -= delta
	if Clock.phase in [&"night", &"harvest_moon"]:  # P4-12: the Harvest Moon is a night
		var cr := get_tree().get_first_node_in_group(&"creature") as Node3D
		var mult := 1.0
		for p in Game.players:
			if Game.players[p].get("role", &"") == &"rancher" and not Game.is_ghost(p):
				mult = float(Data.record(&"roles", &"rancher").perks.animal_alert_range_mult)
		if cr and _panic_t <= 0.0:
			for i in herd.size():
				if Vector2(herd[i].pos.x - cr.global_position.x, herd[i].pos.z - cr.global_position.z).length() < ALERT_M * mult:
					_panic_t = PANIC_GAP_S
					_sound(i, true)
					Log.event(&"animal_panic", {"animal": i, "species": String(herd[i].sp), "day": Clock.day})
					break
	elif Clock.phase == &"day":
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = _rng.randf_range(CALL_EVERY_S.x, CALL_EVERY_S.y)
			_sound(_rng.randi() % herd.size(), false)


func _sound(i: int, panic: bool) -> void:
	Net.to_peers(&"apply_animals", [&"sound", [i, panic]])
	_on_apply(&"animals", [&"sound", [i, panic]])


# --- every peer -------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	if what != &"animals":
		return
	match args[0]:
		&"state":
			if Game.is_host():
				return
			for i in mini(herd.size(), args[1].size()):
				var s: Array = args[1][i]
				herd[i].state = STATES[clampi(int(s[0]), 0, 2)]
				herd[i].snap = Vector3(s[1], 0.0, s[2])
				(herd[i].node as Node3D).rotation.y = s[3]
		&"fence":
			if Game.is_host():
				return
			var now := {}
			for i in args[1]:
				now[int(i)] = true
			for i in _sections.size():
				if now.has(i) != broken.has(i):
					_set_fence(i, now.has(i))
			broken = now
		&"sound":
			var a: Dictionary = herd[int(args[1][0])]
			var k := _species_no(a.sp)
			var s := StringName("sfx_animal_panic_0%d" % k if args[1][1] else "sfx_animal_%s" % a.sp)
			var snd := get_node_or_null("/root/Soundscape")
			if snd:
				snd.play_3d(s, a.pos)


func _species_no(sp: String) -> int:
	return 1 + (Data.value(&"season", &"animal_species") as Array).find(sp)


func _set_fence(i: int, is_broken: bool) -> void:
	var body := _sections[i] as StaticBody3D
	body.visible = not is_broken
	for c in body.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred(&"disabled", is_broken)
