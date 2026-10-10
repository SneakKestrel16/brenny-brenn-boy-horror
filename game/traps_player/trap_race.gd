extends Node
## Doc 05 section 11, doc 03 section 7: traps from the player side. Every peer shows a sprung trap
## (`apply_trap_changed`) and who is pinned (`apply_trap_race`). The host decides: the Creature reports a
## living player on an armed trap, a bear trap pins them and starts the race (start distance over
## `trap_race_speed_mps` seconds), a finished `pry` frees them and starts Shaken, the deadline kills
## (`Death`). A pit only makes the player drop the bag (doc 01 "Night Traps").
## P2-11 adds the sweep side: every set trap gets a `TrapTarget` (disarm_bear, fill_pit), `clear_trap`
## ends one (`trap_changed` `disarmed` / `filled`), flags and the pegboard are in `trap_sweep.gd`.
## Not built yet (later phases): bells, the half-RTT credit (needs `Net.rtt_ms`, so `credit_ms`
## is logged 0).

const TrapTarget := preload("res://game/traps_player/trap_target.gd")
const AT_ONCE_S := 0.5  ## doc 03 section 7: "pried at once" = pry hold started within 0.5 s of the spring
const SLOW_S := 60.0  ## doc 01 "Night Traps": after a bear trap, 40% slower for 60 s
const SLOW_MULT := 0.6  ## doc 02 section 6: walk x0.6

var traps: Dictionary = {}  ## every peer: trap id -> {kind, state, position}; sprung ones only
var victims: Dictionary = {}  ## every peer: trap id -> pinned peer
var races: Dictionary = {}  ## host only: trap id -> {victim, deadline, t, hold_t, helped, start_m}
var _shaken: Dictionary = {}  ## host: peer -> seconds of Shaken left (P3-07, sprint)
var _slowed: Dictionary = {}  ## host: peer -> seconds of the bear trap slow left (speed)
var _creature: Node
var _death: Node
var _registry: Node
var _force := OS.get_cmdline_user_args().has("--force-spring")  # QA: spring the first armed bear trap on the host player (and let pry reach it)
var _force_t := 0.0
var _sync_t := 0.0


func _ready() -> void:
	add_to_group(&"trap_race")
	Net.apply_received.connect(_on_apply)
	Game.player_left.connect(func(p: int) -> void:
		for id in victims.keys():
			if victims[id] == p:
				victims.erase(id)
				races.erase(id)
				_loosen(id, p, "player_left")
		_shaken.erase(p)
		_slowed.erase(p))
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
	var delay := float(Quirks.effect(peer, &"bear_snap_delay_s", 0.0))  # P5-09 Grandiose delusions: a moment to step off
	if delay <= 0.0:
		_pin_victim(id, peer, deep)
		return
	var step_off := float(Quirks.effect(peer, &"step_off_m", 0.0))
	await get_tree().create_timer(delay).timeout
	var now: Dictionary = Game.players.get(peer, {})
	var at: Vector3 = now.get("pos", pos)
	if now.is_empty() or Game.is_ghost(peer) or Vector2(at.x - pos.x, at.z - pos.z).length() > step_off:
		Log.event(&"quirk_dodge", {"player": peer, "trap_id": id})
		_loosen(id, peer, "dodged")  # the click already sounded at the step; only the leg is saved
		return
	_pin_victim(id, peer, deep)


func _pin_victim(id: String, peer: int, deep: bool) -> void:
	var st: Dictionary = Game.players[peer]
	_registry.cancel(peer, &"pinned")
	st.pinned = true
	if peer > 1:
		Net.to_peers(&"apply_teleport", [st.pos], [peer])  # snap back to where the host has them
	var dist: float = get_tree().get_first_node_in_group(&"ai_director").trap_race_m(deep)  # the day's roll (P3-04)
	var dl := dist / float(Data.value(&"creature", &"trap_race_speed_mps", &"speed_mps"))
	races[id] = {"victim": peer, "deadline": dl, "t": 0.0, "hold_t": -1.0, "helped": false, "start_m": dist}
	_bcast(&"trap_race", [peer, id, dl, dist])
	_creature.force_state(&"chase", &"trap_race", peer)  # ambience: the signature approach


func _physics_process(delta: float) -> void:
	if not Game.is_host():
		return
	_force_t += delta
	_sync_t += delta
	if _sync_t >= 0.5:
		_sync_t = 0.0
		sync_set()
	if _force and _force_t >= 3.0 and races.is_empty() and not Game.is_ghost(1):
		_force_t = 0.0
		for t in _creature.debug_state().traps.values():
			if t.armed and t.kind == &"bear" and traps.get(t.id, {}).get("state") != &"sprung":  # `traps` holds set ones too
				_on_sprung(t.id, t.kind, 1, t.position, t.deep)
				break
	for p in _shaken.keys():
		_shaken[p] -= delta
		if _shaken[p] <= 0.0:
			_shaken.erase(p)
			if Game.players.has(p):
				Game.players[p].shaken = false
	for p in _slowed.keys():
		_slowed[p] -= delta
		if _slowed[p] <= 0.0:
			_slowed.erase(p)
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


## Host: the Creature tells only the other peers about `set` and `moved` (its own copy keeps the host's
## clue), so the host reads its trap table to learn which spots hold an armed trap (doc 03 section 9).
func sync_set() -> void:
	var live := {}
	for t in _creature.debug_state().traps.values():
		if t.armed:
			live[t.id] = true
			if not traps.get(t.id, {}).get("state", &"") in [&"set", &"sprung"]:  # sprung: --force-spring leaves it armed
				Net.apply_received.emit(&"trap_changed", [t.id, t.kind, &"set", t.position])
	for id in traps.keys():
		if traps[id].state == &"set" and not live.has(id):
			Net.apply_received.emit(&"trap_changed", [id, traps[id].kind, &"moved", traps[id].position])


## Host: a sweep hold finished (`disarmed` for a bear trap in hand, `filled` for a pit). Doc 09 section 3
## reads the `trap_changed` line.
func clear_trap(id: String, state: StringName, peer: int) -> void:
	var t: Dictionary = traps[id]
	Log.event(&"trap_changed", {"trap_id": id, "state": String(state), "by": peer, "kind": String(t.kind)})
	_creature.clear_trap(id)  # D-037 (2): the spot is free for the Creature's next set
	_bcast(&"trap_changed", [id, t.kind, state, t.position])
	var sweep := get_tree().get_first_node_in_group(&"trap_sweep")
	if sweep:
		sweep.remove_flags_near(t.position, 2.0)


## Host: the victim's pry finished (a helper's hold only shortens it, doc 03 section 7).
func on_pry_done(id: String, peer: int) -> void:
	var r: Dictionary = races.get(id, {})
	if r.is_empty() or peer != r.victim:
		return
	races.erase(id)
	Game.players[peer].pinned = false
	_result(id, r, true, r.deadline - r.t, r.t - maxf(r.hold_t, 0.0))
	slow(peer)
	shake(peer)
	_loosen(id, peer, "pried")
	_creature.force_state(&"retreat" if _night() else &"lurk", &"trap_race_survived", peer)


## Host, P4-29 (CEO): the sprung trap stays at its spot as the Creature's TrapPickup once its victim is
## pried free, dies or leaves; anyone can then hang it back (or the creature takes it at nightfall, D-104).
func _loosen(id: String, peer: int, cause: String) -> void:
	if not Game.is_host() or traps.get(id, {}).get("state") != &"sprung":
		return
	traps[id].state = &"loose"
	Log.event(&"trap_changed", {"trap_id": id, "state": "loose", "by": peer, "kind": String(traps[id].kind), "cause": cause})
	_bcast(&"trap_changed", [id, traps[id].kind, &"loose", traps[id].position])


## Host: `peer` is Shaken (a survived trap race; a jumpscare or disarm lunge, P3-05): sprint time x0.6 for
## taint.json `shaken.duration_s`; a new cause restarts it (`restarts_on_new_cause`). Never Taints (doc 01).
func shake(peer: int) -> void:
	if not Game.players.has(peer) or Game.is_ghost(peer):
		return
	var s := float(Data.value(&"taint", &"shaken", &"duration_s")) * float(Quirks.effect(peer, &"shaken_duration_mult"))  # P5-09 Anxiety disorder
	Game.players[peer].shaken = true
	_shaken[peer] = s
	Log.event(&"shaken", {"player": peer, "seconds": s})
	if peer == 1:
		Net.apply_received.emit(&"shaken", [s])
	elif peer > 1:
		Net.to_peers(&"apply_shaken", [s], [peer])


## Host: after a bear trap (doc 01 "Night Traps"): 40% slower for 60 s. The host's speed check reads
## `speed_mult`; the freed player's own body slows by `apply_slowed`.
func slow(peer: int) -> void:
	Game.players[peer].speed_mult = SLOW_MULT
	_slowed[peer] = SLOW_S
	if peer == 1:
		Net.apply_received.emit(&"slowed", [SLOW_S])
	elif peer > 1:
		Net.to_peers(&"apply_slowed", [SLOW_S], [peer])


func _lose(id: String, r: Dictionary) -> void:
	races.erase(id)
	var pry_s := Data.hold_s(&"pry")
	if bool(Game.players[r.victim].get("tainted", false)):
		pry_s *= float(Data.value(&"taint", &"taint", &"pry_mult"))  # doc 03 section 7: 6 s Tainted
	var h: Dictionary = _registry.holds.get(r.victim, {})
	var left := pry_s * (1.0 - float(h.progress)) if not h.is_empty() and h.verb == &"pry" else pry_s
	_result(id, r, false, r.deadline - (r.t + left), pry_s)
	var night := _night()
	_death.die(r.victim, &"night_trap" if night else &"trap_race")
	_creature.force_state(&"retreat" if night else &"lurk", &"kill", r.victim)


func _result(id: String, r: Dictionary, survived: bool, spare: float, pry_s: float) -> void:
	Log.event(&"trap_race_result", {"player": r.victim, "trap_id": id, "solo": not r.helped,
		"tainted": bool(Game.players.get(r.victim, {}).get("tainted", false)),
		"pried_at_once": r.hold_t >= 0.0 and r.hold_t <= AT_ONCE_S, "survived": survived,
		"seconds_spare": snappedf(spare, 0.01), "start_distance_m": r.start_m, "pry_s": snappedf(pry_s, 0.01),
		"credit_ms": 0})


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	match what:
		&"trap_changed":
			var id: String = args[0]
			if args[2] == &"moved":
				traps.erase(id)
			else:
				traps[id] = {"kind": args[1], "state": args[2], "position": args[3]}
			match args[2]:
				&"set": _ensure_target(id)
				&"sprung":
					_ensure_target(id)
					_show(id, args[1])
				_: _forget(id)  # moved, disarmed, filled; loose (a pried trap): the Creature shows the pickup
			if args[2] != &"sprung" and victims.has(id):
				_pin(victims[id], false)
				victims.erase(id)
		&"trap_race":
			victims[args[1]] = args[0]
			_pin(args[0], true)
		&"shaken":
			var pl := _player(Game.local_peer())
			if pl:
				pl.shaken_s = args[0]
				if not Game.is_host():  # the host's own line is written in shake()
					Log.event(&"shaken", {"player": Game.local_peer(), "seconds": args[0]})
		&"slowed":
			var pl := _player(Game.local_peer())
			if pl:
				pl.shake(args[0], SLOW_MULT)
		&"death":
			for id in victims.keys():
				if victims[id] == args[0]:
					victims.erase(id)
					races.erase(id)
					_loosen(id, args[0], "death")
			_pin(args[0], false)


func _pin(peer: int, on: bool) -> void:
	var pl := _player(peer)
	if pl:
		pl.pinned = on


func _player(peer: int) -> Node:
	var players := get_parent().get_node_or_null("Players")
	return players.player(peer) if players else null


func _spot(id: String) -> Node:
	for m in get_tree().get_nodes_in_group(&"trap_spots"):
		if String(m.name) == id:
			return m
	return null


## One hold target per spot with a live trap (or a sprung one), made on first sight.
func _ensure_target(id: String) -> void:
	var farm := get_parent().get_node("Farm")
	var m := _spot(id)
	if m == null or farm.targets.has(id):
		return
	var t := TrapTarget.new()
	t.race = self
	t.id = id
	t.farm = farm
	m.add_child(t)
	t.add_pick_body(Vector3(1.6, 0.6, 1.6))
	t.pick = m.get_child(m.get_child_count() - 1)
	if _force:
		t.range_m = 1000.0  # QA: the host player is not at the trap
	farm.targets[id] = t


## The trap is gone (moved, disarmed, filled): no disc, no hold target. Deferred so a hold finishing this
## frame can still read its target.
func _forget(id: String) -> void:
	var m := _spot(id)
	if m and m.get_node_or_null(^"Sprung"):
		m.get_node(^"Sprung").free()
	var farm := get_parent().get_node("Farm")
	if farm.targets.has(id) and farm.targets[id] is TrapTarget:
		var t = farm.targets[id]
		farm.targets.erase(id)
		t.pick.queue_free()
		t.queue_free()


## Placeholder art until the Technical Artist's models (TrapArt).
func _show(id: String, kind: StringName) -> void:
	var m := _spot(id)
	if m == null or m.get_node_or_null(^"Sprung"):
		return
	var art := TrapArt.of(kind, true)  # Q-058: the shared placeholder trap art, origin on the ground
	art.name = "Sprung"
	m.add_child(art)
