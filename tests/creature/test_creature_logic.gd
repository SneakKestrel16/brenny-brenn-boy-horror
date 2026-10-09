extends SceneTree
## Doc 03 sections 3.1, 12.3 and 18 unit checks for the Phase 1 creature rules (P1-08).
##   "$GODOT" --headless --path . -s res://tests/creature/test_creature_logic.gd

const Logic := preload("res://game/creature/creature_logic.gd")

var _fails := 0


func _init() -> void:
	# phase1.json: lurk 60, chase 15 s into the stalk, chase 10, retreat 10
	var s := func(t: float, at: float) -> StringName: return Logic.scripted_state(t, at, 60.0, 15.0, 10.0, 10.0)
	_check(s.call(0.0, -1.0) == &"lurk", "lurk at night start")
	_check(s.call(59.9, 0.0) == &"lurk", "lurk until 60 s even with a stalk time")
	_check(s.call(120.0, -1.0) == &"lurk", "lurk while no player is outdoors")
	_check(s.call(60.0, 60.0) == &"stalk", "stalk begins at 60 s")
	_check(s.call(74.9, 60.0) == &"stalk", "still stalking at 14.9 s of stalk")
	_check(s.call(75.0, 60.0) == &"chase", "chase at 15 s of stalk")
	_check(s.call(84.9, 60.0) == &"chase", "chase lasts 10 s")
	_check(s.call(85.0, 60.0) == &"retreat", "retreat after 10 s of chase")
	_check(s.call(94.9, 60.0) == &"retreat", "retreat lasts 10 s")
	_check(s.call(95.0, 60.0) == &"", "script over at 95 s: hunts by sound")
	_check(s.call(110.0, 90.0) == &"chase", "late outdoor player: stalk starts late, chase 15 s later")
	# sound memory: 12 s memory, louder wins within 4 s, ties to the newest
	var m := [{"margin": 20.0, "t": 0.0, "peer": 2}, {"margin": 5.0, "t": 3.0, "peer": 3}]
	_check(Logic.pick_heard(m, 3.0, 12.0, 4.0).peer == 2, "louder within 4 s beats a newer quiet emit")
	m.append({"margin": 1.0, "t": 5.0, "peer": 4})
	_check(Logic.pick_heard(m, 5.0, 12.0, 4.0).peer == 3, "after 4 s the newer emits replace the loud one")
	_check(Logic.pick_heard(m, 17.1, 12.0, 4.0).is_empty(), "everything forgotten after 12 s")
	_check(Logic.pick_heard([{"margin": 2.0, "t": 1.0, "peer": 5}, {"margin": 2.0, "t": 2.0, "peer": 6}], 2.0, 12.0, 4.0).peer == 6, "ties go to the newest")
	# lure: largest reduction of distance since start
	var moved := 0.0
	for d in [30.0, 25.0, 18.0, 22.0]:
		moved = Logic.lure_moved(moved, 30.0, d)
	_check(is_equal_approx(moved, 12.0), "moved_m keeps the largest reduction (12)")
	# whose voice (P3-03): ai_director.json lures, target 1, bot -2 dead, -1 and -3 alive
	var d: Node = preload("res://game/core/data.gd").new()
	d.load_dir("res://data")
	var lw := {}
	for f in [&"weight_dead", &"weight_alive", &"weight_own", &"weight_stranger"]:
		lw[f] = float(d.value(&"ai_director", &"lures", f))
	d.free()
	var w := PackedFloat32Array([lw[&"weight_stranger"]])
	for q in [1, -1, -2, -3]:
		w.append(Logic.voice_weight(q, 1, q == -2, lw))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dead_n := 0
	for i in 10000:
		dead_n += int(rng.rand_weighted(w) == 3)
	_check(w[3] > w[2] and w[2] > w[1], "dead outweighs alive outweighs own")
	_check(dead_n > 10000 / 5, "dead bot voiced more than a fair 1-in-5 share (%d of 10000)" % dead_n)
	# Taint tracking (P3-07): 60 m radius, trail picked up within 3 m, 3 steps ahead
	var trail := []
	for i in 10:
		trail.append({"position": Vector3(100.0 + 2.0 * i, 0, 0), "t": float(i)})
	var fix := func(from: Vector3, pos: Vector3) -> Vector3: return Logic.taint_fix(from, pos, trail, 60.0, 3.0, 3)
	_check(fix.call(Vector3.ZERO, Vector3(59, 0, 0)) == Vector3(59, 0, 0), "a Tainted player within 60 m is tracked where they are")
	_check(fix.call(Vector3.ZERO, Vector3(130, 0, 0)) == Vector3.INF, "beyond 60 m and off the trail: nothing")
	_check(fix.call(Vector3(101, 0, 1), Vector3(200, 0, 0)) == Vector3(108, 0, 0), "on the trail: 3 steps newer than the newest point within 3 m")
	_check(fix.call(Vector3(117, 0, 0), Vector3(200, 0, 0)) == Vector3(118, 0, 0), "near the trail's head: its newest point")
	_check(Logic.taint_fix(Vector3.ZERO, Vector3(130, 0, 0), [], 60.0, 3.0, 3) == Vector3.INF, "no trail (washed, or by day): nothing")
	# season body (P4-13): seeded, stable per seed, forced by --body, all four reachable
	var ids := [&"body_gaunt", &"body_scarecrow", &"body_boar", &"body_husk"]
	_check(Logic.pick_body(ids, 42) == Logic.pick_body(ids, 42), "one seed, one body")
	_check(Logic.pick_body(ids, 42, "boar") == &"body_boar", "--body=boar forces it")
	_check(Logic.pick_body(ids, 42, "body_husk") == &"body_husk", "--body=body_husk forces it")
	_check(Logic.pick_body(ids, 42, "dragon") == Logic.pick_body(ids, 42), "an unknown --body falls back to the seed")
	var seen := {}
	for i in 64:
		seen[Logic.pick_body(ids, i)] = true
	_check(seen.size() == 4, "64 seeds reach all four bodies (%d)" % seen.size())
	print("test_creature_logic: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
