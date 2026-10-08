extends Node
## Doc 05 section 11, doc 03 section 7: traps from the player side. Every peer shows a sprung trap
## (`apply_trap_changed`) and who is pinned (`apply_trap_race`). The host decides: the Creature reports a
## living player on an armed trap, a bear trap pins them and starts the race (start distance over
## `trap_race_speed_mps` seconds), a finished `pry` frees them and starts Shaken, the deadline kills
## (`Death`). A pit only makes the player drop the bag (doc 01 "Night Traps").
## Not built yet (later phases): disarm, fill_pit, bells, flags, pegboard, Taint, the half-RTT credit
## (needs `Net.rtt_ms`, so `credit_ms` is logged 0).

const TrapTarget := preload("res://game/traps_player/trap_target.gd")
const DEEP_M := 18.0  ## doc 03 section 7 deep trap start distance (placeholder)
const AT_ONCE_S := 0.5  ## doc 03 section 7: "pried at once" = pry hold started within 0.5 s of the spring
const SHAKEN_S := 60.0  ## doc 01 "Night Traps"
const SHAKEN_MULT := 0.6  ## doc 01 "Night Traps": 40% slower

var traps: Dictionary = {}  ## every peer: trap id -> {kind, state, position}; sprung ones only
var victims: Dictionary = {}  ## every peer: trap id -> pinned peer
var races: Dictionary = {}  ## host only: trap id -> {victim, deadline, t, hold_t, helped, start_m}
var _shaken: Dictionary = {}  ## host: peer -> seconds left
var _creature: Node
var _death: Node
var _registry: Node
var _force := OS.get_cmdline_user_args().has("--force-spring")  # QA: spring the first armed bear trap on the host player (and let pry reach it)
var _force_t := 0.0


func _ready() -> void:
	add_to_group(&"trap_race")
	Net.apply_received.connect(_on_apply)
	Game.player_left.connect(func(p: int) -> void:
		for id in victims.keys():
			if victims[id] == p:
				victims.erase(id)
				races.erase(id)
		_shaken.erase(p))
	if not Game.is_host():
		return
	_creature = get_parent().get_node("Creature")
	_death = get_parent().get_node("Death")
	_registry = get_parent().get_node("Farm").registry
	_creature.trap_sprung.connect(_on_sprung)
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what != &"farm_state":
			return  # a late joiner sees the open traps and who is pinned
		for id in traps:
			Net.to_peers(&"apply_trap_changed", [id, traps[id].kind, traps[id].state, traps[id].position], [peer])
		for id in races:
			var r: Dictionary = races[id]
			Net.to_peers(&"apply_trap_race", [r.victim, id, r.deadline - r.t, r.start_m], [peer]))


func _bcast(what: StringName, args: Array) -> void:
	Net.to_peers(StringName("apply_" + String(what)), args)
	Net.apply_received.emit(what, args)  # the host is its own client


func _night() -> bool:
	return float(_creature.debug_state().night_t) >= 0.0


# --- host ----------------------------------------------------------------------------------------

func _on_sprung(id: String, kind: StringName, peer: int, pos: Vector3, deep: bool) -> void:
	var st: Dictionary = Game.players[peer]
	_bcast(&"trap_changed", [id, kind, &"sprung", pos])
	if kind != &"bear":
		st.bag = 0  # pit: stumble and drop what you carry
		return
	_registry.cancel(peer, &"pinned")
	st.pinned = true
	if peer > 1:
		Net.to_peers(&"apply_teleport", [st.pos], [peer])  # snap back to where the host has them
	var dist := DEEP_M if deep else float(Data.value(&"phase1", &"trap_race_distance_m", &"metres"))
	var dl := dist / float(Data.value(&"creature", &"trap_race_speed_mps", &"speed_mps"))
	races[id] = {"victim": peer, "deadline": dl, "t": 0.0, "hold_t": -1.0, "helped": false, "start_m": dist}
	_bcast(&"trap_race", [peer, id, dl, dist])
	_creature.force_state(&"chase", &"trap_race", peer)  # ambience: the signature approach


func _physics_process(delta: float) -> void:
	if not Game.is_host():
		return
	_force_t += delta
	if _force and _force_t >= 3.0 and races.is_empty() and not Game.is_ghost(1):
		_force_t = 0.0
		for t in _creature.debug_state().traps.values():
			if t.armed and t.kind == &"bear" and not traps.has(t.id):
				_on_sprung(t.id, t.kind, 1, t.position, t.deep)
				break
	for p in _shaken.keys():
		_shaken[p] -= delta
		if _shaken[p] <= 0.0:
			_shaken.erase(p)
			if Game.players.has(p):
				Game.players[p].speed_mult = 1.0
	for id in races.keys():
		var r: Dictionary = races[id]
		r.t += delta
		for p in _registry.holds:  # who is prying this trap
			var h: Dictionary = _registry.holds[p]
			if h.verb == &"pry" and h.target.id == id:
				if p == r.victim:
					if r.hold_t < 0.0:
						r.hold_t = r.t
				elif not Game.is_ghost(p):
					r.helped = true
		if r.t >= r.deadline:
			_lose(id, r)


## Host: the victim's pry finished (a helper's hold only shortens it, doc 03 section 7).
func on_pry_done(id: String, peer: int) -> void:
	var r: Dictionary = races.get(id, {})
	if r.is_empty() or peer != r.victim:
		return
	races.erase(id)
	var st: Dictionary = Game.players[peer]
	st.pinned = false
	st.speed_mult = SHAKEN_MULT
	_shaken[peer] = SHAKEN_S
	_result(id, r, true, r.deadline - r.t, r.t - maxf(r.hold_t, 0.0))
	Log.event(&"shaken", {"player": peer, "seconds": SHAKEN_S})
	if peer == 1:
		Net.apply_received.emit(&"shaken", [SHAKEN_S])
	elif peer > 1:
		Net.to_peers(&"apply_shaken", [SHAKEN_S], [peer])
	traps[id].state = &"disarmed"
	_bcast(&"trap_changed", [id, traps[id].kind, &"disarmed", traps[id].position])
	_creature.force_state(&"retreat" if _night() else &"lurk", &"trap_race_survived", peer)


func _lose(id: String, r: Dictionary) -> void:
	races.erase(id)
	var pry_s := Data.hold_s(&"pry")
	var h: Dictionary = _registry.holds.get(r.victim, {})
	var left := pry_s * (1.0 - float(h.progress)) if not h.is_empty() and h.verb == &"pry" else pry_s
	_result(id, r, false, r.deadline - (r.t + left), pry_s)
	var night := _night()
	_death.die(r.victim, &"night_trap" if night else &"trap_race")
	_creature.force_state(&"retreat" if night else &"lurk", &"kill", r.victim)


func _result(id: String, r: Dictionary, survived: bool, spare: float, pry_s: float) -> void:
	Log.event(&"trap_race_result", {"player": r.victim, "trap_id": id, "solo": not r.helped, "tainted": false,
		"pried_at_once": r.hold_t >= 0.0 and r.hold_t <= AT_ONCE_S, "survived": survived,
		"seconds_spare": snappedf(spare, 0.01), "start_distance_m": r.start_m, "pry_s": snappedf(pry_s, 0.01),
		"credit_ms": 0})


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	match what:
		&"trap_changed":
			var id: String = args[0]
			traps[id] = {"kind": args[1], "state": args[2], "position": args[3]}
			if args[2] == &"sprung":
				_show(id, args[1])
			elif victims.has(id):
				_pin(victims[id], false)
				victims.erase(id)
		&"trap_race":
			victims[args[1]] = args[0]
			_pin(args[0], true)
		&"shaken":
			var pl := _player(Game.local_peer())
			if pl:
				pl.shake(args[0], SHAKEN_MULT)
		&"death":
			for id in victims.keys():
				if victims[id] == args[0]:
					victims.erase(id)
					races.erase(id)
			_pin(args[0], false)


func _pin(peer: int, on: bool) -> void:
	var pl := _player(peer)
	if pl:
		pl.pinned = on


func _player(peer: int) -> Node:
	var players := get_parent().get_node_or_null("Players")
	return players.player(peer) if players else null


## Placeholder art until the Technical Artist's models: a flat disc, red for a bear trap.
func _show(id: String, kind: StringName) -> void:
	var farm := get_parent().get_node("Farm")
	if farm.targets.has(id):
		return
	for m in get_tree().get_nodes_in_group(&"trap_spots"):
		if String(m.name) != id:
			continue
		var mesh := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.5 if kind == &"bear" else 0.8
		c.bottom_radius = c.top_radius
		c.height = 0.06
		mesh.mesh = c
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.08, 0.06) if kind == &"bear" else Color(0.1, 0.07, 0.04)
		mesh.material_override = mat
		m.add_child(mesh)
		var t := TrapTarget.new()
		t.race = self
		t.id = id
		t.farm = farm
		m.add_child(t)
		t.add_pick_body(Vector3(1.6, 0.6, 1.6))
		if _force:
			t.range_m = 1000.0  # QA: the host player is not at the trap
		farm.targets[id] = t
		return
