extends CharacterBody3D
## Doc 03 sections 3 to 5, 9, 12 and 18: the DD Phase 1 creature ("fake it first"). The host runs all
## of it; clients only show the placeholder body from the 15 Hz `creature` packet and mirror the state
## from `apply_creature_state` (doc 06 section 7). Ambience hooks connect to `state_changed`.
##
## Night: scripted lurk 60 s, stalk the first outdoor player, chase, retreat (doc 03 section 18);
## then it wanders and hunts by sound: it homes on what it heard or saw (sections 3.1, 3.2), never on
## a true position, and loses a chase by section 5. On the Phase 1 farm it sets one bear trap and one pit
## at the four scripted times (section 18); on the full farm (`--full-farm`, P2-05) it tops up the night's
## counts from `ramp_up.json` on spots near where it heard players work; its bear traps are the farm's own,
## taken at nightfall from hands, then the pegboard (D-053, section 9, "9.1 As built"). Traps show to every peer as a close-range clue, and it plays lures
## (section 12, P2-04: recorded clips, sound lures, stranger lines) from crow corn edges and cover points
## as world sounds, in the scripted lurk too. Taint (P3-07, sections 3.3 and 8; off on the Phase 1 farm by
## `phase1.json` `taint_enabled`): at night it tracks Tainted players and leaves stains. After the scripted night the AI
## Director (P3-04, game/ai_director/) gates its lures, stalks, chases and kills and sets its wander region.
## Day: it waits in far cover and, from the day's second third, sends a targeted lure now and then from a
## trap spot, the target picked by the AI Director's scare budget.
##
## Presentation may read true positions (lure targeting, the trap spring check, the lit doorway rule);
## hunting never does, except the scripted stalk and chase, which doc 03 section 18 scripts at "the
## first outdoor player" (debug_state shows `scripted`).
##
## QA flags: `-- --creature-test` starts a night at once, repeats it every `night_s`, walks the local
## player round the yard and turns it toward half the lures it hears (synthetic, measures plumbing,
## not players). `-- --creature-walk` walks and turns the same way but keeps the real clock (day lures).
## `-- --log-creature` logs `apply_creature_state` and `apply_trap_changed` arrivals on clients.
## `-- --shed-lock` gives the team the pegboard lock (the store does not sell it yet). `-- --give-trap` puts a
## bear trap in every living player's hands at nightfall (full farm), so theft runs under `multi.py`.
## `-- --take-loose` (host) walks the host player to a loose trap that turned up at dawn and picks it up.

signal state_changed(state: StringName, body: StringName)
## Host only (P1-09): the creature reached `peer` in a chase / a living player sprang an armed trap.
signal caught(peer: int)
signal trap_sprung(trap_id: String, kind: StringName, peer: int, position: Vector3, deep: bool)
## Host only (P3-04): a noise passed the hearing check; the AI Director's meter input (doc 03 section 11.1).
signal heard(radius_m: float, kind: StringName, peer: int)

const Logic := preload("res://game/creature/creature_logic.gd")
const TrapPickup := preload("res://game/creature/trap_pickup.gd")
const STATES: Array[StringName] = [&"lurk", &"lure", &"stalk", &"chase", &"retreat"]
const PKT := 0x03  ## doc 06 section 7 `creature` packet type (movement is 1 and 2, voice 0x10/0x11)
const PKT_BYTES := 18  ## type u8, state u8, position 3 x f32, yaw f32
const SEND_HZ := 15.0  ## doc 06 section 7 (placeholder)
const EYE_M := 1.65  ## doc 03 section 3.2, CONTRACTS section 4
const EYE_CROUCH_M := 0.9  ## placeholder: crouched head height for the sight ray
const STALK_CHASE_M := 12.0  ## doc 03 section 4.2: at night a sensed target this close starts a chase
const STALK_STANDOFF_M := 10.0  ## placeholder: a stalk holds back this far ("just out of sight", section 4)
# chase_tell_s, scripted_standoff_m and trap_lure_m live in data/creature.json (P2-12, Q-048 (1)).
const REGION_M := 25.0  ## placeholder: lurk wanders among markers this near the last thing it heard
const LOUDER_WINS_S := 4.0  ## doc 03 section 3.1 (placeholder)
const LIT_DOOR_M := 6.0  ## doc 03 section 5 / doc 04 sec 8: lit doorway radius
const LURE_WORKED_M := 10.0  ## doc 01 "Voice mimicry": moved more than 10 m toward the source
const LURE_COOLDOWN_S := 20.0  ## placeholder: no doc number; a playtest settles it
const LURE_MIN_M := 12.0  ## placeholder: a source nearer than this cannot show a 10 m walk
const LURE_MAX_M := 40.0  ## placeholder: beyond this a stranger line is too faint to follow
const LONE_M := 15.0  ## inference: doc 03 section 4.2 "a lone player"; reuses the 15 m rule (doc 04 sec 8.3)
const CLUE_M := 4.0  ## doc 03 section 9: trap clues are seen within 4 m (placeholder)
const TRAP_SPRING_M := 1.0  ## placeholder: a living player this close to an armed trap springs it
const ARRIVE_M := 1.0
const DAY_COVER := "cover_15"  ## doc 04 sec 9: the far south cover point; where it waits by day (placeholder)
const BODY := &"body_gaunt"  ## shown until the host's season pick arrives (P4-13)
const TELLS: Array[StringName] = [&"none", &"echo", &"pitch_up", &"pitch_down", &"no_crackle"]  ## doc 03 section 12.2
# P2-04 recorded lures (doc 03 section 12.1). Whose-voice weights are `ai_director.json` `lures` (P3-03).
## Doc 03 section 16 "Day or night use"; which lines fit both is a placeholder reading. A name call fits both.
const DAY_LINES := ["come_look_at_this", "i_found_something", "its_fine_come_on", "wait_for_me"]
const NIGHT_LINES := ["over_here", "help_me", "where_are_you", "wait_for_me", "its_fine_come_on"]
## Doc 03 section 16 sound lures with a sound in the Soundscape catalog: [catalog id, plays, gap s] (placeholder).
## hoe_fake, watering_can_fake and shovel_fake wait for their assets (Audio Designer).
const SOUND_LURES := {"step_walk_fake": [&"sfx_step_dirt", 8, 0.55], "step_run_fake": [&"sfx_step_dirt", 10, 0.3],
	"door_fake": [&"cre_door_bang", 1, 0.0]}
const DAY_RULE_M := 15.0  ## doc 03 section 12.1 "the 15 m rule": a day source this far from every teammate of the target
const COULD_NOT_BE_M := 25.0  ## doc 03 section 12.2: the source this far from the living teammate it voices
const VOICE_CHAIN := "res://game/audio/voice_chain.gd"  ## Audio Designer's tell buses (P2-08); VoiceBase without it
# P2-05 full-farm traps (doc 03 section 9).
const TRAP_GAP_M := 8.0  ## doc 03 section 9: at most one trap in any 8 m circle (placeholder)
const WORK_MAX := 64  ## placeholder: heard player noises kept as "where they work" for spot choice
const TRAP_SET_FROM := 0.1  ## placeholder: the night's sets spread from 10% to 75% of the night
const TRAP_SET_SPAN := 0.65
const TRAP_WAIT_S := 30.0  ## placeholder (P2-28, CEO): a set waits this long for lurk, then lands in any state
# P3-07 Taint tracking (doc 03 section 3.3) and leavings (section 8).
const TRAIL_STEP_S := 1.0  ## placeholder: a Tainted player's night trail keeps one point per second
const TRAIL_PICKUP_M := 3.0  ## placeholder: it finds a trail within this distance of one of its points
const TRAIL_LEAD := 3  ## placeholder: it homes on the point this many steps newer than the one it stands at
const TRACK_EVERY_S := 0.1  ## placeholder: a tracked fix goes into its memory this often (keeps a chase from going quiet)
const TRAP_KINDS := {&"bear": [&"bear_trap", "bear_4p"], &"pit": [&"pit", "pit_4p"]}  ## traps.json id, ramp_up field; bells wait (enabled false)

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
var _harvest := false  ## P4-12: the Harvest Moon is running (doc 03 section 14)
var _bite_cart := false  ## P4-12: it knocked a pusher off and goes for the pumpkin
var _goal := Vector3.INF
var _memory: Array = []  ## heard: {position, margin, t, peer, kind}
var _seen: Dictionary = {}  ## peer -> {position, t}
var _chase_t := 0.0
var _lose_t := 0.0
var _search_until := -1.0
var _lure: Dictionary = {}
var _lure_n := 0
var _last_lure_t := -INF
var _traps: Dictionary = {}  ## trap id (spot name) -> {id, kind, position, deep, armed}
var _trap_i := 0
var _full := Game.full_farm  ## P2-05 traps and theft; the Phase 1 farm keeps the scripted traps
var _flare_retreat_s := 0.0  ## P4-06: a flare hit's longer Retreat; 0 means the normal one
var shed_lock := OS.get_cmdline_user_args().has("--shed-lock")  ## the team owns the pegboard lock (store hook)
var _plan: Array = []  ## tonight's sets still to come: {t, kind}, sorted by t
var _work: Array = []  ## heard player noise positions, oldest first: the region players work in
var wipe_traps := 0  ## host: extra traps for the next night after a full wipe (doc 02 s14, set by Sabotage at dawn)
var _stash := 0  ## bear traps taken and not yet set: the creature's whole bear supply (D-053)
var _stolen_night := 0
var _capped_logged := false
var _kept: Dictionary = {}  ## peer -> building: held a bear trap in a lit building at nightfall (moved at dawn, D-053 (3))
var _theft_t := 0.0
var _nights := 0
var _rects: Array[Rect2] = []  ## building floors (x, z), for "outdoor"
var _rect_names: Array[String] = []  ## the building of each rect (the door's parent)
var _send_t := 0.0
var _log_t := 0.0
var _log := false
var _last_heard := Vector3.INF  ## outlives the memory: the region it wanders in (section 4 `lurk`)
var _rng := RandomNumberGenerator.new()
var _num: Dictionary = {}
var _dir: Node  ## AiDirector (P3-04): asked before lures, stalks, chases and kills
var _taint := false  ## P3-07: Taint tracking and leavings on (full farm, or phase1.json taint_enabled)
var _trail: Dictionary = {}  ## Tainted peer -> [{position, t}] tonight, oldest first
var _track_t: Dictionary = {}  ## peer -> _now of its last tracked fix
var _leave_m := 0.0  ## lurk and stalk metres walked since the last stain

# client only
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _clip_lures: Array = []  ## every peer: [owner, clip_id, AudioStreamPlayer3D] playing now
var _body_logged := false


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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clue-shot="):
			_clue_shot = a.trim_prefix("--clue-shot=")
	Net.apply_received.connect(_on_apply)
	Net.bytes_received.connect(_on_bytes)
	Voice.clips.clip_freed.connect(_on_clip_freed)
	# Every peer starts it in its day cover (P2-26): left at the origin it stood at the barn door whenever the
	# host had it idle, and on a client until the first `creature` packet.
	global_position = _marker(&"creature_cover", DAY_COVER)
	_target_pos = global_position
	if (_test or OS.get_cmdline_user_args().has("--creature-walk")) and not OS.get_cmdline_user_args().has("--autowalk"):  # --autowalk: players circle instead
		_test_walk.call_deferred()
	if not Game.is_host():
		return
	_pick_body()
	_num[&"sanctuary_m"] = float(Data.value(&"ai_director", &"scare_rules", &"sanctuary_m"))  # Q-089: the AI Director asks even without --phase1
	if not Data.has_table(&"phase1"):
		push_warning("Creature: Phase 1 creature needs --phase1; idle")
		return
	_ok = true
	_rng.seed = Game.seed_value
	_dir = get_tree().get_first_node_in_group(&"ai_director")  # main adds it before the Creature
	_num[&"day_gap_s"] = float(Data.value(&"ai_director", &"lures", &"day_gap_s"))
	for id in [&"lurk_speed_mps", &"stalk_speed_mps", &"chase_speed_mps"]:
		_num[id] = float(Data.value(&"creature", id, &"speed_mps"))
	for id in [&"lure_wait_s", &"stalk_max_s", &"chase_commit_s", &"retreat_s", &"hearing_memory_s", &"chase_lose_quiet_s", &"chase_tell_s"]:
		_num[id] = float(Data.value(&"creature", id, &"seconds"))
	for id in [&"reach_m", &"sight_night_m", &"sight_day_m", &"sight_still_crouch_m", &"scripted_standoff_m", &"trap_lure_m"]:
		_num[id] = float(Data.value(&"creature", id, &"metres"))
	_num[&"corn_damp_mult"] = float(Data.value(&"creature", &"corn_damp_mult", &"mult"))
	for f in [&"weight_dead", &"weight_alive", &"weight_own", &"weight_stranger"]:
		_num[f] = float(Data.value(&"ai_director", &"lures", f))
	for id in [&"night_s", &"scripted_lurk_s", &"scripted_chase_after_stalk_s", &"scripted_retreat_s"]:
		_num[id] = float(Data.value(&"phase1", id, &"seconds"))
	_taint = _full or bool(Data.value(&"phase1", &"taint_enabled", &"flag"))
	_num[&"taint_tracking_radius_m"] = float(Data.value(&"creature", &"taint_tracking_radius_m", &"metres"))
	_num[&"leavings_every_m"] = float(Data.value(&"creature", &"leavings_every_m", &"metres"))
	_num[&"taint_trail_s"] = float(Data.value(&"creature", &"taint_trail_s", &"seconds"))
	for door in get_tree().get_nodes_in_group(&"doors"):
		var r := Rect2()
		var first := true
		for c in door.get_parent().get_children():
			if c is Node3D and String(c.name).contains("Wall"):
				var p := Vector2(c.global_position.x, c.global_position.z)
				r = Rect2(p, Vector2.ZERO) if first else r.expand(p)
				first = false
		_rects.append(r)
		_rect_names.append(String(door.get_parent().name))
	NoiseBus.noise_emitted.connect(_on_noise)
	Clock.phase_changed.connect(func(p: StringName) -> void:
		if p == &"night" and not _test:
			_start_night()
		elif p == &"harvest_moon" and not _test:
			_start_harvest()
		elif p == &"dawn" and not _test:
			_night_t = -1.0
			_harvest = false
			if _full:
				_dawn_traps())
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what == &"farm_state":  # a late joiner gets the current state and the armed traps
			Net.to_peers(&"apply_creature_state", [state, body], [peer])
			for t in _traps.values():
				if t.armed:
					Net.to_peers(&"apply_trap_changed", [t.id, t.kind, &"set", t.position], [peer]))
	if _test or Clock.phase == &"night":
		_start_night.call_deferred()  # after the TrapSweep sibling is ready: theft reads the pegboard


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
	elif Clock.phase == &"day" and _dir.third() >= 2 and not _lure and _now - _last_lure_t >= _num[&"day_gap_s"]:
		_try_day_lure()  # doc 03 section 11.3: no lures in the calm first third
	if _lure:
		_track_lure()
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
	if _full and _test and _nights > 0:  # --creature-test has no dawn: the last night ends here
		_dawn_traps()
	_night_t = 0.0
	_nights += 1
	_stalk_at = -1.0
	_scripted = true
	_trap_i = 0
	_memory.clear()
	_trail.clear()
	_set_state(&"lurk", &"night", 0)
	_goal = Vector3.INF
	if _full:
		_stolen_night = 0
		_capped_logged = false
		get_tree().call_group(&"cans", &"creature_move_cans")  # P2-27 (Gameplay): cans left away from home are moved at nightfall (items/cans.gd)
		if OS.get_cmdline_user_args().has("--give-trap"):  # QA: every living player holds a bear trap at nightfall
			for p in Game.players.keys().filter(_alive):
				get_parent().get_node(^"Farm").set_hands(p, bool(Game.players[p].get("shovel", false)), true)
		_plan_traps()


func _night(delta: float) -> void:
	if _harvest:
		_sense()
		_harvest_moon(delta)
		return
	if _test and _night_t >= _num[&"night_s"]:
		_start_night()
		return
	if _full:
		# Section 9: sets while in lurk; P2-28 (CEO): a set TRAP_WAIT_S overdue lands in any state.
		while not _plan.is_empty() and _night_t >= float(_plan[0].t) and (state == &"lurk" or _night_t >= float(_plan[0].t) + TRAP_WAIT_S):
			_place_trap(_plan.pop_front().kind, state != &"lurk")
		_theft_t += delta
		if _theft_t >= 1.0:
			_theft_t = 0.0
			_steal_traps(false)
	else:
		var times: Array = Data.value(&"phase1", &"trap_set_at_s", &"seconds_list")
		if _trap_i < times.size() and _night_t >= float(times[_trap_i]):
			_set_trap(_trap_i)
			_trap_i += 1
	_sense()
	if _scripted:
		_run_script()
	else:
		_hunt(delta)


## P4-12, doc 03 section 14: no scripted sequence and no ordinary traps on the Harvest Moon.
func _start_harvest() -> void:
	_night_t = 0.0
	_harvest = true
	_bite_cart = false
	_scripted = false
	_plan.clear()
	_memory.clear()
	_set_state(&"lurk", &"harvest_moon", 0)
	_goal = Vector3.INF


## Doc 03 section 14. Act 1: it hunts as at night. Act 2: it lunges at the pusher it senses loudest (section 3.1),
## knocks them off (reach on the true position, like a catch), then bites the pumpkin in the stall and retreats.
## Act 3: it chases a sensed pusher, the guaranteed peak. Who it picks comes from what it senses only.
func _harvest_moon(delta: float) -> void:
	var cart := get_tree().get_first_node_in_group(&"cart")
	if cart == null or cart.act < cart.PUSH:
		_hunt(delta)
		return
	if cart.act == cart.DONE:
		_bite_cart = false
		if state != &"retreat":
			_goal = Vector3.INF
			_set_state(&"retreat", &"cart_done", 0)
		_goal_retreat()
		return
	if _bite_cart:
		_goal = cart.body.global_position  # it is at the cart: it just knocked the pusher off
		if cart.stall_s <= 0.0 or Vector2(_goal.x - global_position.x, _goal.z - global_position.z).length() <= _num[&"reach_m"] + 1.0:
			_bite_cart = false
			_set_state(&"retreat", &"bit_pumpkin" if cart.bite() else &"knock_off", 0)
			# ponytail: a straight 30 m back-off (placeholder), not the farthest cover: act 3 needs it near (Q-129)
			var away := global_position - _goal
			_goal = global_position + Vector3(away.x, 0.0, away.z).normalized() * 30.0
		return
	if cart.act == cart.PUSH and state == &"chase":
		var sensed := _sensed_pos(target, {})
		if sensed != Vector3.INF:
			_goal = sensed
		if not cart.knock_ready() or not cart.pushers.has(target) or _t_state >= _num[&"stalk_max_s"]:
			_set_state(&"lurk", &"knock_off", 0)
		elif _t_state >= _num[&"chase_tell_s"] and _alive(target) and Game.players[target].pos.distance_to(global_position) <= _num[&"reach_m"] and cart.knock(target):
			_bite_cart = true
		return
	if cart.act == cart.GATE_RUN and state == &"retreat" and _flare_retreat_s == 0.0:
		_goal = Vector3.INF
		_set_state(&"lurk", &"gate_run", 0)  # the guaranteed peak cuts a knock-off retreat short; a flare's holds
	if state in [&"chase", &"retreat", &"lure"]:
		_hunt(delta)  # act 3 chase and every retreat run as at night (catch, sanctuary, losing it)
		return
	var mem := _memory.filter(func(e: Dictionary) -> bool: return cart.pushers.has(int(e.peer)))
	var heard := Logic.pick_heard(mem if mem else _memory, _now, _num[&"hearing_memory_s"], LOUDER_WINS_S)
	var p := 0 if heard.is_empty() else int(heard.peer)
	for s in cart.pushers:  # sight finds a pusher it did not hear
		if p == 0 and _seen.has(s) and _now - float(_seen[s].t) < 0.5:
			p = s
	if heard.is_empty() and p == 0:
		_set_state(&"lurk", &"lost_track", 0)
		if _dir.wander_region and _goal != Vector3.INF and not _dir.region_rect(_dir.wander_region).has_point(Vector2(_goal.x, _goal.z)):
			_goal = Vector3.INF  # acts 2 and 3: the AI Director's region (section 11.6) wins over an old lurk goal
		_wander()
		return
	_goal = _sensed_pos(p, heard) if p != 0 else heard.position
	var near := p != 0 and _goal.distance_to(global_position) <= STALK_STANDOFF_M + ARRIVE_M
	if cart.act == cart.GATE_RUN and p != 0 and _dir.allow(&"chase", p):
		_dir.spend(&"chase", p)
		_set_state(&"chase", &"gate_run", p)
	elif cart.act == cart.PUSH and near and cart.pushers.has(p) and cart.knock_ready():
		_set_state(&"chase", &"knock_off", p)  # the lunge carries the chase tell before the hit
	else:
		_set_state(&"stalk", &"heard_" + String(heard.kind) if heard and int(heard.peer) == p else &"seen", p)


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
	if s == &"lurk" and state == &"lure":
		return  # a lure from the scripted lurk runs until _track_lure ends it
	if s != state:
		_set_state(s, &"scripted", target if s != &"lurk" else 0)
	match state:
		&"stalk", &"chase":
			if _alive(target):
				_goal = Game.players[target].pos  # scripted: doc 03 section 18 names the player
				if state == &"chase" and _t_state >= _num[&"chase_tell_s"] and _goal.distance_to(global_position) <= _num[&"reach_m"]:
					_scripted = false
					if _dir.allow(&"kill", target):  # sanctuary: no kill (doc 03 section 11.5)
						caught.emit(target)
					_set_state(&"retreat", &"reached", target)
		&"retreat":
			_goal_retreat()
		&"lurk":
			var heard := Logic.pick_heard(_memory, _now, _num[&"hearing_memory_s"], LOUDER_WINS_S)
			if heard.is_empty() or not _try_lure(int(heard.peer)):
				_wander()


## Doc 03 section 4.2 lurk -> lure: it heard `p` and a lure source fits (section 12.1). Outside the scripted
## night the AI Director budgets it (section 11.2).
func _try_lure(p: int) -> bool:
	if not _alive(p) or _now - _last_lure_t < LURE_COOLDOWN_S or not (_scripted or _dir.allow(&"lure", p)) or not _play_lure(p):
		return false
	if not _scripted:
		_dir.spend(&"lure", p)
	return true


## Doc 03 sections 4.2 and 5, by sound and sight only.
func _hunt(delta: float) -> void:
	var heard := Logic.pick_heard(_memory, _now, _num[&"hearing_memory_s"], LOUDER_WINS_S)
	match state:
		&"lurk":
			if not heard.is_empty():
				_search_until = -1.0
				var p := int(heard.peer)
				if _try_lure(p):
					return
				if not _dir.allow(&"stalk", p):  # out of build-up events, fading or relaxing: it keeps to its region
					_wander()
					return
				_dir.spend(&"stalk", p)
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
			if (seen or sprint or sensed.distance_to(global_position) <= STALK_CHASE_M) and _dir.allow(&"chase", target):
				_dir.spend(&"chase", target)  # chases only at peak (doc 03 section 11.2); else it holds the stalk
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
			if _alive(target) and not _dir.allow(&"kill", target):
				_end_chase(&"retreat", &"sanctuary")  # doc 03 section 11.5: no kill within 10 m of the town stand
			elif _alive(target) and _t_state >= _num[&"chase_tell_s"] and Game.players[target].pos.distance_to(global_position) <= _num[&"reach_m"]:
				caught.emit(target)
				_end_chase(&"retreat", &"reached")
			elif _alive(target) and _in_lit_doorway(Game.players[target].pos):
				_end_chase(&"lit_building", &"lit_building")
			elif not _alive(target) or (_chase_t >= _num[&"chase_commit_s"] and _lose_t >= _num[&"chase_lose_quiet_s"]):
				_end_chase(&"lost", &"lost")
		&"retreat":
			if _t_state >= maxf(_num[&"retreat_s"], _flare_retreat_s):
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


## P4-06 (store.json `flare_gun`): a flare hit sends it into Retreat for `seconds` (doc 01 Store: 30 s). False if it
## is not hunting yet (day, or before its night starts).
func flare_hit(seconds: float) -> bool:
	if not _ok or (_night_t < 0.0 and not _full):
		return false
	_flare_retreat_s = seconds
	if state == &"retreat":
		_t_state = 0.0  # a second hit restarts the 30 s
	else:
		_set_state(&"retreat", &"flare", 0)
	return true


func _set_state(s: StringName, reason: StringName, p_target: int) -> void:
	if s == state and p_target == target:
		return
	var from := state
	var old_target := target
	var state_s := _t_state
	state = s
	target = p_target
	_t_state = 0.0
	if s == &"chase" and from != &"chase":
		_chase_t = 0.0
		_lose_t = 0.0
		# start_m is the true distance, for the log only (OPEN_ISSUES 8): hunting never reads it
		Log.event(&"chase_started", {"target": target, "reason": String(reason),
			"start_m": snappedf(Game.players[target].pos.distance_to(global_position), 0.1) if _alive(target) else null})
	elif from == &"chase" and s != &"chase":  # doc 05 section 18 `how`: lost, lit_building, kill, retreat
		Log.event(&"chase_ended", {"target": old_target, "how": String(reason) if reason in [&"lost", &"lit_building"] else "retreat",
			"chase_s": snappedf(state_s, 0.01)})
	if s == &"retreat":
		_goal = Vector3.INF
	elif from == &"retreat":
		_flare_retreat_s = 0.0
	Log.event(&"creature_state", {"from": String(from), "to": String(s), "reason": String(reason),
		"position": _v(global_position), "target": target if target != 0 else null})
	if from != s:
		Net.to_peers(&"apply_creature_state", [state, body])
		state_changed.emit(state, body)


# --- senses (doc 03 section 3) -------------------------------------------------------------------

func _on_noise(position: Vector3, radius_m: float, kind: StringName, source_peer: int) -> void:
	if _night_t < 0.0 and not _full:
		return
	var r := radius_m
	if kind != &"step_sprint_corn" and _blocked(global_position + Vector3.UP, position + Vector3.UP, 16):
		r *= _num[&"corn_damp_mult"]
	var d := global_position.distance_to(position)
	if d > r:
		return
	if source_peer != 0:  # P2-05: where it heard players work, day and night, picks the trap region
		_work.append(position)
		if _work.size() > WORK_MAX:
			_work.pop_front()
	if _night_t < 0.0:
		return
	heard.emit(radius_m, kind, source_peer)
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
	if _taint and _night_t >= 0.0:
		_track_taint()


## Doc 03 section 3.3: it knows where a Tainted player is within the tracking radius, and farther off it can
## follow their last `taint_trail_s` of night trail once it comes across it. A fix goes into the hearing memory
## as kind `taint` (margin 0, so any real noise wins the pick), which also keeps a chase from going quiet
## (section 5: a Tainted player cannot lose a chase by quiet alone). Washing drops the trail (inference).
func _track_taint() -> void:
	for p in Game.players:
		if not _alive(p) or not bool(Game.players[p].get("tainted", false)):
			_trail.erase(p)
			continue
		var pos: Vector3 = Game.players[p].pos
		var tr: Array = _trail.get(p, [])
		_trail[p] = tr
		if tr.is_empty() or _now - float(tr[-1].t) >= TRAIL_STEP_S:
			tr.append({"position": pos, "t": _now})
		while not tr.is_empty() and _now - float(tr[0].t) > _num[&"taint_trail_s"]:
			tr.pop_front()
		if _now - float(_track_t.get(p, -INF)) < TRACK_EVERY_S:
			continue
		var fix := Logic.taint_fix(global_position, pos, tr, _num[&"taint_tracking_radius_m"], TRAIL_PICKUP_M, TRAIL_LEAD)
		if fix == Vector3.INF:
			continue
		_track_t[p] = _now
		_memory.append({"position": fix, "margin": 0.0, "t": _now, "peer": p, "kind": &"taint"})
		_last_heard = fix
	_memory = _memory.filter(func(e: Dictionary) -> bool: return _now - float(e.t) <= _num[&"hearing_memory_s"])


func _blocked(from: Vector3, to: Vector3, mask: int) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# --- lures (doc 03 section 12) -------------------------------------------------------------------

## Night (doc 03 section 4.2 lurk -> lure): a world lure at `p`; the creature waits by the source.
func _play_lure(p: int) -> bool:
	if not _lure_at(p, false):
		return false
	_set_state(&"lure", &"lone_player", p)
	_goal = _lure.position + (_lure.position - global_position).normalized() * 3.0  # waits by the source's far side
	return true


## Day (doc 03 section 11.3 thirds 2 and 3): a targeted lure at one outdoor living player. Private: no state
## change, the creature stays in cover. The AI Director picks the target within the scare budget (section 11.4).
func _try_day_lure() -> void:
	_last_lure_t = _now  # one attempt per gap, played or not
	var p: int = _dir.day_lure_target(Game.players.keys().filter(func(q: int) -> bool: return _alive(q) and _outdoor(Game.players[q].pos)))
	if p != 0 and _lure_at(p, true):
		_dir.spend(&"day_lure", p)


## Doc 03 section 12. Presentation: reads true positions. Picks whose voice (12.1), the source (12.1 the
## 15 m rule, 12.2 a place the voiced teammate could not be), one tell or none, then plays it: by day to the
## target only, by night as a world sound. Exact clips only: splicing (day 4 on) is not built, so `exact`
## is always true and `day` is logged.
func _lure_at(p: int, day: bool) -> bool:
	var v := _choose_voice(p, day)
	var src := _lure_source(p, day, int(v.owner))
	if src == Vector3.INF and int(v.owner) != 0:  # no place for that voice: the unattributed voice from any
		v = {"kind": "stranger", "owner": 0}
		src = _lure_source(p, day, 0)
	if src == Vector3.INF:
		return false
	_lure_n += 1
	_last_lure_t = _now
	var lure_id := "lure_%d" % _lure_n
	var tell: StringName = &"none"  # sound lures carry no voice tell (inference: section 12.2 tells are voice giveaways)
	if v.kind != "sound":
		tell = TELLS[0] if _rng.randf() < 1.0 / 3.0 else TELLS[_rng.randi_range(1, TELLS.size() - 1)]
	if Game.difficulty == &"nightmare":
		tell = &"none"  # doc 03 s7.2 / doc 02 s16: Nightmare has no voice tells (rolled anyway, so the seed stream matches)
	var ghost := int(v.owner) != 0 and Game.is_ghost(int(v.owner))  # doc 01 "Ghosts": the dead-voice twist
	var source := "stranger"
	match v.kind:
		"stranger":  # Soundscape plays STRANGER_LINES[hash(lure_id) % 6], the stranger records in voice_lines order
			var lines: Array = Data.records(&"voice_lines").filter(func(r: Dictionary) -> bool: return r.get("kind") == "stranger")
			v.line_id = lines[hash(lure_id) % lines.size()].id
		"sound":
			source = "sound:" + String(v.sound_id)
		"clip":
			source = "clip:%d:%s" % [v.owner, v.clip_id]
	var pos: Vector3 = Game.players[p].pos
	_lure = {"lure_id": lure_id, "target": p, "position": src, "start_d": src.distance_to(pos), "moved_m": 0.0, "t0": _now,
		"recorded_line": v.get("line_id") if v.kind == "clip" else null}
	Log.event(&"lure_played", {"lure_id": lure_id, "kind": v.kind, "owner": v.owner if int(v.owner) != 0 else null,
		"line_id": v.get("line_id"), "clip_id": v.get("clip_id"), "sound_id": v.get("sound_id"), "target": p,
		"heard_by": p if day else -1, "position": _v(src), "tell": String(tell), "ghost": ghost, "day": Clock.day, "exact": true,
		"owner_dead": int(v.owner) != 0 and Game.is_ghost(int(v.owner))})
	_send_lure([lure_id, source, src, p if day else -1, tell, ghost])
	return true


## Doc 03 section 12.1 "Whose voice": each player weighs dead 3, alive 1, own 0.1, plus the stranger. A
## player voices a clip only with `lobby_lines` and a fitting clip this machine holds; anyone else (Off,
## unchosen, a bot) gets a sound lure instead: footsteps and tools only (doc 01 "Habits").
func _choose_voice(p: int, day: bool) -> Dictionary:
	var opts: Array = [{"kind": "stranger", "owner": 0}]
	var w := PackedFloat32Array([_num[&"weight_stranger"]])
	for q: int in Game.players:
		w.append(Logic.voice_weight(q, p, Game.is_ghost(q), _num))
		var clips := _fitting_clips(q, p, day) if Game.voice_setting_of(q) == "lobby_lines" else []
		if clips.is_empty():
			opts.append({"kind": "sound", "owner": q, "sound_id": SOUND_LURES.keys()[_rng.randi() % SOUND_LURES.size()]})
		else:
			var id: String = clips[_rng.randi() % clips.size()]
			opts.append({"kind": "clip", "owner": q, "clip_id": id, "line_id": "name:" + id.trim_prefix("name_") if id.begins_with("name_") else id})
	return opts[_rng.rand_weighted(w)]


## `q`'s clips for a lure at `p`: the phase's fixed lines (section 16) and `p`'s name, never chatter. Own
## voice: no name call (a player calling their own name is no lure).
func _fitting_clips(q: int, p: int, day: bool) -> Array:
	var lines: Array = DAY_LINES if day else NIGHT_LINES
	var p_name := "name_" + str(Net.profiles.get(p, {}).get("uid", "-"))
	return Voice.clips.clip_ids(q).filter(func(id: String) -> bool: return id in lines or (q != p and id == p_name))


## The source point (doc 03 section 12.1 "Position"): a trap spot by day, a crow corn edge or cover point by
## night, LURE_MIN_M to LURE_MAX_M from the target, nearest first. Night without the lone rule: near an armed
## trap (`trap_lure_m`). Day: DAY_RULE_M from every teammate. A living voiced teammate: COULD_NOT_BE_M away.
func _lure_source(p: int, day: bool, owner: int) -> Vector3:
	var pos: Vector3 = Game.players[p].pos
	var lone := _lone(p)
	var pts := get_tree().get_nodes_in_group(&"trap_spots") if day else \
		get_tree().get_nodes_in_group(&"crow_perches") + get_tree().get_nodes_in_group(&"creature_cover")
	var src := Vector3.INF
	for n: Node3D in pts:
		var m := n.global_position
		var d := m.distance_to(pos)
		if d < LURE_MIN_M or d > LURE_MAX_M or (src != Vector3.INF and d >= src.distance_to(pos)):
			continue
		if not day and not lone and not _traps.values().any(func(t: Dictionary) -> bool: return t.armed and t.position.distance_to(m) <= _num[&"trap_lure_m"]):
			continue
		if day and Game.players.keys().any(func(q: int) -> bool: return q != p and _alive(q) and Game.players[q].pos.distance_to(m) < DAY_RULE_M):
			continue
		if owner != 0 and owner != p and _alive(owner) and Game.players[owner].pos.distance_to(m) < COULD_NOT_BE_M:
			continue
		src = m
	return src


## Host: day lures go to the target only, night lures to everyone. `Net.apply_lure` is call_remote, so
## the host plays its own share here.
func _send_lure(args: Array) -> void:
	var to: int = args[3]
	if to < 0:
		Net.to_peers(&"apply_lure", args)
	elif to != 1:
		Net.to_peers(&"apply_lure", args, [to])
	if to < 0 or to == 1:
		Net.apply_received.emit(&"lure", args)


## Every peer that hears a lure. A stranger line is the Soundscape's. A clip plays at the source through the
## tell's bus, unless its owner is Off by now (doc 06 section 11 "Coverage") or the clip is not here.
func _hear_lure(args: Array) -> void:
	var source: String = args[1]
	var pos: Vector3 = args[2]
	if source.begins_with("sound:"):
		var s: Array = SOUND_LURES.get(source.trim_prefix("sound:"), [])
		for i in (int(s[1]) if s else 0):
			Soundscape.play_3d(s[0], pos + Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6)))
			await get_tree().create_timer(float(s[2])).timeout
		return
	if not source.begins_with("clip:"):
		return
	var parts := source.split(":", true, 2)
	var owner := int(parts[1])
	var clip_id := parts[2]
	if Settings.peer_volume(owner) <= 0.0:
		return  # D-047: muted for this listener: the replay is skipped whole (its crackle would expose it)
	var pk: Array = Voice.clips.packets(owner, clip_id) if Game.voice_setting_of(owner) == "lobby_lines" else []
	if pk.is_empty():
		Log.event(&"lure_skipped", {"lure_id": args[0], "owner": owner, "clip_id": clip_id,
			"why": "missing" if Game.voice_setting_of(owner) == "lobby_lines" else "owner_off"})
		return
	var chain: Script = load(VOICE_CHAIN) if ResourceLoader.exists(VOICE_CHAIN) else null
	var tell: StringName = args[4]
	var bus: StringName = chain.call(&"bus_for", tell, Voice.hears_static(owner)) if chain else &"VoiceBase"  # P3-10: a dead owner's static
	var s := AudioStreamOpus.new()
	s.opus_sample_rate = Voice.OPUS_RATE
	s.opus_channels = 1
	s.buffer_length = pk.size() * 0.02 + 0.5  # 20 ms frames: the whole clip fits, pushed at once (clips.gd)
	var player := AudioStreamPlayer3D.new()
	player.stream = s
	player.bus = bus
	player.unit_size = VoiceEmitter.UNIT_SIZE
	player.volume_db = linear_to_db(Settings.peer_volume(owner))  # D-047 per-player volume applies to replays too
	player.max_distance = VoiceEmitter.MAX_DISTANCE
	get_parent().add_child(player)
	player.global_position = pos + Vector3.UP * VoiceEmitter.EYE_HEIGHT
	player.play()
	var pb := player.get_stream_playback() as AudioStreamPlaybackOpus
	for pkt: PackedByteArray in pk:
		pb.push_opus_packet(pkt, 0, 0)
	pb.mark_end_opus_stream(true)
	if chain:
		chain.call(&"attach_crackle", player, tell, bus)
	_clip_lures.append([owner, clip_id, player])
	await get_tree().create_timer(pk.size() * 0.02 + 0.3).timeout
	_drop_clip_lure(player)


## Doc 06 section 11: a clip freed (its owner went Off or left) stops at once.
func _on_clip_freed(owner: int, clip_id: String) -> void:
	for e in _clip_lures.duplicate():
		if e[0] == owner and (clip_id.is_empty() or e[1] == clip_id):
			_drop_clip_lure(e[2])
			Log.event(&"lure_stopped", {"owner": owner, "clip_id": e[1]})


func _drop_clip_lure(player: Node) -> void:
	_clip_lures = _clip_lures.filter(func(e: Array) -> bool: return e[2] != player)
	if is_instance_valid(player):
		player.queue_free()


func _track_lure() -> void:
	var p: int = _lure.target
	var elapsed := _now - float(_lure.t0)
	if _alive(p):
		_lure.moved_m = Logic.lure_moved(_lure.moved_m, _lure.start_d, Game.players[p].pos.distance_to(_lure.position))
	var worked: bool = _lure.moved_m > LURE_WORKED_M
	if not worked and elapsed < _num[&"lure_wait_s"]:
		return
	if worked:
		_dir.lure_worked()
	Log.event(&"lure_result", {"lure_id": _lure.lure_id, "target": p, "moved_m": _lure.moved_m,  # unrounded: check_logs re-applies "> 10 m"
		"within_s": snappedf(elapsed, 0.01) if worked else _num[&"lure_wait_s"], "window_s": _num[&"lure_wait_s"], "worked": worked})
	if worked and _lure.recorded_line != null:  # CONTRACTS section 10 (D-020)
		Log.event(&"lure_fooled", {"lure_id": _lure.lure_id, "target": p, "line_id": _lure.recorded_line})
	var src: Vector3 = _lure.position
	_lure = {}
	if state != &"lure":
		return
	if worked and not _scripted:  # doc 03 section 4.2 lure -> stalk (the scripted lurk keeps its script); it heads for the source it sent them to
		_memory.append({"position": src, "margin": 0.0, "t": _now, "peer": p, "kind": &"lure"})
		_set_state(&"stalk", &"lure_worked", p)
	else:
		_set_state(&"lurk", &"lure_failed", 0)


# --- traps (doc 03 sections 9 and 18) ------------------------------------------------------------

## One bear trap and one pit; the third and fourth set times move them to new spots (doc 03 section 4
## "sets and moves traps"; reading of section 18, see production/handoffs/P1-08.md). Every peer shows an
## armed trap's clue (`_show_clue`); a moved trap is sent as `moved` so its old clue goes.
func _set_trap(i: int) -> void:
	var kind := &"bear" if i % 2 == 0 else &"pit"
	var old: Dictionary = {}
	for t in _traps.values():
		if t.kind == kind:
			old = t
	if not old.is_empty() and not old.armed:
		return  # a sprung trap stays where it is (the trap race is P1-09)
	var ids: Array = Data.value(&"phase1", &"scripted_trap_spots", &"ids")
	var spots := get_tree().get_nodes_in_group(&"trap_spots").filter(func(n: Node) -> bool:
		return ids.has(String(n.name)) and not _traps.has(String(n.name)) and (kind == &"bear" or n.get_meta("kind", "") != "deep"))
	var n: Node3D = spots[(_nights * 4 + i) % spots.size()]
	if not old.is_empty():
		Net.to_peers(&"apply_trap_changed", [old.id, kind, &"moved", old.position])
		_show_clue(old.id, kind, false)
		_traps.erase(old.id)
	_arm(n, kind, {})


## Arms `kind` at spot `n` and shows its clue to every peer; `extra` goes into the `trap_changed` line.
func _arm(n: Node3D, kind: StringName, extra: Dictionary) -> void:
	var id := String(n.name)
	_traps[id] = {"id": id, "kind": kind, "position": n.global_position, "deep": n.get_meta("kind", "") == "deep", "armed": true}
	Log.event(&"trap_changed", {"trap_id": id, "state": "set", "by": "creature", "kind": String(kind)}.merged(extra))
	Net.to_peers(&"apply_trap_changed", [id, kind, &"set", n.global_position])
	_show_clue(id, kind, true)
	if _test and _walker:  # QA: the host's walker steps on it, so trap_sprung fires
		_walker.nav_path = [n.global_position]


## P2-05 (D-037 (2)): TrapRace ends a trap (disarmed, filled); its spot is free for later sets.
func clear_trap(id: String) -> void:
	_traps.erase(id)


## Full farm, at nightfall: doc 02 section 11 counts for today (`ramp_up.json`, scaled by headcount, 2p
## floor) less what is still armed out there (traps stay armed by day, section 9), spread over the night.
## Disabled kinds (bells, `traps.json` `enabled` false) are skipped. Difficulty scales the count inside
## `Data.scaled` (doc 02 s16); after a full wipe `wipe_traps` more are added, bear and pit in turn (doc 03 s9).
## The bear sets take their traps now (D-053): `supply` is what the creature holds after the theft.
func _plan_traps() -> void:
	_plan.clear()
	var day := clampi(_nights if _test else Clock.day, 1, 7)
	var row: Dictionary = Data.record(&"ramp_up", StringName("day_%d" % day)) if Data.has_table(&"ramp_up") else {}
	var heads := clampi(Game.player_count(), 2, Game.max_players())
	var kinds: Array = []
	for kind: StringName in TRAP_KINDS:
		if not bool(Data.record(&"traps", TRAP_KINDS[kind][0]).get("enabled", true)):
			continue
		var v: Variant = row.get(TRAP_KINDS[kind][1])  # day 7 is null: it hunts all night instead
		var want := Data.scaled(int(v), &"traps", heads) if v != null else 0
		var have := _traps.values().filter(func(t: Dictionary) -> bool: return t.kind == kind and t.armed).size()
		for i in maxi(want - have, 0):
			kinds.insert(_rng.randi_range(0, kinds.size()), kind)
	var mix: Array = [&"bear", &"pit"]  # placeholder `full_wipe_extra_mix`: doc 03 s9 says 1 bear + 1 pit for 2
	for i in wipe_traps:
		kinds.insert(_rng.randi_range(0, kinds.size()), mix[i % mix.size()])
	wipe_traps = 0
	var night: float = _num[&"night_s"] if _test else Clock.length_of(&"night")
	for i in kinds.size():
		_plan.append({"t": night * (TRAP_SET_FROM + TRAP_SET_SPAN * (i + 0.5) / kinds.size()), "kind": kinds[i]})
	_steal_traps(true, kinds.count(&"bear") - _stash)
	Log.event(&"trap_plan", {"day": day, "players": heads, "plan": kinds.map(func(k: StringName) -> String: return String(k)),
		"supply": _stash, "armed": _traps.values().filter(func(t: Dictionary) -> bool: return t.armed).size()})


## Doc 03 section 9 spot choice, then arms it. A bear set needs a taken trap (D-053): none left, it is skipped.
## `late`: the set waited TRAP_WAIT_S for lurk and lands in another state (P2-28).
func _place_trap(kind: StringName, late := false) -> void:
	if kind == &"bear" and _stash <= 0:
		Log.event(&"trap_skipped", {"kind": String(kind), "reason": "no_supply"})
		return
	var pick := _pick_spot(kind)
	if pick.is_empty():
		Log.event(&"trap_skipped", {"kind": String(kind), "reason": "no_spot"})
		return
	if kind == &"bear":
		_stash -= 1
	_arm(pick.node, kind, {"stolen": kind == &"bear", "region": pick.region, "work_m": pick.work_m, "late": late})


## A free `trap_spots` marker for `kind`: no deep spot for a pit, none in sanctuary or within LIT_DOOR_M of
## a lit doorway, none within TRAP_GAP_M of another trap, none within CLUE_M of a living player (it is
## not set under someone's feet; true positions here only avoid players). Region: a spot within REGION_M
## of a random heard work point, else the nearest to it; nothing heard yet: any free spot.
func _pick_spot(kind: StringName) -> Dictionary:
	var free: Array = []
	for n: Node3D in get_tree().get_nodes_in_group(&"trap_spots"):
		var m := n.global_position
		if _traps.has(String(n.name)) or (kind != &"bear" and n.get_meta("kind", "") == "deep") or _in_sanctuary(m) or _in_lit_doorway(m):
			continue
		if _traps.values().any(func(t: Dictionary) -> bool: return t.position.distance_to(m) < TRAP_GAP_M):
			continue
		if Game.players.keys().any(func(p: int) -> bool: return _alive(p) and Game.players[p].pos.distance_to(m) < CLUE_M):
			continue
		free.append(n)
	if free.is_empty():
		return {}
	if _work.is_empty():
		return {"node": free[_rng.randi() % free.size()], "region": "none", "work_m": null}
	var w: Vector3 = _work[_rng.randi() % _work.size()]
	var near := free.filter(func(n: Node3D) -> bool: return n.global_position.distance_to(w) <= REGION_M)
	var n: Node3D = near[_rng.randi() % near.size()] if not near.is_empty() else null
	if n == null:
		for f: Node3D in free:
			if n == null or f.global_position.distance_to(w) < n.global_position.distance_to(w):
				n = f
	return {"node": n, "region": "heard" if not near.is_empty() else "nearest", "work_m": snappedf(n.global_position.distance_to(w), 0.1)}


func _in_sanctuary(pos: Vector3) -> bool:
	for s: Node3D in get_tree().get_nodes_in_group(&"sanctuary"):
		if s.global_position.distance_to(pos) <= float(s.get_meta("radius_m", _num[&"sanctuary_m"])):  # the marker's radius wins
			return true
	return false


## Full farm, doc 01 "The tool shed", D-053: the farm's bear traps are the creature's only supply. At
## nightfall it takes up to `need`: traps in living players' hands first (outdoors, or in a dark building),
## then traps off the pegboard. One in a lit building is kept (and moved at dawn, `_dawn_traps`). During
## the night a trap in a building that goes dark is taken too. Before `broken_from_day` the lock caps every
## theft together at `theft_cap_per_night` (store.json `shed_lock`).
func _steal_traps(nightfall: bool, need: int = 0) -> void:
	var farm := get_parent().get_node_or_null(^"Farm")
	var gen := get_parent().get_node_or_null(^"Generator")
	if farm == null:
		return
	var lit: bool = gen != null and gen.powered()
	var lock: Dictionary = Data.record(&"store", &"shed_lock").get("effect", {}) if Data.has_table(&"store") else {}
	var locked := shed_lock and Clock.day < int(lock.get("broken_from_day", 5))
	var cap := int(lock.get("theft_cap_per_night", 1)) if locked else 1 << 30
	var capped := false
	for p in Game.players.keys():
		if not _alive(p) or not bool(Game.players[p].get("trap", false)):
			continue
		var b := _building(Game.players[p].pos)
		if b != "" and lit:
			if nightfall:
				_kept[p] = b
			continue
		if b != "":
			_kept.erase(p)  # the building went dark: it did not stay lit all night
		if (nightfall and need <= 0) or (not nightfall and b == ""):
			continue
		if _stolen_night >= cap:
			capped = true
			continue
		need -= 1
		farm.set_hands(p, bool(Game.players[p].get("shovel", false)), false)
		_took("held:%d" % p, "dark_building" if b != "" else "outdoor", locked, {"player": p})
	var sweep := get_tree().get_first_node_in_group(&"trap_sweep")
	while nightfall and need > 0 and sweep != null and sweep.filled.has(true):
		if _stolen_night >= cap:
			capped = true
			break
		var slot: int = sweep.filled.find(true)
		sweep.take_trap()
		need -= 1
		_took("board:%d" % slot, "board", locked, {})
	if capped and not _capped_logged:
		_capped_logged = true
		Log.event(&"trap_theft_capped", {"cap": cap, "day": Clock.day})


func _took(trap: String, from: String, locked: bool, extra: Dictionary) -> void:
	_stolen_night += 1
	_stash += 1
	Log.event(&"trap_stolen", {"trap": trap, "from": from, "lock": locked, "day": Clock.day, "supply": _stash}.merged(extra))


## Dawn, D-053 (3): a bear trap kept all night in a building that stayed lit leaves the hands and turns up
## unarmed in the corn at a random free `trap_spot`, as a pickup (`trap_changed` `loose`, `TrapPickup`).
func _dawn_traps() -> void:
	var farm := get_parent().get_node_or_null(^"Farm")
	for p in _kept:
		if farm == null or not _alive(p) or not bool(Game.players[p].get("trap", false)) or _building(Game.players[p].pos) == "":
			continue
		var free := get_tree().get_nodes_in_group(&"trap_spots").filter(func(n: Node3D) -> bool:
			return not _traps.has(String(n.name)) and not _in_sanctuary(n.global_position))
		if free.is_empty():
			continue
		var n: Node3D = free[_rng.randi() % free.size()]
		var id := String(n.name)
		farm.set_hands(p, bool(Game.players[p].get("shovel", false)), false)
		_traps[id] = {"id": id, "kind": &"bear", "position": n.global_position, "deep": n.get_meta("kind", "") == "deep", "armed": false, "loose": true}
		Log.event(&"trap_moved", {"trap": "held:%d" % p, "from_building": _kept[p], "to_spot": id, "player": p})
		Net.to_peers(&"apply_trap_changed", [id, &"bear", &"loose", n.global_position])
		Net.apply_received.emit(&"trap_changed", [id, &"bear", &"loose", n.global_position])
	_kept.clear()


## Host, from `TrapPickup`: the loose trap goes into `peer`'s hands and its spot is free again.
func pick_up_loose(id: String, peer: int, st: Dictionary) -> void:
	var t: Dictionary = _traps.get(id, {})
	if not t.get("loose", false):
		return
	_traps.erase(id)
	get_parent().get_node(^"Farm").set_hands(peer, bool(st.get("shovel", false)), true)
	Log.event(&"trap_changed", {"trap_id": id, "state": "picked_up", "by": peer, "kind": "bear"})
	Net.to_peers(&"apply_trap_changed", [id, &"bear", &"picked_up", t.position])
	Net.apply_received.emit(&"trap_changed", [id, &"bear", &"picked_up", t.position])


## Every peer: the loose trap's pickup at its spot (placeholder art: TrapArt's bear trap).
func _show_loose(id: String, on: bool) -> void:
	var farm := get_parent().get_node_or_null(^"Farm")
	if farm == null:
		return
	if not on:
		if farm.targets.get(id) is TrapPickup:
			var old: Node = farm.targets[id]
			farm.targets.erase(id)
			old.get_meta(&"art").queue_free()
			old.get_meta(&"pick").queue_free()
			old.queue_free()  # deferred: a hold finishing this frame still reads it
		return
	var m: Node3D = null
	for s: Node3D in get_tree().get_nodes_in_group(&"trap_spots"):
		if String(s.name) == id:
			m = s
	if m == null or farm.targets.has(id):
		return
	var t := TrapPickup.new()
	t.creature = self
	t.id = id
	t.farm = farm
	m.add_child(t)
	t.add_pick_body(Vector3(1.2, 0.5, 1.2))
	t.set_meta(&"pick", m.get_child(m.get_child_count() - 1))
	var mesh := TrapArt.bear()
	m.add_child(mesh)
	t.set_meta(&"art", mesh)
	farm.targets[id] = t
	if Game.is_host() and OS.get_cmdline_user_args().has("--take-loose") and _alive(1):  # QA: the host player picks it up
		var hc: Node = get_tree().current_scene.get_node("Players").player(1).get_node("HoldController")
		var stand := m.global_position + Vector3(1.0, 0, 0)
		var st: Dictionary = Game.players[1]
		st.pos = Vector3(stand.x, st.pos.y, stand.z)  # the speed check would clamp the teleport (as death.gd's respawn)
		st.freeze_until = Time.get_ticks_msec() + 300
		hc._sweep_go.call_deferred(&"take_trap", t, stand)


## The building `pos` is in (the door's parent), or "" outdoors.
func _building(pos: Vector3) -> String:
	for i in _rects.size():
		if _rects[i].has_point(Vector2(pos.x, pos.z)):
			return _rect_names[i]
	return ""


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


## Every peer: an armed trap at its spot (doc 01 "Night Traps": glinting metal, fresh dirt). TrapArt's
## placeholder mesh, seen at any range per D-055 (doc 03 section 9's CLUE_M rule paused). TrapRace shows a
## sprung trap, so any state but `set` removes the clue.
func _show_clue(id: String, kind: StringName, on: bool) -> void:
	for m in get_tree().get_nodes_in_group(&"trap_spots"):
		if String(m.name) != id:
			continue
		var old := m.get_node_or_null(^"Clue")
		if old:
			old.free()
		if not on:
			return
		var mesh := TrapArt.of(kind)  # D-055: seen at any range until art; the 4 m clue rule is paused
		mesh.name = "Clue"
		m.add_child(mesh)
		if _log:  # QA (P2-26): proves the clue exists on this peer, where, and that it can render
			Log.event(&"trap_clue_shown", {"trap_id": id, "kind": String(kind), "position": _v(mesh.global_position),
				"visible": mesh.is_visible_in_tree()})
		if _clue_shot != "" and not _shot_kinds.has(kind):
			_shot_kinds.append(kind)
			_shoot_clue(mesh.global_position, "%s/clue_%s_%s.png" % [_clue_shot, kind, "host" if Game.is_host() else "client"])
		return


## QA `-- --clue-shot=<dir>` (any peer, windowed): a player-eye view of each kind's first clue from 10 m
## (D-055: plainly visible at walking distance).
var _clue_shot := ""
var _shot_kinds: Array[StringName] = []


func _shoot_clue(at: Vector3, path: String) -> void:
	var cam := Camera3D.new()
	get_parent().add_child(cam)
	cam.global_position = at + Vector3(0, EYE_M, 10.0)
	cam.look_at(at)
	cam.make_current()
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(path)
	Log.event(&"clue_shot", {"path": path, "night": _night_t >= 0.0 or Clock.phase == &"night"})
	cam.queue_free()


# --- movement ------------------------------------------------------------------------------------

func _move(_delta: float) -> void:
	var speed: float = _num[&"lurk_speed_mps"]
	match state:
		&"stalk": speed = _num[&"stalk_speed_mps"]
		&"chase", &"retreat": speed = _num[&"chase_speed_mps"]
	if _night_t < 0.0:
		_goal = _dir.day_cover(_marker(&"creature_cover", DAY_COVER))
	var d := Vector3.INF if _goal == Vector3.INF else _goal - global_position
	var stop := ARRIVE_M
	if state == &"stalk" and target != 0:
		stop = _num[&"scripted_standoff_m"] if _scripted else STALK_STANDOFF_M
	if _scripted and state == &"stalk" and d != Vector3.INF and Vector2(d.x, d.z).length() < stop - ARRIVE_M:
		d = -d  # the target walked closer: back off to stay out of sight (doc 03 section 2)
	elif d == Vector3.INF or Vector2(d.x, d.z).length() < stop:
		velocity = Vector3.ZERO
		if state == &"lurk" and _search_until < _now:
			_goal = Vector3.INF
		return
	d.y = 0.0
	if state in [&"lurk", &"lure", &"stalk"] and _scarecrow_in_way(d.normalized()):  # P4-06: store.json `scarecrow` creature_avoid_m
		_goal = Vector3.INF
		velocity = Vector3.ZERO
		return
	velocity = d.normalized() * speed
	rotation.y = atan2(-d.x, -d.z)
	var was := global_position
	move_and_slide()
	global_position.y = 0.0
	if _taint and _night_t >= 0.0 and (state == &"lurk" or state == &"stalk"):  # doc 03 section 8: leavings
		_leave_m += Vector2(global_position.x - was.x, global_position.z - was.z).length()
		if _leave_m >= _num[&"leavings_every_m"]:
			_leave_m = 0.0
			get_tree().get_first_node_in_group(&"taint").add_source(&"leavings", global_position)


## P4-06: a bought scarecrow keeps it `creature_avoid_m` away; it never blocks a chase or a retreat.
func _scarecrow_in_way(dir: Vector3) -> bool:
	var avoid := float(Data.value(&"store", &"scarecrow", &"effect").get("creature_avoid_m", 0.0)) if Data.has_table(&"store") else 0.0
	var next := global_position + dir * 1.0
	for s: Node3D in get_tree().get_nodes_in_group(&"bought_scarecrow"):
		var now := Vector2(s.global_position.x - global_position.x, s.global_position.z - global_position.z).length()
		if now < avoid and Vector2(s.global_position.x - next.x, s.global_position.z - next.z).length() < now:
			return true
	return false


## Lurk: walk between cover points and trap spots in its region (doc 03 section 4): the AI Director's wander
## region when it set one (section 11.6; its centre when the region has no such points), else near what it heard.
func _wander() -> void:
	if _goal != Vector3.INF:
		return
	var pts := get_tree().get_nodes_in_group(&"creature_cover") + get_tree().get_nodes_in_group(&"trap_spots")
	if _dir.wander_region:
		var rect: Rect2 = _dir.region_rect(_dir.wander_region)
		var inside := pts.filter(func(n: Node3D) -> bool: return rect.has_point(Vector2(n.global_position.x, n.global_position.z)))
		_goal = (inside[_rng.randi() % inside.size()] as Node3D).global_position if inside else Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		return
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
	if gen == null or not gen.powered():  # doors are lit only while the generator runs (doc 03 section 6)
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


## P4-13, doc 01 "Bodies", doc 03 section 2: the host picks the season's body once; clients get it with
## every `apply_creature_state`. `--body=<id>` forces it. Without `--seed` the seed is the session id, so
## unseeded seasons differ (inference: doc 01 names no seed source; P4-10 saves the pick).
func _pick_body() -> void:
	var ids := []
	for r in Data.records(&"creature"):
		if r.get("kind") == "body":
			ids.append(StringName(r.id))
	var forced := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--body="):
			forced = a.trim_prefix("--body=")
	var seed_n := Game.seed_value if Game.seed_value != 0 else hash(Game.session_id)
	body = Logic.pick_body(ids, seed_n, forced)
	if forced != "" and String(body) != forced and String(body) != "body_" + forced:
		push_warning("Creature: --body=%s names no body; the seed picked %s" % [forced, body])
	Log.event(&"creature_body", {"body": String(body), "seed": seed_n, "forced": forced})


func _on_apply(what: StringName, args: Array) -> void:
	match what:
		&"creature_state":
			if not _body_logged or args[1] != body:  # the season's body: the first packet carries it (farm_state reply)
				_body_logged = true
				body = args[1]
				Log.event(&"creature_body", {"body": String(body)})
				if args[0] == state:
					state_changed.emit(state, body)
			if args[0] != state:
				state = args[0]
				body = args[1]
				if _log:
					Log.event(&"creature_state_applied", {"state": String(state), "body": String(body)})
				state_changed.emit(state, body)
		&"lure":
			_hear_lure(args)
			if _walker and not String(args[0]).begins_with("scare_"):  # a scare voice is not a lure test
				_test_lure_heard(args[2])
		&"trap_changed":  # every peer: the Creature sends `set`, TrapRace the later states
			_show_clue(args[0], args[1], args[2] == &"set")
			_show_loose(args[0], args[2] == &"loose")
			if _log and not Game.is_host():
				Log.event(&"trap_changed_applied", {"trap_id": args[0], "kind": String(args[1]), "state": String(args[2])})
			if Game.is_host() and args[2] == &"disarmed":  # a pried-free bear trap too (on_pry_done)
				clear_trap(args[0])


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
		"noise_memory": _memory.size(), "lure": _lure.duplicate(), "traps": _traps.duplicate(true),
		"trap_plan": _plan.duplicate(true), "stash": _stash, "work_heard": _work.size(), "taint_trails": _trail.size()}


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
