extends SceneTree
## QA P5-55: the REAL local Player (move_and_slide, nav_path walk, no teleports: the host rubber-bands those) cannot walk out
## through a closed barn door, on the host and on a client. Walk to just inside the door, close it (host: Doors.host_set,
## client: request_hold, as a player would), walk out, expect to be stopped inside (local z < 0). Then open it and walk out.
## Host:   godot --headless --audio-driver Dummy -s res://tests/qa/qa_p5_55_door_walk.gd -- --host --port=56801 --free-mouse --seed=1
## Client: godot --headless --audio-driver Dummy -s res://tests/qa/qa_p5_55_door_walk.gd -- --join=127.0.0.1 --port=56801 --free-mouse
## Host with a client: add `--passive` to the host args and let the client do the walk (two actors race).
## Prints "QA_DOORWALK PASS|FAIL". The host stays up until the client is done (its quit would drop the client's peer id to 1).

var _t := 0.0
var _stage := 0
var _m: Node3D
var _pl: Node
var _at := -1.5


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			_at = float(a.substr(5))
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _local_z() -> float:
	return (_m.global_transform.affine_inverse() * _pl.global_position).z


func _physics_process(delta: float) -> bool:
	_t += delta
	if not root.has_node("Main/Doors") or not root.has_node("Game"):
		return false
	var game := root.get_node("Game")
	if OS.get_cmdline_user_args().has("--passive"):  # host while a client runs the test: only keep the session up
		if _t > 40.0:
			quit()
		return false
	var doors := root.get_node("Main/Doors")
	if _pl == null:
		var p := root.get_node_or_null("Main/Players/%d" % game.local_peer())
		if p == null:
			return false
		_pl = p
		for d: Node3D in get_nodes_in_group(&"doors"):
			if d.get_meta(&"building") == "barn":
				_m = d
		_t = 0.0
		_pl.nav_path = [_m.global_transform * Vector3(0, 0, _at)]  # just inside (`--at=<z>` overrides: 0 stands in the doorway as it closes)
		return false
	if _stage == 0 and _pl.nav_path.is_empty() and _t > 2.0:
		print("inside at z=%.2f" % _local_z())
		if game.is_host():
			doors.host_set("door_barn", false, 0)
		else:
			root.get_node("Net").to_host(&"request_hold", [&"close_door", "door_barn"])
		_stage = 1
		_t = 0.0
	elif _stage == 1 and _t > 2.0:
		print("closed seen: ", not doors.open["door_barn"])
		_pl.nav_path = [_m.global_transform * Vector3(0, 0, 4.0)]  # out
		_stage = 2
		_t = 0.0
	elif _stage == 2 and _t > 6.0:
		var z := _local_z()
		var ok: bool = z < 0.0 and not doors.open["door_barn"]
		print("closed: end local z=%.2f" % z)
		if game.is_host():
			doors.host_set("door_barn", true, 0)
		else:
			root.get_node("Net").to_host(&"request_hold", [&"open_door", "door_barn"])
		_stage = 3 if ok else 9
		_t = 0.0
	elif _stage == 3 and _t > 2.0:
		_pl.nav_path = [_m.global_transform * Vector3(0, 0, 4.0)]
		_stage = 4
		_t = 0.0
	elif (_stage == 4 and _t > 6.0) or _stage == 9:
		var z := _local_z()
		print("open: end local z=%.2f" % z)
		print("QA_DOORWALK ", "PASS" if _stage == 4 and z > 1.0 else "FAIL")
		if game.is_host():
			_stage = 10
			_t = 0.0
		else:
			quit()
	elif _stage == 10 and _t > 8.0:
		quit()
	return false
