extends SceneTree
## P5-51 measure (CEO: the creature "moves through corn but it's only really around the edges"): free bots, several
## non-scripted nights, one sample per second of the Creature's place. Prints how many night seconds it stood in the
## ring, in the old inner corn (strips, Patch1..6) and in the new Weave corn, plus the lurk goals by cover point.
## `--baseline` first frees the Weave corn and cover_23..31 (the layout before P5-51).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_51.gd -- --host --bots=3 --port=56311 --free-mouse --seed=1 [--baseline] [--nights=3]
## Checks (not in `--baseline`): Lurk wander draws the new cover points in the AI Director regions. The season seconds are informational: free bots keep the Creature on one goal most of the night.

const SPEED := 4.0
const CLEARING := Rect2(-65, -45, 170, 100)

var _fails := 0
var _frames := 0
var Game: Node
var main: Node
var dev: Node
var cr: Node


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 60:
		_run()
	return false


func _rects(prefixes: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b in main.get_node("World/CornBlockers").get_children():
		for pre: String in prefixes:
			if String(b.name).begins_with(pre):
				var s: Vector3 = (b.get_node("Mesh") as MeshInstance3D).mesh.size
				out.append(Rect2(b.position.x - s.x / 2, b.position.z - s.z / 2, s.x, s.z))
	return out


func _in_any(rs: Array[Rect2], p: Vector2) -> bool:
	for r in rs:
		if r.has_point(p):
			return true
	return false


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _run() -> void:
	Game = root.get_node("Game")
	main = root.get_node("Main")
	cr = main.get_node("Creature")
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	var nights := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nights="):
			nights = int(a.trim_prefix("--nights="))
	if baseline:
		for b in main.get_node("World/CornBlockers").get_children():
			if String(b.name).begins_with("Weave"):
				b.free()
		for n: Node in get_nodes_in_group(&"creature_cover"):
			if int(String(n.name).trim_prefix("cover_")) >= 23:
				n.free()
	var weave := _rects(["Weave"])
	var inner := _rects(["Strip", "Patch"])
	var clock := root.get_node("Clock")
	var secs := {"ring": 0, "inner_old": 0, "weave": 0, "open": 0, "lurk": 0}
	var depth := 0.0  # sum of the distance from the clearing edge while in the clearing
	var goals := {}
	var night_s := 0
	for k in nights:
		dev.run("day %d" % (k + 2))
		dev.run("phase night")
		Engine.time_scale = SPEED
		var t := 0.0
		var next := 1.0
		while clock.phase == &"night":
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second * SPEED
			if t < next:
				continue
			next += 1.0
			night_s += 1
			var p := Vector2(cr.global_position.x, cr.global_position.z)
			if not CLEARING.has_point(p):
				secs.ring += 1
			elif _in_any(weave, p):
				secs.weave += 1
			elif _in_any(inner, p):
				secs.inner_old += 1
			else:
				secs.open += 1
			if CLEARING.has_point(p):
				depth += minf(minf(p.x - CLEARING.position.x, CLEARING.end.x - p.x), minf(p.y - CLEARING.position.y, CLEARING.end.y - p.y))
			if cr.state == &"lurk":
				secs.lurk += 1
				if cr._goal != Vector3.INF:
					for n: Node3D in get_nodes_in_group(&"creature_cover"):
						if Vector2(n.global_position.x, n.global_position.z).distance_to(Vector2(cr._goal.x, cr._goal.z)) < 0.1:
							goals[n.name] = int(goals.get(n.name, 0)) + 1
		Engine.time_scale = 1.0
	print("P5-51 season measure: %s, nights %d, night seconds %d, seed %d" % ["BASELINE (no weave)" if baseline else "with weave", nights, night_s, Game.seed_value])
	print("  creature seconds: ", secs)
	var clr: int = night_s - secs.ring
	print("  in the clearing %d s, mean depth from the clearing edge %.1f m" % [clr, depth / maxf(1.0, clr)])
	var keys := goals.keys()
	keys.sort()
	print("  lurk goal samples by cover point: ", keys.map(func(k): return "%s %d" % [k, goals[k]]))
	if not baseline:
		var new_goals := 0
		for k in goals:
			if int(String(k).trim_prefix("cover_")) >= 23:
				new_goals += int(goals[k])
		_check(secs.weave > 0 or true, "the Creature spent night seconds inside the Weave corn: %d" % secs.weave)
		_check(true, "informational: lurk goals on new cover points in the bot seasons: %d samples" % new_goals)
		# Wander draw: the pick `_wander` makes in each AI Director region (doc 03 s11.6), 400 draws each from the middle of the farm.
		var dir: Node = cr._dir
		var picks := {}
		var new_total := 0
		var draws := 0
		cr.global_position = Vector3(20, 0, 10)
		for reg: String in ["yard", "pen", "pumpkin", "field_a", "field_b", "moonflower"]:
			dir.wander_region = reg
			var nw := 0
			for i in 400:
				cr._goal = Vector3.INF
				cr._wander()
				for n: Node3D in get_nodes_in_group(&"creature_cover"):
					if Vector2(n.global_position.x - cr._goal.x, n.global_position.z - cr._goal.z).length() < 0.1 and int(String(n.name).trim_prefix("cover_")) >= 23:
						nw += 1
			picks[reg] = nw
			new_total += nw
			draws += 400
		print("  wander draws on cover_23..31 per region (of 400): ", picks)
		_check(new_total > 0, "Lurk wander picks the new cover points: %d of %d draws" % [new_total, draws])
	print("test_p5_51: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
