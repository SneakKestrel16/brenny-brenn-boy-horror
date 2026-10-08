extends Node
## Doc 05 section 7 (client, on the local player): looks at what the interact ray hits, sends
## `request_hold` while `interact` is held, shows a cosmetic world-space ring, cancels on release or
## leaving range. The host decides everything. `-- --autochore` drives a scripted chore loop for the
## 2-instance test (QA only).

const REACH_M := 3.0  ## ray length from the eye (placeholder; the host range check is range_m)
const PICK_MASK := 8  ## layer 4 "interactable"

var player: CharacterBody3D
var _cam: Camera3D
var _verb: StringName = &""
var _target: Node
var _hold_s := 0.0
var _t := 0.0
var _ring: MeshInstance3D
var _result := &""  ## last host answer for the autochore: done / refused / cancelled
var _holding := false
var _need_release := false  ## a refused hold waits for `interact` to be released before it retries
var _autopry := OS.get_cmdline_user_args().has("--autopry")
var _pin_t := 0.0
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
		var tgt := _look_target()
		aimed_verb = &""
		if tgt != null:
			var vs: Array[StringName] = tgt.verbs_for({})
			aimed_verb = vs[0] if not vs.is_empty() else &""
		if not Input.is_action_pressed(&"interact"):
			_need_release = false
		if tgt != null and not _need_release and Input.is_action_pressed(&"interact"):
			var verbs: Array[StringName] = tgt.verbs_for({})
			if not verbs.is_empty():
				start(verbs[0], tgt)
		return
	_t += delta
	_ring.scale = Vector3.ONE * clampf(_t / _hold_s, 0.01, 1.0)
	_ring.global_position = _target.target_pos() + Vector3(0, 1.4, 0)
	if not Input.is_action_pressed(&"interact") and not _scripted:
		cancel()


var _scripted := false


## HUD: the verb being held and its progress 0..1, or an empty verb.
func hold_state() -> Array:
	return [_verb, clampf(_t / maxf(_hold_s, 0.01), 0.0, 1.0)] if _holding else [&"", 0.0]


func start(verb: StringName, target: Node) -> void:
	_verb = verb
	_target = target
	_hold_s = Data.hold_s(verb)
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
	_ring.visible = false
	_result = result


func _look_target() -> Node:
	var from := _cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - _cam.global_transform.basis.z * REACH_M, PICK_MASK)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.collider.get_meta(&"interactable") if hit and hit.collider.has_meta(&"interactable") else null


func _on_apply(what: StringName, args: Array) -> void:
	if not _holding or not what in [&"hold_done", &"refused", &"hold_cancelled"] or args[0] != _verb:
		return
	match what:
		&"hold_done": _end(&"done")
		&"refused":
			_need_release = true
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
