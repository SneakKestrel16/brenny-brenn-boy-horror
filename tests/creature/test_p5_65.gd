extends SceneTree
## P5-65 (CEO playtest 2026-10-10, "the monster just stood there during the day"): by day it parked on its day
## cover all day. Solo host, real clock:
##   A, day third 1 (calm, doc 03 s11.3): it stays at its day cover, in lurk.
##   B, day third 2: it lurks through the corn (doc 03 s4 `lurk`, doc 01 "Behavior states"), more than 10 m walked
##      in 40 s and at least two cover points reached, still in lurk (no day chase, doc 03 s4.2).
##   C, day third 2 for 120 s (QA): at least 85% of the time in corn (`lurk_open_cost_mult_day`, doc 01 "What players
##      see": by day parts and motion only).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_65.gd -- --host --port=29650 --free-mouse
## Exits 0 on pass, 1 on any failure.

var _fails := 0
var _frames := 0
var main: Node
var cr: Node


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 60:
		_run()
	return false


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


## Seconds of physics; returns the metres walked, the cover points passed within 2 m and the share of frames in corn.
func _walk(s: float) -> Array:
	var t := 0.0
	var m := 0.0
	var at: Vector3 = cr.global_position
	var covers := {}
	var corn := 0
	var frames := 0
	while t < s:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		m += Vector2(cr.global_position.x - at.x, cr.global_position.z - at.z).length()
		at = cr.global_position
		frames += 1
		corn += 1 if cr._corn_rects().any(func(r: Rect2) -> bool: return r.has_point(Vector2(at.x, at.z))) else 0
		for n: Node3D in cr.get_tree().get_nodes_in_group(&"creature_cover"):
			if n.global_position.distance_to(at) < 2.0:
				covers[n.name] = true
	return [m, covers.keys(), float(corn) / maxi(frames, 1)]


func _run() -> void:
	var game := root.get_node("Game")
	main = root.get_node("Main")
	cr = main.get_node("Creature")
	var clock := root.get_node("Clock")
	for p: int in game.players.keys():  # far from every field, so the calm keep-out never moves the day cover
		game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		game.players[p].pos = Vector3(-60, 0, -60)
	var day_s: float = clock.length_of(&"day")

	print("A: day third 1")
	clock.t_phase = 0.05 * day_s
	var cover: Vector3 = main.get_node("AiDirector").day_cover(cr._marker(&"creature_cover", cr.DAY_COVER))
	cr.global_position = cover
	var a: Array = await _walk(10.0)
	_check(a[0] < 1.0 and cr.state == &"lurk", "stays at its day cover: %.1f m walked, state %s" % [a[0], cr.state])

	print("B: day third 2")
	clock.t_phase = 0.4 * day_s
	var b: Array = await _walk(40.0)
	_check(b[0] > 10.0, "lurks: %.1f m walked in 40 s" % b[0])
	_check(b[1].size() >= 2, "reaches cover points: %s" % [b[1]])
	_check(cr.state == &"lurk" and clock.phase == &"day", "still lurk by day: %s, %s" % [cr.state, clock.phase])

	print("C: day third 2, 120 s")
	var c: Array = await _walk(120.0)
	_check(c[2] >= 0.85, "in corn %.0f%% of the time" % (100.0 * c[2]))

	print("PASS" if _fails == 0 else "FAILED %d" % _fails)
	quit(1 if _fails else 0)
