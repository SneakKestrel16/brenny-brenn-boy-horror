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
	print("test_creature_logic: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
