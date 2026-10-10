extends SceneTree
## Doc 03 section 11 unit checks for the AI Director rules (P3-04), on the shipped ai_director.json.
##   "$GODOT" --headless --path . -s res://tests/creature/test_director_logic.gd

const Logic := preload("res://game/ai_director/director_logic.gd")
const Sab := preload("res://game/ai_director/sabotage_logic.gd")

var _fails := 0


func _init() -> void:
	var data: Node = preload("res://game/core/data.gd").new()
	data.load_dir("res://data")
	var r := {}
	for rec in data.records(&"ai_director"):
		r[String(rec.id)] = rec
	var sab: Array = data.records(&"sabotage")
	var dist: Array = []  # ramp_up disturbances per day at 2, 3 and 4 players
	for day in range(1, 8):
		var v := int(data.record(&"ramp_up", StringName("day_%d" % day)).disturbances_4p)
		dist.append([data.scaled(v, &"disturbances", 2), data.scaled(v, &"disturbances", 3), data.scaled(v, &"disturbances", 4)])
	data.free()
	# phases: peak at 70, peak at most 20 s, fade to 30 or 20 s, relax at least 40 s and at most 40 s
	var ph: Dictionary = r.phases
	_check(Logic.next_phase(&"build_up", 0.0, 69.9, ph, 40.0) == &"build_up", "build-up below peak_at")
	_check(Logic.next_phase(&"build_up", 0.0, 70.0, ph, 40.0) == &"peak", "peak at peak_at")
	_check(Logic.next_phase(&"peak", 19.9, 100.0, ph, 40.0) == &"peak", "peak holds under peak_max_s")
	_check(Logic.next_phase(&"peak", 20.0, 100.0, ph, 40.0) == &"fade", "fade after peak_max_s")
	_check(Logic.next_phase(&"fade", 5.0, 30.1, ph, 40.0) == &"fade", "fade above fade_to")
	_check(Logic.next_phase(&"fade", 5.0, 30.0, ph, 40.0) == &"relax", "relax at fade_to")
	_check(Logic.next_phase(&"relax", 39.9, 0.0, ph, 40.0) == &"relax", "relax holds its minimum")
	_check(Logic.next_phase(&"relax", 35.0, 1.0, ph, 30.0) == &"relax", "relax waits for an empty meter under relax_max_s")
	_check(Logic.next_phase(&"relax", 35.0, 0.0, ph, 30.0) == &"build_up", "build-up after relax with an empty meter")
	_check(Logic.next_phase(&"relax", 40.0, 0.0, ph, 40.0) == &"build_up", "build-up after relax")
	_check(Logic.next_phase(&"relax", 40.0, 0.0, ph, 60.0) == &"relax", "a jumpscare's longer relax holds")
	_check(Logic.next_phase(&"fade", 19.9, 90.0, ph, 40.0) == &"fade", "fade holds under fade_max_s")
	_check(Logic.next_phase(&"fade", 20.0, 90.0, ph, 40.0) == &"relax", "relax after fade_max_s with the meter up (P5-33)")
	_check(Logic.next_phase(&"relax", 40.0, 90.0, ph, 40.0) == &"build_up", "build-up after relax_max_s with the meter up (P5-33)")
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
	# scares (P3-05): hallucination opens day 5 in third 2, x2 Tainted; jumpscare third 3 only
	var h: Dictionary = r.scare_hallucination
	_check(Logic.scare_weight_of(h, 4, 3, false) == 0.0, "no hallucination before day 5")
	_check(Logic.scare_weight_of(h, 5, 1, false) == 0.0, "no hallucination in the calm third")
	_check(Logic.scare_weight_of(h, 5, 2, false) == 1.0, "hallucination on day 5, third 2")
	_check(Logic.scare_weight_of(h, 5, 2, true) == 2.0, "Tainted see hallucinations x2")
	_check(Logic.scare_weight_of(r.scare_jumpscare, 1, 2, false) == 0.0, "no jumpscare in third 2")
	_check(Logic.scare_weight_of(r.scare_jumpscare, 1, 3, true) == 1.0, "jumpscare in third 3, Taint changes nothing")
	_check(Logic.scare_weight_of(r.scare_fake_out, 1, 0, false) == 1.0, "fake-out open at night")
	_check(Logic.scare_weight_of(r.scare_scarecrow_moved, 9, 3, false) == 0.0, "scarecrow moved is never rolled")
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
	# sabotage (P3-06, doc 03 section 10): the pool opens by day (opens_day in sabotage.json; P4-03 enabled broken_fence day 2, pumpkin_gnaw day 3)
	_check(Sab.pool(sab, 1) == [&"trample", &"stolen_tool"], "day 1 pool: trample, stolen tool")
	_check(Sab.pool(sab, 2) == [&"trample", &"stolen_tool", &"broken_fence"], "day 2 pool: broken fence joins (P4-03 enabled, P4-08)")
	_check(Sab.pool(sab, 3) == [&"trample", &"stolen_tool", &"dead_crow", &"strange_seeds", &"broken_fence", &"pumpkin_gnaw"], "day 3 adds the Taint sources and pumpkin gnaw")
	_check(Sab.pool(sab, 4).has(&"generator_kill") and not Sab.pool(sab, 3).has(&"generator_kill"), "generator kill from day 4")
	_check(not Sab.pool(sab, 9).has(&"scarecrow_moved"), "free kinds (scarecrow moved, budget false) never budgeted")
	_check(dist[0] == [1, 1, 1] and dist[2] == [2, 2, 2] and dist[4] == [2, 3, 3] and dist[6] == [3, 4, 4], "disturbance counts scale up by headcount")
	var tr: Dictionary = {}
	for rec: Dictionary in sab:
		if rec.id == "trample":
			tr = rec
	_check(Sab.trample_count(tr, 30.0, 0.0, false) == 1, "trample: 1 a night")
	_check(Sab.trample_count(tr, 29.9, 0.0, false) == 2, "trample: +1 if nobody spent 30 s outside")
	_check(Sab.trample_count(tr, 30.0, 0.0, true) == 2, "trample: +1 dead generator")
	_check(Sab.trample_count(tr, 30.0, 89.9, false) == 1, "unattended: under 30 + 60 s adds nothing")
	_check(Sab.trample_count(tr, 30.0, 90.0, false) == 2, "unattended: +1 per 60 s after the first 30")
	_check(Sab.trample_count(tr, 0.0, 600.0, true) == 6, "unattended capped at +3")
	_check(is_equal_approx(Sab.place_at(0, 2, 300.0, 0.3333), 24.9975) and Sab.place_at(1, 2, 300.0, 0.3333) < 100.0, "placed inside the first third")
	print("test_director_logic: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
