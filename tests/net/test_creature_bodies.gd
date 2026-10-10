extends SceneTree
## P5-58 (Gameplay): the host forces a creature body and the client sees that body, with its art, moving.
## Run once per body as the client of a 2-instance session (tests/net/run_creature_bodies.sh loops all four):
##   uv run tools/qa/multi.py -n 2 --headless --duration 70 \
##     --args "-- --host --port=56650 --free-mouse --creature-test --creature-body=gaunt" \
##     --args "-s res://tests/net/test_creature_bodies.gd -- --join=127.0.0.1 --port=56650 --free-mouse --expect-body=body_gaunt"
## Passes when the client's Creature has `body` == the expected id, a mesh under Art from that body's glb (the glbs are static, no rig, so
## "animates" means it moves), has moved >= 3 m and has been in at least 2 states (the host is hunting).

var _t := 0.0
var _expect := ""
var _first := Vector3.INF
var _moved := 0.0
var _states := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--expect-body="):
			_expect = a.get_slice("=", 1)
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var cr := current_scene.find_child("Creature", true, false) if current_scene else null
	if cr != null:
		_states[cr.state] = true
		if _first == Vector3.INF:
			_first = cr.global_position
		_moved = maxf(_moved, cr.global_position.distance_to(_first))
		var art := cr.get_node_or_null("Art")
		var meshes := art.find_children("*", "MeshInstance3D", true, false) if art else []
		if cr.body == StringName(_expect) and meshes.size() > 0 and _moved >= 3.0 and _states.size() >= 2:
			print("test_creature_bodies: PASS %s (meshes %d, moved %.1f m, states %s)" % [_expect, meshes.size(), _moved, _states.keys()])
			quit(0)
			return false
	if _t > 60.0:
		print("test_creature_bodies: FAIL expect %s (creature %s, body %s, moved %.1f m, states %s)" % [_expect, cr != null, cr.body if cr else "-", _moved, _states.keys()])
		quit(1)
	return false
