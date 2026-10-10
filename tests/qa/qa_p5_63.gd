extends SceneTree
## QA P5-63: in the running full farm, every can's lowest mesh point sits on the ground under it (3 cm), and so do
## the prop models; a 5 cm sphere cannot slip through any building or pen corner; PNGs of the corners and cans.
## Windowed host solo (ports 32000-32999 while the CEO may play on the default):
##   "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 -s res://tests/qa/qa_p5_63.gd -- --host --lobby-start=1 --no-intro --port=32610 --free-mouse --out=<dir>
## Prints one line per check and "QA_P5_63 PASS|FAIL".

const BOXES := {  # building and pen outlines (wall centrelines), build_farm.py
	"barn": [-8, 8, -20, 0], "farmhouse": [-51, -39, -10, 0], "shed": [-18, -12, 26, 31], "pen": [-30, -18, -38, -28]}

var _t := 0.0
var _done := false
var _fails := 0
var _out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := root.get_node_or_null("Main") as Node3D
	if _done or main == null or main.get_node_or_null("Farm/Cans") == null or _t < 4.0:
		if _t > 60.0 and not _done:
			print("QA_P5_63 FAIL (no Main)")
			quit(1)
		return false
	_done = true
	_run(main)
	return false


func _run(main: Node3D) -> void:
	var space := main.get_world_3d().direct_space_state
	var cans: Node = main.get_node("Farm/Cans")
	for id in cans.cans:
		_on_ground(space, "can %d (%s)" % [id, cans.cans[id].kind], cans.cans[id].node)
	for n in main.get_node("World/Props").get_children():
		var art := n.get_node_or_null("Art") as Node3D
		if art and n.name != "FarmGate":  # the gate model is the gate, posts hang it
			_on_ground(space, "prop %s" % n.name, art)
	for k in BOXES:
		var b: Array = BOXES[k]
		for c in [Vector2(b[0], b[2]), Vector2(b[1], b[2]), Vector2(b[0], b[3]), Vector2(b[1], b[3])]:
			var out := Vector2(signf(c.x - (b[0] + b[1]) / 2.0), signf(c.y - (b[2] + b[3]) / 2.0)).normalized()
			var q := PhysicsShapeQueryParameters3D.new()
			var s := SphereShape3D.new()
			s.radius = 0.05
			q.shape = s
			q.collision_mask = 1
			q.transform.origin = Vector3(c.x + out.x, 1.0, c.y + out.y)
			q.motion = Vector3(-out.x, 0, -out.y) * 2.0
			var safe: float = space.cast_motion(q)[0]
			_check(safe < 1.0, "%s corner (%.0f, %.0f) closed to a 5 cm sphere (safe %.2f)" % [k, c.x, c.y, safe])
	_shots.call_deferred(main, cans)


## The node's lowest visible mesh point vs the world collision straight under its origin.
func _on_ground(space: PhysicsDirectSpaceState3D, what: String, n: Node3D) -> void:
	var low := INF
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if not m.is_visible_in_tree():
			continue
		var bb := m.global_transform * m.get_aabb()
		low = minf(low, bb.position.y)
	var p := n.global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -2, 0), 1)
	var bodies := n.find_children("*", "CollisionObject3D", true, false).map(func(b: CollisionObject3D) -> RID: return b.get_rid())
	if n.get_parent() is CollisionObject3D:
		bodies.append((n.get_parent() as CollisionObject3D).get_rid())
	q.exclude = bodies
	var hit := space.intersect_ray(q)
	var ground: float = hit.position.y if hit else 0.0
	_check(absf(low - ground) <= 0.03, "%s at (%.1f, %.1f): lowest mesh y %.3f, support y %.3f" % [what, p.x, p.z, low, ground])


func _shots(main: Node3D, cans: Node) -> void:
	for c in main.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	var list: Array = []
	for id in cans.cans:
		var p: Vector3 = cans.cans[id].node.global_position
		list.append(["can%d" % id, p + Vector3(1.2, 0.5, 1.2), p + Vector3(0, 0.2, 0)])
	for k in BOXES:
		var b: Array = BOXES[k]
		var mid := Vector3((b[0] + b[1]) / 2.0, 0, (b[2] + b[3]) / 2.0)
		for c in [Vector3(b[0], 0, b[2]), Vector3(b[1], 0, b[2]), Vector3(b[0], 0, b[3]), Vector3(b[1], 0, b[3])]:
			var out := Vector3(c.x - mid.x, 0, c.z - mid.z).normalized()
			list.append(["%s_out_%d_%d" % [k, c.x, c.z], c + out * 3.0 + Vector3(0, 1.7, 0), c + Vector3(0, 1.0, 0)])
			if k != "pen":
				list.append(["%s_in_%d_%d" % [k, c.x, c.z], c - out * 2.5 + Vector3(0, 1.7, 0), c + Vector3(0, 1.5, 0)])
	for d in [["barn_door", Vector3(0, 2, 7), Vector3(0, 1.5, 0)], ["farmhouse_door", Vector3(-45, 2, 6), Vector3(-45, 1.5, 0)],
			["shed_door", Vector3(-15, 2, 20), Vector3(-15, 1.2, 26)]]:
		list.append(d)
	for s in list:
		cam.global_position = s[1]
		cam.look_at(s[2])
		for i in 20:
			await process_frame
		if _out != "":
			root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
	print("QA_P5_63 ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("ok   " if ok else "FAIL ", what)
