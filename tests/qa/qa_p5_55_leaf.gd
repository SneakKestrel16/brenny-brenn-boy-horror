extends SceneTree
## P5-55: an open barn door leaf is solid (layer 1) where it sticks out (z 0..1.5 at x +-1.5), the gap between the
## leaves stays clear, and a closed door blocks the doorway. Host solo:
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/qa/qa_p5_55_leaf.gd -- --host --port=56812 --free-mouse

var _t := 0.0
var _closed_t := -1.0
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Doors") == null:
		if _t > 30.0:
			print("QA_LEAF FAIL (no Main)")
			quit(1)
		return false
	if _t < 2.0:
		return false  # let the physics server register the bodies
	var doors: Node = main.get_node("Doors")
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	if _closed_t < 0.0:
		_check(not _hit(space, Vector3(-3.0, 1.0, 0.7), Vector3(-1.0, 1.0, 0.7)).is_empty(), "open: the left leaf stops a ray at x -1.5")
		_check(not _hit(space, Vector3(3.0, 1.0, 0.7), Vector3(1.0, 1.0, 0.7)).is_empty(), "open: the right leaf stops a ray at x 1.5")
		_check(_hit(space, Vector3(-1.0, 1.0, 0.7), Vector3(1.0, 1.0, 0.7)).is_empty(), "open: the gap between the leaves is clear")
		_check(_hit(space, Vector3(0.0, 1.0, 3.0), Vector3(0.0, 1.0, -3.0)).is_empty(), "open: a ray straight through the doorway is clear")
		doors.host_set("door_barn", false, 0)
		_closed_t = _t
		return false
	if _t < _closed_t + 0.5:
		return false
	_check(not _hit(space, Vector3(0.0, 1.0, 3.0), Vector3(0.0, 1.0, -3.0)).is_empty(), "closed: the door blocks the doorway")
	print("QA_LEAF ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)
	return false


func _hit(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
