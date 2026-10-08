extends CharacterBody3D
## Doc 03 sections 3 to 5, 9, 12 and 18: the DD Phase 1 creature ("fake it first"). The host runs all
## of it; clients only show the placeholder body from the 15 Hz `creature` packet and mirror the state
## from `apply_creature_state` (doc 06 section 7). Ambience hooks connect to `state_changed`.
##
## Night: scripted lurk 60 s, stalk the first outdoor player, chase, retreat (doc 03 section 18);
## then it wanders and hunts by sound: it homes on what it heard or saw (sections 3.1, 3.2), never on
## a true position, and loses a chase by section 5. It sets one bear trap and one pit at the four
## scripted times (section 18) and plays generic stranger lines from the crow corn edges as lures
## (section 12). Taint and the AI Director are off in Phase 1. Day: it waits in far cover.
##
## Presentation may read true positions (lure targeting, the trap spring check, the lit doorway rule);
## hunting never does, except the scripted stalk and chase, which doc 03 section 18 scripts at "the
## first outdoor player" (debug_state shows `scripted`).
##
## QA flags: `-- --creature-test` starts a night at once, repeats it every `night_s`, walks the local
## player round the yard and turns it toward half the lures it hears (synthetic, measures plumbing,
## not players). `-- --log-creature` logs `apply_creature_state` arrivals on clients.

signal state_changed(state: StringName, body: StringName)
## Host only (P1-09): the creature reached `peer` in a chase / a living player sprang an armed trap.
signal caught(peer: int)
signal trap_sprung(trap_id: String, kind: StringName, peer: int, position: Vector3, deep: bool)

const Logic := preload("res://game/creature/creature_logic.gd")
const STATES: Array[StringName] = [&"lurk", &"lure", &"stalk", &"chase", &"retreat"]
const PKT := 0x03  ## doc 06 section 7 `creature` packet type (movement is 1 and 2, voice 0x10/0x11)
const PKT_BYTES := 18  ## type u8, state u8, position 3 x f32, yaw f32
const SEND_HZ := 15.0  ## doc 06 section 7 (placeholder)
const EYE_M := 1.65  ## doc 03 section 3.2, CONTRACTS section 4
const EYE_CROUCH_M := 0.9  ## placeholder: crouched head height for the sight ray
const STALK_CHASE_M := 12.0  ## doc 03 section 4.2: at night a sensed target this close starts a chase
const STALK_STANDOFF_M := 10.0  ## placeholder: a stalk holds back this far ("just out of sight", section 4)
const REGION_M := 25.0  ## placeholder: lurk wanders among markers this near the last thing it heard
const LOUDER_WINS_S := 4.0  ## doc 03 section 3.1 (placeholder)
const LIT_DOOR_M := 6.0  ## doc 03 section 5 / doc 04 sec 8: lit doorway radius
const LURE_WORKED_M := 10.0  ## doc 01 "Voice mimicry": moved more than 10 m toward the source
const LURE_COOLDOWN_S := 20.0  ## placeholder: no doc number; a playtest settles it
const LURE_MIN_M := 12.0  ## placeholder: a source nearer than this cannot show a 10 m walk
const LURE_MAX_M := 40.0  ## placeholder: beyond this a stranger line is too faint to follow
const LONE_M := 15.0  ## inference: doc 03 section 4.2 "a lone player"; reuses the 15 m rule (doc 04 sec 8.3)
const TRAP_SPRING_M := 1.0  ## placeholder: a living player this close to an armed trap springs it
const ARRIVE_M := 1.0
const DAY_COVER := "cover_15"  ## doc 04 sec 9: the far south cover point; where it waits by day (placeholder)
const BODY := &"body_gaunt"  ## doc 03 section 2: Phase 1 shows one body (placeholder choice)
const TELLS: Array[StringName] = [&"none", &"echo", &"pitch_up", &"pitch_down"]  ## doc 03 section 12.2

var state: StringName = &"lurk"
var body: StringName = BODY
var target := 0  ## peer the creature is after, 0 for none

# host only
var _ok := false
var _test := false
var _now := 0.0
var _night_t := -1.0  ## seconds into the current night, negative by day
var _t_state := 0.0
var _stalk_at := -1.0
var _scripted := false  ## the scripted sequence is running this night
var _goal := Vector3.INF
var _memory: Array = []  ## heard: {position, margin, t, peer, kind}
var _seen: Dictionary = {}  ## peer -> {position, t}
var _chase_t := 0.0
var _lose_t := 0.0
var _search_until := -1.0
var _lure: Dictionary = {}
var _lure_n := 0
var _last_lure_t := -INF
var _traps: Dictionary = {}  ## kind -> {id, kind, position, deep, armed}
var _trap_i := 0
var _nights := 0
var _rects: Array[Rect2] = []  ## building floors (x, z), for "outdoor"
var _send_t := 0.0
var _log_t := 0.0
var _log := false
var _last_heard := Vector3.INF  ## outlives the memory: the region it wanders in (section 4 `lurk`)
var _rng := RandomNumberGenerator.new()
var _num: Dictionary = {}

# client only
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0


func _ready() -> void:
	add_to_group(&"creature")
	collision_layer = 4  # layer 3 creature
	collision_mask = 1  # world only: it walks through corn (D-023)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var mesh := MeshInstance3D.new()  # placeholder body until the Technical Artist's model
	var cap := CapsuleMesh.new()
	cap.height = 2.4
	cap.radius = 0.4
	mesh.mesh = cap
	mesh.position.y = 1.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.06, 0.05)
	mesh.material_override = mat
	add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	(shape.shape as CapsuleShape3D).radius = 0.4
	shape.position.y = 1.0
	add_child(shape)
	_test = OS.get_cmdline_user_args().has("--creature-test")
	_log = OS.get_cmdline_user_args().has("--log-creature")
	Net.apply_received.connect(_on_apply)
	Net.bytes_received.connect(_on_bytes)
	if _test and not OS.get_cmdline_user_args().has("--autowalk"):  # --autowalk: players circle instead
		_test_walk.call_deferred()
	if not Game.is_host():
		return
	if not Data.has_table(&"phase1"):
		push_warning("Creature: Phase 1 creature needs --phase1; idle")
		return
	_ok = true
	_rng.seed = Game.seed_value
	for id in [&"lurk_speed_mps", &"stalk_speed_mps", &"chase_speed_mps"]:
		_num[id] = float(Data.value(&"creature", id, &"speed_mps"))
	for id in [&"lure_wait_s", &"stalk_max_s", &"chase_commit_s", &"retreat_s", &"hearing_memory_s", &"chase_lose_quiet_s"]:
		_num[id] = float(Data.value(&"creature", id, &"seconds"))
	for id in [&"reach_m", &"sight_night_m", &"sight_day_m", &"sight_still_crouch_m"]:
		_num[id] = float(Data.value(&"creature", id, &"metres"))
	_num[&"corn_damp_mult"] = float(Data.value(&"creature", &"corn_damp_mult", &"mult"))
	for id in [&"night_s", &"scripted_lurk_s", &"scripted_chase_after_stalk_s", &"scripted_retreat_s"]:
		_num[id] = float(Data.value(&"phase1", id, &"seconds"))
	for door in get_tree().get_nodes_in_group(&"doors"):
		var r := Rect2()
		var first := true
		for c in door.get_parent().get_children():
			if c is Node3D and String(c.name).contains("Wall"):
				var p := Vector2(c.global_position.x, c.global_position.z)
				r = Rect2(p, Vector2.ZERO) if first else r.expand(p)
				first = false
		_rects.append(r)
	global_position = _marker(&"creature_cover", DAY_COVER)
	NoiseBus.noise_emitted.connect(_on_noise)
	Clock.phase_changed.connect(func(p: StringName) -> void:
		if p == &"night" and not _test:
			_start_night()
		elif p == &"dawn" and not _test:
			_night_t = -1.0)
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what == &"farm_state":  # a late joiner gets the current state
			Net.to_peers(&"apply_creature_state", [state, body], [peer]))
	if _test or Clock.phase == &"night":
		_start_night()


func _physics_process(delta: float) -> void:
	if not Game.is_host():
		global_position = global_position.lerp(_target_pos, 1.0 - exp(-10.0 * delta))
		rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-10.0 * delta))
		return
	if not _ok:
		return
	_now += delta
	_t_state += delta
	_check_traps()
	if _night_t >= 0.0:
		_night_t += delta
		_night(delta)
	_move(delta)
	_log_t += delta
	if _log and _log_t >= 5.0:
		_log_t = 0.0
		Log.event(&"creature_debug", {"state": String(state), "position": _v(global_position), "goal": null if _goal == Vector3.INF else _v(_goal),
			"memory": _memory.size(), "seen": _seen.keys(), "night_t": snappedf(_night_t, 0.1)})
	_send_t += delta
	if _send_t >= 1.0 / SEND_HZ:
		_send_t = 0.0
		var pkt := PackedByteArray([PKT, STATES.find(state)])
		pkt.resize(PKT_BYTES)
		pkt.encode_float(2, global_position.x)
		pkt.encode_float(6, global_position.y)
		pkt.encode_float(10, global_position.z)
		pkt.encode_float(14, rotation.y)
		Net.send_bytes(0, pkt)


# --- night ---------------------------------------------------------------------------------------

func _start_night() -> void:
	_night_t = 0.0
	_nights += 1
	_stalk_at = -1.0
	_scripted = true
	_trap_i = 0
	_memory.clear()
	_set_state(&"lurk", &"night", 0)
	_goal = Vector3.INF


func _night(delta: float) -> void:
	if _test and _night_t >= _num[&"night_s"]:
		_start_night()
		return
	var times: Array = Data.value(&"phase1", &"trap_set_at_s", &"seconds_list")
	if _trap_i < times.size() and _night_t >= float(times[_trap_i]):
		_set_trap(_trap_i)
		_trap_i += 1
	_sense()
	if _lure:
		_track_lure()
	if _scripted:
		_run_script()
	else:
		_hunt(delta)


func _run_script() -> void:
	if _stalk_at < 0.0 and _night_t >= _num[&"scripted_lurk_s"]:
		for p in Game.players:
			if _alive(p) and _outdoor(Game.players[p].pos):
				_stalk_at = _night_t
				target = p
				break
	var s := Logic.scripted_state(_night_t, _stalk_at, _num[&"scripted_lurk_s"], _num[&"scripted_chase_after_stalk_s"],
		_num[&"scripted_retreat_s"], _num[&"scripted_retreat_s"])
	if s == &"":
		_scripted = false
		_set_state(&"lurk", &"script_done", 0)
		return
	if s != state:
		_set_state(s, &"scripted", target if s != &"lurk" else 0)
	match state:
		&"stalk", &"chase":
			if _alive(target):
				_goal = Game.players[target].pos  # scripted: doc 03 section 18 names the player
				if state == &"chase" and _goal.distance_to(global_position) <= _num[&"reach_m"]:
					_scripted = false
					caught.emit(target)
					_set_state(&"retreat", &"reached", target)
		&"retreat":
			_goal_retreat()
		&"lurk":
			_wander()


## Doc 03 sections 4.2 and 5, by sound and sight only.
func _hunt(delta: float) -> void:
	var heard := Logic.pick_heard(_memory, _now, _num[&"hearing_memory_s"], LOUDER_WINS_S)
	match state:
		&"lurk":
			if not heard.is_empty():
				_search_until = -1.0
				var p := int(heard.peer)
				if _alive(p) and _now - _last_lure_t >= LURE_COOLDOWN_S and _lone(p) and _play_lure(p):
					return
				_set_state(&"stalk", &"heard_" + String(heard.kind), p)
			elif _search_until >= _now and _goal != Vector3.INF:
				pass  # searching the last sensed position (section 5)
			else:
				_wander()
		&"lure":
			pass  # waits by the source; _track_lure ends it
		&"stalk":
			var sensed := _sensed_pos(target, heard)
			if sensed == Vector3.INF:
				_set_state(&"lurk", &"lost_track", 0)
				return
			_goal = sensed
			if target == 0:  # a noise with no player behind it (a dead generator): look, then go back
				if sensed.distance_to(global_position) < 2.0 or _t_state >= _num[&"stalk_max_s"]:
					_memory.clear()
					_set_state(&"lurk", &"investigated", 0)
				return
			var seen := _seen.has(target) and _now - float(_seen[target].t) < 0.5
			var sprint := not heard.is_empty() and int(heard.peer) == target and String(heard.kind).begins_with("step_sprint") and _now - float(heard.t) < 0.5
			if seen or sprint or sensed.distance_to(global_position) <= STALK_CHASE_M:
				_set_state(&"chase", &"seen" if seen else (&"sprint" if sprint else &"close"), target)
			elif _t_state >= _num[&"stalk_max_s"]:
				_memory.clear()
				_set_state(&"lurk", &"stalk_max", 0)
		&"chase":
			_chase_t += delta
			var seen := _seen.has(target) and _now - float(_seen[target].t) < 0.2
			var loud := false
			for e in _memory:
				if int(e.peer) == target and _now - float(e.t) < 0.2:
					loud = true
			_lose_t = 0.0 if seen or loud else _lose_t + delta
			var sensed := _sensed_pos(target, {})
			if sensed != Vector3.INF:
				_goal = sensed
			if _alive(target) and Game.players[target].pos.distance_to(global_position) <= _num[&"reach_m"]:
				caught.emit(target)
				_end_chase(&"retreat", &"reached")
			elif _alive(target) and _in_lit_doorway(Game.players[target].pos):
				_end_chase(&"lit_building", &"lit_building")
			elif not _alive(target) or (_chase_t >= _num[&"chase_commit_s"] and _lose_t >= _num[&"chase_lose_quiet_s"]):
				_end_chase(&"lost", &"lost")
		&"retreat":
			if _t_state >= _num[&"retreat_s"]:
				_set_state(&"lurk", &"retreat_done", 0)
			else:
				_goal_retreat()


func _end_chase(how: StringName, reason: StringName) -> void:
	if how == &"lost":
		_search_until = _now + _num[&"hearing_memory_s"]  # section 5: search for `memory` seconds
		_memory.clear()
		_set_state(&"lurk", reason, 0)
		# _goal stays at the last sensed position
	else:
		_set_state(&"retreat", reason, target)


## Latest sensed position of `peer`: seen, else its newest heard entry, else the picked entry.
func _sensed_pos(peer: int, heard: Dictionary) -> Vector3:
	if _seen.has(peer) and _now - float(_seen[peer].t) < _num[&"hearing_memory_s"]:
		var s: Dictionary = _seen[peer]
		var newest: Dictionary = {}
		for e in _memory:
			if int(e.peer) == peer and float(e.t) > float(s.t) and (newest.is_empty() or float(e.t) > float(newest.t)):
				newest = e
		return s.position if newest.is_empty() else newest.position
	var best: Dictionary = {}
	for e in _memory:
		if int(e.peer) == peer and _now - float(e.t) <= _num[&"hearing_memory_s"] and (best.is_empty() or float(e.t) > float(best.t)):
			best = e
	if not best.is_empty():
		return best.position
	return Vector3.INF if heard.is_empty() else heard.position


## P1-09: the trap race sets the state it needs (chase while pinned, retreat or lurk after).
func force_state(s: StringName, reason: StringName, p_target: int) -> void:
	if _ok:
		_set_state(s, reason, p_target)


func _set_state(s: StringName, reason: StringName, p_target: int) -> void:
	if s == state and p_target == target:
		return
	var from := state
	var old_target := target
	state = s
	target = p_target
	_t_state = 0.0
	if s == &"chase" and from != &"chase":
		_chase_t = 0.0
		_lose_t = 0.0
		Log.event(&"chase_started", {"target": target})
	elif from == &"chase" and s != &"chase":  # doc 05 section 18 `how`: lost, lit_building, kill, retreat
		Log.event(&"chase_ended", {"target": old_target, "how": String(reason) if reason in [&"lost", &"lit_building"] else "retreat"})
	if s == &"retreat":
		_goal = Vector3.INF
	Log.event(&"creature_state", {"from": String(from), "to": String(s), "reason": String(reason),
		"position": _v(global_position), "target": target if target != 0 else null})
	if from != s:
		Net.to_peers(&"apply_creature_state", [state, body])
		state_changed.emit(state, body)


# --- senses (doc 03 section 3) -------------------------------------------------------------------

func _on_noise(position: Vector3, radius_m: float, kind: StringName, source_peer: int) -> void:
	if _night_t < 0.0:
		return
	var r := radius_m
	if kind != &"step_sprint_corn" and _blocked(global_position + Vector3.UP, position + Vector3.UP, 16):
		r *= _num[&"corn_damp_mult"]
	var d := global_position.distance_to(position)
	if d > r:
		return
	_memory.append({"position": position, "margin": r - d, "t": _now, "peer": source_peer, "kind": kind})
	_last_heard = position
	_memory = _memory.filter(func(e: Dictionary) -> bool: return _now - float(e.t) <= _num[&"hearing_memory_s"])


func _sense() -> void:
	var range_m: float = _num[&"sight_night_m"] if _night_t >= 0.0 else _num[&"sight_day_m"]
	for p in Game.players:
		if not _alive(p):
			continue
		var st: Dictionary = Game.players[p]
		var head: Vector3 = st.pos + Vector3.UP * (EYE_CROUCH_M if bool(st.get("crouch", false)) else EYE_M)
		var r := range_m
		if bool(st.get("crouch", false)) and bool(st.get("is_still", false)):
			r = minf(r, _num[&"sight_still_crouch_m"])
		if head.distance_to(global_position) <= r and not _blocked(global_position + Vector3.UP * EYE_M, head, 1 | 16):
			_seen[p] = {"position": st.pos, "t": _now}


func _blocked(from: Vector3, to: Vector3, mask: int) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- lures (doc 03 section 12) -------------------------------------------------------------------

## Presentation: picks the crow corn edge (doc 03 section 18) from the target's true position.
func _play_lure(p: int) -> bool:
	var pos: Vector3 = Game.players[p].pos
	var src := Vector3.INF
	var ids: Array = Data.value(&"phase1", &"stranger_voice_spots", &"ids")
	for id in ids:
		var m := _marker(&"crow_perches", id)
		var d := m.distance_to(pos)
		if d >= LURE_MIN_M and d <= LURE_MAX_M and (src == Vector3.INF or d < src.distance_to(pos)):
			src = m
	if src == Vector3.INF:
		return false
	var lines: Array = Data.records(&"voice_lines").filter(func(r: Dictionary) -> bool:
		return r.get("kind") == "stranger" and bool(r.get("phase1", false)))
	_lure_n += 1
	_last_lure_t = _now
	var tell: StringName = TELLS[0] if _rng.randf() < 1.0 / 3.0 else TELLS[_rng.randi_range(1, TELLS.size() - 1)]
	_lure = {"lure_id": "lure_%d" % _lure_n, "target": p, "position": src, "start_d": src.distance_to(pos), "moved_m": 0.0, "t0": _now}
	Log.event(&"lure_played", {"lure_id": _lure.lure_id, "owner": null, "line_id": lines[_rng.randi() % lines.size()].id,
		"sound_id": null, "target": p, "position": _v(src), "tell": String(tell), "ghost": false})
	# Night lures are world sounds (doc 03 section 12.1): everyone hears, target slot -1.
	Net.to_peers(&"apply_lure", [_lure.lure_id, "stranger", src, -1, tell, false])
	_set_state(&"lure", &"lone_player", p)
	_goal = src + (src - global_position).normalized() * 3.0  # waits by the source's far side
	return true


func _track_lure() -> void:
	var p: int = _lure.target
	var elapsed := _now - float(_lure.t0)
	if _alive(p):
		_lure.moved_m = Logic.lure_moved(_lure.moved_m, _lure.start_d, Game.players[p].pos.distance_to(_lure.position))
	var worked: bool = _lure.moved_m > LURE_WORKED_M
	if not worked and elapsed < _num[&"lure_wait_s"]:
		return
	Log.event(&"lure_result", {"lure_id": _lure.lure_id, "target": p, "moved_m": _lure.moved_m,  # unrounded: check_logs re-applies "> 10 m"
		"within_s": snappedf(elapsed, 0.01) if worked else _num[&"lure_wait_s"], "window_s": _num[&"lure_wait_s"], "worked": worked})
	var src: Vector3 = _lure.position
	_lure = {}
	if state != &"lure":
		return
	if worked:  # doc 03 section 4.2 lure -> stalk; it heads for the source it sent them to
		_memory.append({"position": src, "margin": 0.0, "t": _now, "peer": p, "kind": &"lure"})
		_set_state(&"stalk", &"lure_worked", p)
	else:
		_set_state(&"lurk", &"lure_failed", 0)


# --- traps (doc 03 sections 9 and 18) ------------------------------------------------------------

## One bear trap and one pit; the third and fourth set times move them to new spots (doc 03 section 4
## "sets and moves traps"; reading of section 18, see production/handoffs/P1-08.md).
func _set_trap(i: int) -> void:
	var kind := &"bear" if i % 2 == 0 else &"pit"
	if _traps.has(kind) and not _traps[kind].armed:
		return  # a sprung trap stays where it is (the trap race is P1-09)
	var ids: Array = Data.value(&"phase1", &"scripted_trap_spots", &"ids")
	var spots := get_tree().get_nodes_in_group(&"trap_spots").filter(func(n: Node) -> bool:
		return ids.has(String(n.name)) and (kind == &"bear" or n.get_meta("kind", "") != "deep"))
	var used: Array = _traps.values().map(func(t: Dictionary) -> String: return t.id)
	spots = spots.filter(func(n: Node) -> bool: return not used.has(String(n.name)))
	var n: Node3D = spots[(_nights * 4 + i) % spots.size()]
	_traps[kind] = {"id": String(n.name), "kind": kind, "position": n.global_position, "deep": n.get_meta("kind", "") == "deep", "armed": true}
	Log.event(&"trap_changed", {"trap_id": String(n.name), "state": "set", "by": "creature", "kind": String(kind)})
	if _test and _walker:  # QA: the host's walker steps on it, so trap_sprung fires
		_walker.nav_path = [n.global_position]


func _check_traps() -> void:
	for t in _traps.values():
		if not t.armed:
			continue
		for p in Game.players:
			if _alive(p) and Game.players[p].pos.distance_to(t.position) <= TRAP_SPRING_M:
				t.armed = false
				Log.event(&"trap_sprung", {"trap_id": t.id, "kind": String(t.kind), "player": p, "position": _v(t.position), "deep": t.deep})
				Log.event(&"trap_changed", {"trap_id": t.id, "state": "sprung", "by": p})
				trap_sprung.emit(t.id, t.kind, p, t.position, t.deep)
				break


# --- movement ------------------------------------------------------------------------------------

func _move(_delta: float) -> void:
	var speed: float = _num[&"lurk_speed_mps"]
	match state:
		&"stalk": speed = _num[&"stalk_speed_mps"]
		&"chase", &"retreat": speed = _num[&"chase_speed_mps"]
	if _night_t < 0.0:
		_goal = _marker(&"creature_cover", DAY_COVER)
	var d := Vector3.INF if _goal == Vector3.INF else _goal - global_position
	var stop := STALK_STANDOFF_M if state == &"stalk" and target != 0 else ARRIVE_M
	if d == Vector3.INF or Vector2(d.x, d.z).length() < stop:
		velocity = Vector3.ZERO
		if state == &"lurk" and _search_until < _now:
			_goal = Vector3.INF
		return
	d.y = 0.0
	velocity = d.normalized() * speed
	rotation.y = atan2(-d.x, -d.z)
	move_and_slide()
	global_position.y = 0.0


## Lurk: walk between cover points and trap spots in its region (doc 03 section 4).
func _wander() -> void:
	if _goal != Vector3.INF:
		return
	var pts := get_tree().get_nodes_in_group(&"creature_cover") + get_tree().get_nodes_in_group(&"trap_spots")
	var near := pts.filter(func(n: Node3D) -> bool: return _last_heard != Vector3.INF and n.global_position.distance_to(_last_heard) <= REGION_M)
	if not near.is_empty():
		pts = near
	_goal = (pts[_rng.randi() % pts.size()] as Node3D).global_position


func _goal_retreat() -> void:
	if _goal != Vector3.INF:
		return
	var far := global_position
	for n in get_tree().get_nodes_in_group(&"creature_cover"):
		if (n as Node3D).global_position.distance_to(global_position) > far.distance_to(global_position):
			far = n.global_position
	_goal = far


# --- helpers -------------------------------------------------------------------------------------

func _alive(p: int) -> bool:
	return Game.players.has(p) and Game.players[p].has("pos") and not Game.is_ghost(p)


func _outdoor(pos: Vector3) -> bool:
	for r in _rects:
		if r.has_point(Vector2(pos.x, pos.z)):
			return false
	return true


## Presentation: no other living player within LONE_M (true positions, for lure targeting only).
func _lone(p: int) -> bool:
	for q in Game.players:
		if q != p and _alive(q) and Game.players[q].pos.distance_to(Game.players[p].pos) < LONE_M:
			return false
	return true


func _in_lit_doorway(pos: Vector3) -> bool:
	var gen := get_parent().get_node_or_null(^"Generator")
	if gen == null or gen.damaged or gen.fuel_s <= 0.0:
		return false
	for d in get_tree().get_nodes_in_group(&"doors"):
		if (d as Node3D).global_position.distance_to(pos) <= LIT_DOOR_M:
			return true
	return false


func _marker(group: StringName, id: String) -> Vector3:
	for n in get_tree().get_nodes_in_group(group):
		if String(n.name) == id:
			return (n as Node3D).global_position
	push_error("Creature: no %s marker %s" % [group, id])
	return Vector3.ZERO


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]


# --- clients -------------------------------------------------------------------------------------

func _on_bytes(_from: int, pkt: PackedByteArray) -> void:
	if Game.is_host() or pkt.size() < PKT_BYTES or pkt[0] != PKT:
		return
	_target_pos = Vector3(pkt.decode_float(2), pkt.decode_float(6), pkt.decode_float(10))
	_target_yaw = pkt.decode_float(14)


func _on_apply(what: StringName, args: Array) -> void:
	match what:
		&"creature_state":
			if args[0] != state:
				state = args[0]
				body = args[1]
				if _log:
					Log.event(&"creature_state_applied", {"state": String(state), "body": String(body)})
				state_changed.emit(state, body)
		&"lure":
			if _test:
				_test_lure_heard(args[2])


# --- debug (doc 05 section 19) -------------------------------------------------------------------

func debug_sensed() -> Array:
	var out: Array = []
	for e in _memory:
		out.append({"peer": e.peer, "position": e.position, "age_s": _now - float(e.t), "source_kind": String(e.kind)})
	for p in _seen:
		out.append({"peer": p, "position": _seen[p].position, "age_s": _now - float(_seen[p].t), "source_kind": "sight"})
	return out


func debug_state() -> Dictionary:
	return {"state": state, "body": body, "target": target, "position": global_position, "goal": _goal,
		"scripted": _scripted, "night_t": _night_t, "timers": {"state_s": _t_state, "chase_s": _chase_t, "quiet_s": _lose_t},
		"noise_memory": _memory.size(), "lure": _lure.duplicate(), "traps": _traps.duplicate(true)}


# --- QA walker (`-- --creature-test`) ------------------------------------------------------------

const TEST_LOOP := [Vector3(0, 0, 6), Vector3(25, 0, 10), Vector3(40, 0, 25), Vector3(20, 0, 35),
	Vector3(-20, 0, 20), Vector3(-16, 0, -12), Vector3(-12, 0, 5)]
var _walker: Node
var _walk_i := 0


func _test_walk() -> void:
	var players := get_parent().get_node_or_null(^"Players")
	for i in 60:
		_walker = players.player(Game.local_peer()) if players else null
		if _walker:
			break
		await get_tree().physics_frame
	if _walker == null:
		return
	_walker.nav_path = [Vector3(0, 0, -4)]
	_walk_i = (Game.local_peer() % 7) if not Game.is_host() else 0
	var last: Vector3 = _walker.global_position
	var t := 0.0
	while is_inside_tree():
		t += get_physics_process_delta_time()
		if t >= 3.0:  # stuck on corn or a wall: skip the waypoint
			t = 0.0
			if _walker.global_position.distance_to(last) < 1.0:
				_walker.nav_path.clear()
			last = _walker.global_position
		if _walker.nav_path.is_empty():
			_walk_i = (_walk_i + 1) % TEST_LOOP.size()
			_walker.nav_path = [TEST_LOOP[_walk_i]]
		await get_tree().physics_frame


## Synthetic: half the time the walker heads for the lure source, so lure_result shows both answers.
func _test_lure_heard(src: Vector3) -> void:
	if _walker and _rng.randf() < 0.5:
		_walker.nav_path = [Vector3(src.x, 0, src.z)]
