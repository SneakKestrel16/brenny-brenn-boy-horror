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
	if OS.get_cmdline_user_args().has("--autosweep"):
		_autosweep.call_deferred()


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
	elif _autopry and not player.pinned:
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
		if tgt != null and not _need_release and Input.is_action_pressed(&"interact") and not Game.console_open:
			var verbs: Array[StringName] = tgt.verbs_for(mine)
			if not verbs.is_empty():
				start(verbs[0], tgt)
		return
	_t += delta
	_ring.scale = Vector3.ONE * clampf(_t / _hold_s, 0.01, 1.0)
	_ring.global_position = _target.target_pos() + Vector3(0, 1.4, 0)
	if not Input.is_action_pressed(_action) and not _scripted:
		cancel()


var _scripted := false


## HUD: the verb being held and its progress 0..1, or an empty verb.
func hold_state() -> Array:
	return [_verb, clampf(_t / maxf(_hold_s, 0.01), 0.0, 1.0)] if _holding else [&"", 0.0]


## HUD: the refusal reason while it is fresh, else empty.
func fresh_refusal() -> StringName:
	return refused_reason if Time.get_ticks_msec() - _refused_ms < REFUSED_SHOW_MS else &""


func start(verb: StringName, target: Node, action: StringName = &"interact") -> void:
	_verb = verb
	_target = target
	_action = action
	_hold_s = Interactable.hold_seconds(verb)
	_t = 0.0
	_holding = true
	_result = &""
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
	if what == &"hold_done" and args[1] != _target.id:
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
	var farm := get_tree().get_first_node_in_group(&"farm")
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
	var farm := get_tree().get_first_node_in_group(&"farm")
	var host := Game.is_host()
	var mine := "Plot01" if host else "Plot02"
	await get_tree().create_timer(2.0).timeout
	var out_of_barn := [Vector3(0, 0, -4), Vector3(0, 0, 4), Vector3(22, 0, 4)]  # door at (0, 0), corn strip 2 at x 12..18
	var front := Vector3(0, 0, 1.5)
	await _do(&"plant", mine, front, out_of_barn)
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
	var farm := get_tree().get_first_node_in_group(&"farm")
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
