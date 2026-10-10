extends SceneTree
## P5-55: an interactable cannot be picked, or held, through a wall. The tool shed pegboard sits against the
## shed's back wall (z 31.1-31.5): HoldController.pick from outside (z 32.5) finds nothing, from inside
## (z 28.5) finds the pegboard, and the host refuses a hold from outside with `out_of_sight`.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_p5_55_pick_los.gd -- --host --port=56810 --free-mouse

var _t := 0.0
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null:
		if _t > 30.0:
			print("test_p5_55_pick_los: FAIL (no Main after 30 s)")
			quit(1)
		return false
	var farm: Node = main.get_node("Farm")
	if not farm.targets.has("pegboard"):
		print("test_p5_55_pick_los: FAIL (no pegboard target)")
		quit(1)
		return false
	var peg: Object = farm.targets["pegboard"]
	var space: PhysicsDirectSpaceState3D = (peg.get_parent() as Node3D).get_world_3d().direct_space_state
	var at := Vector3(-15, 1.6, 30.5)
	_check(_pick(space, Vector3(-15, 1.6, 28.5), at) == peg, "from inside the shed the ray finds the pegboard")
	_check(_pick(space, Vector3(-15, 1.6, 32.5), at) == null, "from outside the back wall the ray finds nothing")
	var reg: Node = farm.get_node_or_null("HoldRegistry")
	_check(reg != null, "host has the hold registry")
	if reg != null:
		var me: int = root.get_node("Game").local_peer()
		var st: Dictionary = farm.pstate(me)
		var old: Vector3 = st.pos
		st.pos = Vector3(-15, 0, 32.5)
		_check(reg._validate(me, &"take_shovel", "pegboard") == &"out_of_sight", "host refuses the hold from outside: out_of_sight")
		st.pos = Vector3(-15, 0, 28.5)
		_check(reg._validate(me, &"take_shovel", "pegboard") != &"out_of_sight", "host does not refuse from inside")
		main.get_node("Doors").host_set("door_barn", false, 0)  # closed: its DoorBlock must not hide the door from the host
		for p in [Vector3(2.8, 0, 0.75), Vector3(-2.8, 0, -0.75), Vector3(2.8, 0, -0.75), Vector3(0, 0, 2.5)]:
			st.pos = p
			_check(reg._validate(me, &"open_door", "door_barn") == &"", "host accepts open_door on a closed barn door from %s (got %s)" % [p, reg._validate(me, &"open_door", "door_barn")])
		st.pos = old
	print("test_p5_55_pick_los: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
	return false


func _pick(space: PhysicsDirectSpaceState3D, from: Vector3, at: Vector3) -> Object:
	return load("res://game/interaction/hold_controller.gd").pick(space, from, from + (at - from).normalized() * 3.0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
