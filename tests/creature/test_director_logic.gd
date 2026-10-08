extends SceneTree
## Doc 03 section 11 unit checks for the AI Director rules (P3-04), on the shipped ai_director.json.
##   "$GODOT" --headless --path . -s res://tests/creature/test_director_logic.gd

const Logic := preload("res://game/ai_director/director_logic.gd")

var _fails := 0


func _init() -> void:
	var data: Node = preload("res://game/core/data.gd").new()
	data.load_dir("res://data")
	var r := {}
	for rec in data.records(&"ai_director"):
		r[String(rec.id)] = rec
	data.free()
	# phases: peak at 70, peak at most 20 s, fade to 30, relax at least 40 s
	var ph: Dictionary = r.phases
	_check(Logic.next_phase(&"build_up", 0.0, 69.9, ph, 40.0) == &"build_up", "build-up below peak_at")
	_check(Logic.next_phase(&"build_up", 0.0, 70.0, ph, 40.0) == &"peak", "peak at peak_at")
	_check(Logic.next_phase(&"peak", 19.9, 100.0, ph, 40.0) == &"peak", "peak holds under peak_max_s")
	_check(Logic.next_phase(&"peak", 20.0, 100.0, ph, 40.0) == &"fade", "fade after peak_max_s")
	_check(Logic.next_phase(&"fade", 5.0, 30.1, ph, 40.0) == &"fade", "fade above fade_to")
	_check(Logic.next_phase(&"fade", 5.0, 30.0, ph, 40.0) == &"relax", "relax at fade_to")
	_check(Logic.next_phase(&"relax", 39.9, 0.0, ph, 40.0) == &"relax", "relax holds its minimum")
	_check(Logic.next_phase(&"relax", 40.0, 1.0, ph, 40.0) == &"relax", "relax waits for an empty meter")
	_check(Logic.next_phase(&"relax", 40.0, 0.0, ph, 40.0) == &"build_up", "build-up after relax")
	_check(Logic.next_phase(&"relax", 40.0, 0.0, ph, 60.0) == &"relax", "a jumpscare's longer relax holds")
	# day arc: thirds of a 300 s day
	_check(Logic.day_third(0.0, 300.0, r.day_arc) == 1, "first third at dawn")
	_check(Logic.day_third(99.0, 300.0, r.day_arc) == 1, "first third to 1/3")
	_check(Logic.day_third(101.0, 300.0, r.day_arc) == 2, "second third")
	_check(Logic.day_third(201.0, 300.0, r.day_arc) == 3, "last third")
	# scare budget: 1 big per player per day, 120 s apart, unscared 3 : 1
	var sr: Dictionary = r.scare_rules
	_check(Logic.scare_ok(0, -INF, 0.0, sr), "first big scare allowed")
	_check(not Logic.scare_ok(1, -INF, 0.0, sr), "second big scare the same day refused")
	_check(not Logic.scare_ok(0, 100.0, 219.0, sr), "big scare within 120 s refused")
	_check(Logic.scare_ok(0, 100.0, 220.0, sr), "big scare after 120 s allowed")
	_check(is_equal_approx(Logic.scare_weight(0, sr) / Logic.scare_weight(1, sr), 3.0), "unscared weighted 3 : 1")
	# trap race: 25 m bent 3 m, normal trap floored, deep trap not
	_check(is_equal_approx(Logic.race_m(25.0, 3.0, -1.0, 21.0), 22.0), "normal race bends down to 22 m")
	_check(is_equal_approx(Logic.race_m(25.0, 3.0, -1.0, 23.0), 23.0), "normal race keeps its floor")
	_check(is_equal_approx(Logic.race_m(18.0, 3.0, -1.0, 0.0), 15.0), "deep race has no floor")
	# nudge: one hop on a chain a - b - c - d
	var links := {"a": ["b"], "b": ["a", "c"], "c": ["b", "d"], "d": ["c"]}
	_check(Logic.hop(links, "a", "d") == "b", "one hop toward d")
	_check(Logic.hop(links, "c", "d") == "d", "adjacent: the target")
	_check(Logic.hop(links, "b", "b") == "b", "already there")
	_check(Logic.hop(links, "a", "x") == "a", "no path: stay")
	print("test_director_logic: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
