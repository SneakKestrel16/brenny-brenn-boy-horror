extends Node
## Doc 05 section 7 (client, on the local player): looks at what the interact ray hits, sends
## `request_hold` while `interact` is held, shows a cosmetic world-space ring, cancels on release or
## leaving range. The host decides everything. `-- --autochore` drives a scripted chore loop for the
## 2-instance test (QA only).

const Interactable := preload("res://game/interaction/interactable.gd")
const FlagSpot := preload("res://game/traps_player/flag_spot.gd")
const REACH_M := 3.0  ## ray length from the eye (placeholder; the host range check is range_m)
const PICK_MASK := 8  ## layer 4 "interactable"
const REFUSED_SHOW_MS := 2000  ## how long a refusal reason stays on screen (placeholder)

var player: CharacterBody3D
var _cam: Camera3D
var _verb: StringName = &""
var _target: Node
var _target_id := ""  ## kept apart: a trap target is freed when the trap clears, possibly before `hold_done` arrives
var _hold_s := 0.0
var _t := 0.0
var _ring: MeshInstance3D
var _result := &""  ## last host answer for the autochore: done / refused / cancelled
var _holding := false
var _action := &"interact"  ## the input that started this hold (releasing it cancels)
var _flag: Node  ## P2-11: the FlagSpot the ring follows during a place_flag hold
var _need_release := false  ## a refused hold waits for `interact` to be released before it retries
var target_farm: Node  ## the Farm (found lazily); its `carry` is what this player holds
var _autopry := OS.get_cmdline_user_args().has("--autopry")
var _pin_t := 0.0
var refused_reason: StringName = &""  ## HUD: why the host refused the last hold
var _refused_ms := -REFUSED_SHOW_MS
var aimed_verb: StringName = &""  ## HUD: first verb of the aimed target, empty if none (set while not holding)


func _ready() -> void:
	player = get_parent()
	_cam = player._cam  # ponytail: reaches into Player; a getter if Player grows one
	Net.apply_received.connect(_on_apply)
	_ring = MeshInstance3D.new()
	var c := CylinderMesh.new()  # placeholder ring: a disc that grows with progress (no art yet)
	c.top_radius = 0.4
	c.bottom_radius = 0.4
	c.height = 0.02
	_ring.mesh = c
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)
	if OS.get_cmdline_user_args().has("--autochore"):
		_autochore.call_deferred()
	if OS.get_cmdline_user_args().has("--autotap"):
		_autotap.call_deferred()
	if OS.get_cmdline_user_args().has("--autosweep"):
		_autosweep.call_deferred()
	if OS.get_cmdline_user_args().has("--autopush"):
		_autopush.call_deferred()


func _physics_process(delta: float) -> void:
	if player.ghost:
		aimed_verb = &""
		if _holding:
			cancel()
		return
	if _autopry and player.pinned and not _holding:
		_pin_t += delta
		if _pin_t > 0.3:  # QA: pry the trap I am pinned in (a bot-less pry for the 2-instance test)
			var race := get_tree().get_first_node_in_group(&"trap_race")
			for id in race.victims:
				if race.victims[id] == player.peer:
					_scripted = true
					start(&"pry", get_tree().get_first_node_in_group(&"farm").targets[id])
					_pin_t = -1000.0  # once per trap
	elif _autopry and not player.pinned and _pin_t != 0.0:  # once, so a later scripted hold (--take-loose) keeps its flag
		_pin_t = 0.0
		_scripted = false
	if not _holding:
		if target_farm == null:
			target_farm = get_tree().get_first_node_in_group(&"farm")
		var tgt := _look_target()
		var mine: Dictionary = target_farm.carry.get(player.peer, {}) if target_farm else {}
		aimed_verb = &""
		if tgt != null:
			var vs: Array[StringName] = tgt.verbs_for(mine)
			aimed_verb = vs[0] if not vs.is_empty() else &""
		if not Input.is_action_pressed(&"interact") and not Input.is_action_pressed(&"alt_use"):
			_need_release = false
		if tgt == null and not _need_release and Input.is_action_pressed(&"alt_use") and not Game.console_open:
			var spot := _ground_spot()  # right mouse: plant a flag where the ray lands (doc 01 "Flags")
			if spot != null:
				_flag = spot
				start(&"place_flag", spot, &"alt_use")
				return
		if Input.is_action_just_pressed(&"drop") and not Game.console_open and not _need_release and held_can_id() >= 0 and target_farm.targets.has("can_%d" % held_can_id()):
			start(&"drop_can", target_farm.targets["can_%d" % held_can_id()])  # P2-27: G puts the carried can down
			return
		if Input.is_action_just_pressed(&"drop") and not Game.console_open and not _need_release and target_farm.targets.has("prize_pumpkin") and target_farm.targets["prize_pumpkin"].carrier == player.peer:
			start(&"set_down_prize", target_farm.targets["prize_pumpkin"])  # P4-05: G puts the Prize Pumpkin down
			return
		if tgt != null and not _need_release and Input.is_action_pressed(&"interact") and not Game.console_open:
			var verbs: Array[StringName] = tgt.verbs_for(mine)
			if not verbs.is_empty():
				start(verbs[0], tgt)
		return
	_t += delta
	_ring.scale = Vector3.ONE * maxf(hold_state()[1], 0.01)
	if is_instance_valid(_target):  # freed mid-hold (trap filled or disarmed by this hold): ring stays put
		_ring.global_position = _target.target_pos() + Vector3(0, 1.4, 0)
	if _scripted or _verb in [&"drop_can", &"set_down_prize"]:  # drop_can: one tap, the host times it (releasing G must not cancel)
		return
	if bool(Settings.get_value(&"toggle_holds")):  # D-047: press starts, press again stops; hold time is unchanged
		if not Input.is_action_pressed(_action):
			_armed = true
		elif _armed:
			_need_release = true
			cancel()
	elif not Input.is_action_pressed(_action):
		cancel()


var _scripted := false
var _armed := false  ## toggle_holds: the starting press has been released, the next press stops


## HUD: the verb being held, its progress 0..1 and a note, or an empty verb. A target with `hold_progress`
## (the cart's push, P4-32) supplies its own progress and note; otherwise the hold timer, no note.
func hold_state() -> Array:
	if not _holding:
		return [&"", 0.0, ""]
	var own: Array = _target.hold_progress(_verb) if is_instance_valid(_target) and _target.has_method(&"hold_progress") else []
	return [_verb] + (own if not own.is_empty() else [clampf(_t / maxf(_hold_s, 0.01), 0.0, 1.0), ""])


## The id of the can this player carries, or -1.
func held_can_id() -> int:
	var f := target_farm if target_farm else get_tree().get_first_node_in_group(&"farm")
	return int(f.carry.get(player.peer, {}).get("held_can", -1)) if f else -1


## HUD: the refusal reason while it is fresh, else empty.
func fresh_refusal() -> StringName:
	return refused_reason if Time.get_ticks_msec() - _refused_ms < REFUSED_SHOW_MS else &""


func start(verb: StringName, target: Node, action: StringName = &"interact") -> void:
	_verb = verb
	_target = target
	_target_id = String(target.id)
	_action = action
	_hold_s = Interactable.hold_seconds(verb, Roles.of(Game.local_peer()), target)
	_t = 0.0
	_holding = true
	_result = &""
	_armed = false
	_ring.visible = true
	Net.to_host(&"request_hold", [verb, target.id])


func cancel() -> void:
	if _holding:
		Net.to_host(&"request_hold_cancel")
	_end(&"cancelled")


func _end(result: StringName) -> void:
	_holding = false
	if _flag != null:
		_flag.free()
		_flag = null
	_ring.visible = false
	_result = result


## A FlagSpot on the ground the ray hits (world layer 1), or null. The wire id carries the position.
func _ground_spot() -> Node:
	var from := _cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - _cam.global_transform.basis.z * REACH_M, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var spot := FlagSpot.new()
	spot.id = FlagSpot.make_id(hit.position)
	spot.pos = FlagSpot.from_id(spot.id)
	return spot


func _look_target() -> Node:
	var from := _cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - _cam.global_transform.basis.z * REACH_M, PICK_MASK)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.collider.get_meta(&"interactable") if hit and hit.collider.has_meta(&"interactable") else null


func _on_apply(what: StringName, args: Array) -> void:
	if not _holding or not what in [&"hold_done", &"refused", &"hold_cancelled"] or args[0] != _verb:
		return
	if what == &"hold_done" and args[1] != _target_id:
		return  # a late answer for an earlier hold of the same verb
	match what:
		&"hold_done":
			_end(&"done")
			if Interactable.INSTANT_S.has(args[0]) or args[0] == &"place_flag":
				_need_release = true  # one press, one action (no shovel flapping)
		&"refused":
			_need_release = true
			refused_reason = args[1]
			_refused_ms = Time.get_ticks_msec()
			_end(&"refused")
		&"hold_cancelled": _end(&"cancelled")


# --- QA script (`-- --autochore`) ------------------------------------------------------------------

func _walk(points: Array) -> void:
	player.nav_path = points.duplicate()
	while not player.nav_path.is_empty():
		await get_tree().physics_frame
	await get_tree().create_timer(0.4).timeout  # let the host see the final move frame


func _do(verb: StringName, id: String, offset: Vector3, via: Array = []) -> StringName:
	var farm: Node = await _wait_farm()
	var t: Node = farm.targets[id]
	await _walk(via + [t.target_pos() * Vector3(1, 0, 1) + offset])
	_scripted = true
	start(verb, t)
	var timeout := get_tree().create_timer(_hold_s + 4.0)
	while _holding and timeout.time_left > 0.0:
		await get_tree().physics_frame
	_scripted = false
	if _holding:
		_end(&"timeout")
	Log.event(&"autochore_step", {"verb": String(verb), "target": id, "result": String(_result)})
	return _result


func _autochore() -> void:
	var farm: Node = await _wait_farm()
	var host := Game.is_host()
	var mine := "Plot01" if host else "Plot02"
	await get_tree().create_timer(2.0).timeout
	var out_of_barn := [Vector3(0, 0, -4), Vector3(0, 0, 4), Vector3(22, 0, 4)]  # door at (0, 0), corn strip 2 at x 12..18
	var front := Vector3(0, 0, 1.5)
	await _do(&"plant", mine, front, out_of_barn)
	await _do(&"take_can", "can_0" if host else "can_1", Vector3(0, 0, 1.2))  # D-054: nobody starts with a can
	await _do(&"water", mine, front)
	if host:
		var other: Node = farm.targets["Plot02"]
		var timeout := get_tree().create_timer(40.0)
		while not other.watered and timeout.time_left > 0.0:
			await get_tree().physics_frame
		farm.advance_day()  # stands in for the dawn tick (Clock.day_changed does this in a real session)
	else:
		var timeout := get_tree().create_timer(60.0)
		while farm.targets[mine].state != &"ripe" and timeout.time_left > 0.0:
			await get_tree().physics_frame
	await _do(&"harvest", mine, front)
	await _do(&"sell", "sell_box", Vector3(-1.6, 0, 0))
	await _do(&"fill_can", "well", Vector3(1.6, 0, 0))
	if held_can_id() >= 0:
		await _do(&"drop_can", "can_%d" % held_can_id(), Vector3.ZERO)  # D-054: put it down where we stand
	Log.event(&"autochore_done", {"coins": farm.coins})


# --- QA script (`-- --autosweep`, P2-11) -----------------------------------------------------------------
# Host: waits for a set bear trap, takes the shovel, disarms it, hangs it, plants a flag. Joiner: waits for
# a set pit, takes the shovel, fills it, plants a flag. Teleports (the host speed check is off under --autosweep).

func _sweep_go(verb: StringName, target: Node, stand: Vector3) -> void:
	var tid := String(target.id)
	var tpos: Vector3 = target.target_pos()
	var pin := func() -> void:  # the creature's QA walker also steers this body: hold it at the spot
		player.nav_path.clear()
		player.global_position = Vector3(stand.x, player.global_position.y, stand.z)
	var settle := get_tree().create_timer(0.6)  # let the host see the move
	while settle.time_left > 0.0:
		pin.call()
		await get_tree().physics_frame
	_scripted = true
	start(verb, target)
	var timeout := get_tree().create_timer(_hold_s + 4.0)
	while _holding and timeout.time_left > 0.0:
		pin.call()
		await get_tree().physics_frame
	_scripted = false
	if _holding:
		_end(&"timeout")
	Log.event(&"autosweep_step", {"verb": String(verb), "target": tid, "result": String(_result), "at": [player.global_position.x, player.global_position.z], "target_at": [tpos.x, tpos.z]})


func _autosweep() -> void:
	var farm: Node = await _wait_farm()
	var race := get_tree().get_first_node_in_group(&"trap_race")
	var kind := &"bear" if Game.is_host() else &"pit"
	await get_tree().create_timer(2.0).timeout
	var peg: Node = farm.targets["pegboard"]
	var board := peg.get_parent() as Node3D
	var at_board := board.global_position + board.global_transform.basis * Vector3(0, -1.5, -1.5)
	if not Game.is_host():
		at_board += Vector3(1.0, 0, 0)
	var timeout := get_tree().create_timer(160.0)
	var id := ""
	while id == "" and timeout.time_left > 0.0:
		for k in race.traps:
			if race.traps[k].kind == kind and race.traps[k].state == &"set":
				id = k
		await get_tree().create_timer(0.5).timeout
	if id == "":
		Log.event(&"autosweep_step", {"verb": "wait_trap", "target": "", "result": "timeout"})
		return
	await _sweep_go(&"take_shovel", peg, at_board)
	var t: Node = farm.targets[id]
	var tp: Vector3 = t.target_pos()
	await _sweep_go(&"disarm_bear" if kind == &"bear" else &"fill_pit", t, tp + Vector3(1.9, 0, 0))
	if kind == &"bear":
		await _sweep_go(&"hang_trap", peg, at_board)
	await _sweep_go(&"return_shovel", peg, at_board)
	var spot := FlagSpot.new()
	var p := at_board + Vector3(-2.0 if Game.is_host() else 2.0, 0, -2.0)
	spot.id = FlagSpot.make_id(p)
	spot.pos = FlagSpot.from_id(spot.id)
	_flag = spot
	await _sweep_go(&"place_flag", spot, at_board)
	Log.event(&"autosweep_done", {})


## QA (`-- --autopush`, P4-32): on the Harvest Moon walk to the cart's handle, hold `push_cart` for 12 s and log,
## once a second, where this body is against its handle slot; then let go and log that the lock is gone.
func _autopush() -> void:
	await _wait_farm()
	while Clock.phase != &"harvest_moon":
		await get_tree().create_timer(0.5).timeout
	var cart: Node = get_tree().get_first_node_in_group(&"cart")
	await _walk([Vector3(0, 0, -4), Vector3(0, 0, 4), cart.handle_pos() + cart.body.global_basis.z * 0.6])
	Log.event(&"autopush_step", {"step": "at_handle", "verbs": str(cart.verbs_for({}))})
	_scripted = true
	start(&"push_cart", cart)
	for i in 12:
		await get_tree().create_timer(1.0).timeout
		var slot: Vector3 = cart.push_slot(player.peer)
		var p := player.global_position
		Log.event(&"autopush_step", {"step": "pushing", "holding": _holding, "offset_m": snappedf(cart.offset, 0.1), "pushers": cart.pushers.size(),
				"slot_dist_m": snappedf(Vector2(p.x - slot.x, p.z - slot.z).length(), 0.01) if slot != Vector3.INF else -1.0, "hs": str(hold_state()),
				"cart_yaw": snappedf(cart.body.global_rotation.y, 0.01), "yaw_off": snappedf(angle_difference(cart.body.global_rotation.y, player.yaw), 0.01)})
	_scripted = false
	cancel()
	await get_tree().create_timer(1.5).timeout
	Log.event(&"autopush_step", {"step": "released", "locked": cart.push_slot(player.peer) != Vector3.INF, "offset_m": snappedf(cart.offset, 0.1)})


## QA scripts start in the barn lobby, where no Farm exists yet (P2-20): wait for the match scene's Farm.
func _wait_farm() -> Node:
	var farm := get_tree().get_first_node_in_group(&"farm")
	while farm == null:
		await get_tree().create_timer(0.5).timeout
		farm = get_tree().get_first_node_in_group(&"farm")
	return farm


## QA (`-- --autotap`): take a can, then drop it with a real 60 ms G tap through the input system.
func _autotap() -> void:
	var farm: Node = await _wait_farm()
	await get_tree().create_timer(2.0).timeout
	await _do(&"take_can", "can_0" if Game.is_host() else "can_1", Vector3(0, 0, 1.2), [Vector3(0, 0, -4), Vector3(0, 0, 4), Vector3(22, 0, 4)])  # same way out of the barn as autochore
	for i in 5:
		await get_tree().physics_frame
	Log.event(&"autotap_pre", {"held": held_can_id(), "need_release": _need_release, "holding": _holding})
	var ev := InputEventAction.new()
	ev.action = &"drop"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.06).timeout
	ev = InputEventAction.new()
	ev.action = &"drop"
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().create_timer(1.0).timeout
	Log.event(&"autotap_result", {"dropped": held_can_id() < 0})
