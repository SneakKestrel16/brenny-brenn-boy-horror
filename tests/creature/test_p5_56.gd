extends SceneTree
## P5-56 creature AI checks, one per change (each behind a creature.json number, 0 = off), on frozen bots:
##   A, Logic.open_m: metres of a segment outside the corn rects (overlaps counted once).
##   B, Logic.corn_route: a route through corn waypoints when the open costs more; straight with open_mult 0.
##   C, Logic.corn_waypoints: ring waypoints sit inside the wide corn, on the edge facing the farm.
##   D, lurk wander (`lurk_open_cost_mult`, Q-354): picks cover points only, and its route from the pumpkin's cover to
##      the barn's walks fewer open metres than the straight line, through corn.
##   E, linger (`lurk_linger_s`): at a route's end it waits, then picks again.
##   F, anti-repetition (`wander_recent_s`): consecutive picks in a region do not repeat while others are free.
##   G, search (`search_radius_m`): a lost chase checks the cover and trap spots round the last sensed position.
##   H, traffic traps (`trap_traffic_m`): night trap spots go where the heard player noises are.
##   I, stuck: a lurk walk pushing into the pen's fence drops its hop after STUCK_S.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_56.gd -- --host --bots=3 --port=56420 --free-mouse
## Exits 0 on pass, 1 on any failure.

const Logic := preload("res://game/creature/creature_logic.gd")

var _fails := 0
var _frames := 0
var _ev: Array = []
var Game: Node
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


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _route_open(from: Vector2, route: Array, corn: Array) -> float:
	var m := 0.0
	var at := from
	for p: Vector2 in route:
		m += Logic.open_m(at, p, corn)
		at = p
	return m


func _reset_wander() -> void:
	cr._goal = Vector3.INF
	cr._route.clear()
	cr._dest = Vector3.INF
	cr._linger_until = -INF


func _run() -> void:
	Game = root.get_node("Game")
	main = root.get_node("Main")
	cr = main.get_node("Creature")
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	var dir: Node = main.get_node("AiDirector")
	var ids: Array = Game.players.keys()
	for p: int in ids:
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[p].pos = Vector3(-60, 0, -60) + Vector3(p % 7, 0, 0)
	for b in main.get_node("Bots").get_children():
		b.process_mode = Node.PROCESS_MODE_DISABLED
	var dev: Node
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	dev.run("day 2")
	await _wait(1.0)

	print("A: open metres")
	var box := [Rect2(0, -5, 10, 10)]
	_check(is_equal_approx(Logic.open_m(Vector2(-10, 0), Vector2(20, 0), box), 20.0), "a 30 m line through a 10 m box: 20 m open (%.2f)" % Logic.open_m(Vector2(-10, 0), Vector2(20, 0), box))
	_check(is_zero_approx(Logic.open_m(Vector2(1, 0), Vector2(9, 1), box)), "inside the box: 0 m open")
	_check(is_equal_approx(Logic.open_m(Vector2(-10, 0), Vector2(20, 0), box + [Rect2(5, -1, 10, 2)]), 15.0), "overlapping boxes count once: 15 m open")
	_check(is_equal_approx(Logic.open_m(Vector2(-10, 20), Vector2(20, 20), box), 30.0), "a line past the box: 30 m open")

	print("B: corn route")
	# an L of corn: down x 0..4 and along z 40..44; the straight line from (2, 2) to (40, 42) is mostly open
	var ell := [Rect2(0, 0, 4, 44), Rect2(0, 40, 44, 4)]
	var via := [Vector2(2, 42)]
	var r1 := Logic.corn_route(Vector2(2, 2), Vector2(40, 42), via, ell, 4.0)
	_check(r1 == [Vector2(2, 42), Vector2(40, 42)], "open_mult 4 walks the L: %s" % [r1])
	var r0 := Logic.corn_route(Vector2(2, 2), Vector2(40, 42), via, ell, 0.0)
	_check(r0 == [Vector2(40, 42)], "open_mult 0 walks straight: %s" % [r0])

	print("C: ring waypoints")
	var corn: Array = cr._corn_rects()
	_check(corn.size() >= 20, "CornBlockers rects read: %d" % corn.size())
	var wps := Logic.corn_waypoints(corn, cr.RING_STEP_M, cr.RING_INSET_M, cr.RING_MIN_M)
	var inside := wps.filter(func(p: Vector2) -> bool: return Logic.open_m(p, p + Vector2(0.01, 0), corn) == 0.0)
	_check(wps.size() >= 20 and inside.size() == wps.size(), "%d ring waypoints, %d inside corn" % [wps.size(), inside.size()])
	var clearing := Rect2(-65, -45, 170, 100)  # doc 04: the clearing inside the corn ring
	var pad: float = cr.RING_INSET_M + 0.5
	var edge := wps.filter(func(p: Vector2) -> bool: return not clearing.has_point(p) and (absf(p.x - clearing.position.x) <= pad \
			or absf(p.x - clearing.end.x) <= pad or absf(p.y - clearing.position.y) <= pad or absf(p.y - clearing.end.y) <= pad))
	_check(edge.size() == wps.size(), "all on the ring's inner edge (%d of %d)" % [edge.size(), wps.size()])

	print("D: lurk routes through corn")
	cr._scripted = false
	cr._set_state(&"lurk", &"dev", 0)
	dev.run("phase night")
	await _wait(0.5)
	var cover_pts := get_nodes_in_group(&"creature_cover").map(func(n: Node3D) -> Vector2: return _flat(n.global_position))
	var trap_pts := get_nodes_in_group(&"trap_spots").map(func(n: Node3D) -> Vector2: return _flat(n.global_position))
	var on_cover := 0
	var on_trap := 0
	var keep_region: String = dir.wander_region
	for reg: String in ["yard", "pen", "pumpkin", "field_a", "field_b", "moonflower"]:
		dir.wander_region = reg
		for i in 20:
			cr.global_position = Vector3(20, 0, 10)
			_reset_wander()
			cr._wander()
			var d := _flat(cr._dest)
			var cov := cover_pts.any(func(p: Vector2) -> bool: return p.distance_to(d) < 0.1)
			on_cover += 1 if cov else 0
			on_trap += 1 if not cov and trap_pts.any(func(p: Vector2) -> bool: return p.distance_to(d) < 0.1) else 0  # some cover points share a trap spot's place
	_check(on_cover == 120 and on_trap == 0, "120 picks: %d on cover points, %d on trap spots" % [on_cover, on_trap])
	var c10 := Vector2(-47, 42)  # doc 04 s7.2 cover_10, Prize Pumpkin
	var c01 := Vector3(13, 0, -6)  # cover_01, barn door
	var route: Array = Logic.corn_route(c10, _flat(c01), cr._corn_via(), corn, cr._num[&"lurk_open_cost_mult"], cr._via_cost)
	var straight := Logic.open_m(c10, _flat(c01), corn)
	var walked := _route_open(c10, route, corn)
	# cover_01 stands in the open yard, so the last stretch is open whatever the route; the corn saves the rest
	_check(walked < straight * 0.75, "cover_10 to cover_01: %.0f open metres routed, %.0f straight (%d hops)" % [walked, straight, route.size()])

	print("E: linger at the route's end")
	_reset_wander()
	cr._dest = Vector3(cr.global_position)
	cr._wander()
	var linger: float = cr._num[&"lurk_linger_s"]
	_check(cr._goal == Vector3.INF and is_equal_approx(cr._linger_until, cr._now + linger), "it waits %.0f s: goal %s" % [linger, cr._goal])
	cr._linger_until = cr._now - 0.1
	cr._wander()
	_check(cr._goal != Vector3.INF, "then picks again")

	print("F: no repeats")
	cr._picked.clear()
	dir.wander_region = "field_b"
	var seen := {}
	var picks := 0
	for i in 4:
		cr.global_position = Vector3(20, 0, 10)
		_reset_wander()
		cr._wander()
		seen[cr._key(cr._dest)] = true
		picks += 1
	_check(seen.size() == picks, "%d field_b picks, %d different" % [picks, seen.size()])
	dir.wander_region = keep_region

	print("G: search round the last sensed position")
	var radius: float = cr._num[&"search_radius_m"]
	var spots_all: Array = (get_nodes_in_group(&"creature_cover") + get_nodes_in_group(&"trap_spots")).map(func(n: Node3D) -> Vector3: return n.global_position)
	var centre := Vector3.INF  # the cover point with the most search points round it
	var most := 0
	for p: Vector3 in spots_all:
		var n := spots_all.filter(func(q: Vector3) -> bool: return q.distance_to(p) <= radius).size()
		if n > most:
			most = n
			centre = p
	cr.global_position = centre
	cr._goal = centre
	cr._search_c = centre
	cr._searched.clear()
	cr._search_until = cr._now + 1000.0
	var checked: Array = []
	for i in 12:
		cr._search_next()
		if cr._goal.distance_to(cr.global_position) < 0.1:
			break
		checked.append(cr._goal)
		cr.global_position = cr._goal
	var within :=checked.filter(func(p: Vector3) -> bool: return p.distance_to(centre) <= radius)
	_check(checked.size() >= 2 and within.size() == checked.size(), "round %s (%d points within %.0f m): checked %d, all within: %s" % [centre, most, radius, checked.size(), checked])
	cr._search_until = -1.0
	cr._search_c = Vector3.INF

	print("H: traps on the heard paths")
	var spots := get_nodes_in_group(&"trap_spots").filter(func(n: Node3D) -> bool: return n.get_meta("kind", "") != "deep")
	var hot: Vector3 = (spots[0] as Node3D).global_position
	cr._work.clear()
	for i in 30:
		cr._work.append(hot + Vector3(i % 5 - 2, 0, i % 3 - 1))
	for i in 5:
		cr._work.append(Vector3(i * 30 - 40, 0, 50))
	var hits := 0
	for i in 100:
		var pick: Dictionary = cr._pick_spot(&"bear")
		if not pick.is_empty() and (pick.node as Node3D).global_position.distance_to(hot) <= cr._num[&"trap_traffic_m"]:
			hits += 1
	_check(hits >= 70, "%d of 100 picks within %.0f m of the busy spot" % [hits, cr._num[&"trap_traffic_m"]])
	cr._work.clear()

	print("I: a lurk walk into the pen fence gives up")
	_ev.clear()
	cr._set_state(&"lurk", &"dev", 0)
	cr._memory.clear()
	cr.global_position = Vector3(-25.4, 0, -38.5)  # the probe's stuck spot: pushing south-west into the pen
	_reset_wander()
	cr._goal = Vector3(-47, 0, 42)
	cr._dest = cr._goal
	await _wait(cr.STUCK_S + 1.0)
	var stuck := _ev.any(func(e: Array) -> bool: return e[0] == "creature_stuck")
	_check(stuck, "dropped the hop: creature_stuck logged")

	print("test_p5_56: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
