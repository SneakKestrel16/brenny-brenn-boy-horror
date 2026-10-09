extends SceneTree
## P4-33 follow-up: a flag planted on a set trap must not steal the aim from the trap. Sets a bear trap,
## plants the local player's flag on the same spot (the worst case) and someone else's beside it, then casts
## HoldController.pick (layer 4, 3 m) at the trap from eight sides at standing eye height: every
## ray must find the trap's target (D-142: the pick sees through a flag to the trap). Both flags can be pulled up, so
## both have a pick body; a ray at the cloth finds the flag. Passes headless too:
##   "$GODOT" --audio-driver Dummy --path . -s res://tests/gameplay/test_flag_pick.gd -- --host --port=24866 --free-mouse

var _t := 0.0
var _step := 0
var _id := ""
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null:
		if _t > 30.0:
			print("test_flag_pick: FAIL (no Main after 30 s)")
			quit(1)
		return false
	var farm: Node = main.get_node("Farm")
	var sweep := get_first_node_in_group(&"trap_sweep")
	var race := get_first_node_in_group(&"trap_race")
	var me: int = root.get_node("Game").local_peer()
	if _step == 0:
		var spot: Node3D = get_nodes_in_group(&"trap_spots")[0]
		_id = String(spot.name)
		main.get_node("Creature")._arm(spot, &"bear", {"dev": true})
		race.sync_set()
		_step = 1
		return false
	if _step == 1:
		var p: Vector3 = farm.targets[_id].target_pos()
		var on := Vector3(p.x, 0.0, p.z)
		sweep.add_flag(on, me)  # mine, right on the trap
		sweep.add_flag(on + Vector3(0.8, 0, 0), 999)  # someone else's, beside it
		_step = 2
		_t = 0.0
		return false
	if _t < 0.5:
		return false  # let the pick bodies enter the physics space
	var trap: Node = farm.targets[_id]
	var p: Vector3 = trap.target_pos()
	var space: PhysicsDirectSpaceState3D = (trap.get_parent() as Node3D).get_world_3d().direct_space_state
	for i in 8:
		var a := TAU * i / 8.0
		var eye := p + Vector3(sin(a) * 1.5, 1.6, cos(a) * 1.5)
		var hit := _pick(space, eye, p + Vector3(0, 0.2, 0))
		_check(hit == trap, "from side %d the ray finds the trap (got %s)" % [i, hit])
	var flags: Array = []
	var picks := 0
	for n in sweep.find_children("*", "StaticBody3D", true, false):
		picks += 1
		flags.append(n.get_meta(&"interactable"))
	_check(picks == 2, "every flag has a pick body (%d)" % picks)
	var mine: Node = flags.filter(func(s: Node) -> bool: return s.by == me)[0]
	var cloth := p + Vector3(0, 1.4, 0)
	_check(_pick(space, cloth + Vector3(0, 0.2, 1.5), cloth) == mine, "a ray at the cloth finds my flag")
	print("test_flag_pick: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
	return false


func _pick(space: PhysicsDirectSpaceState3D, from: Vector3, at: Vector3) -> Object:
	return load("res://game/interaction/hold_controller.gd").pick(space, from, from + (at - from).normalized() * 3.0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
