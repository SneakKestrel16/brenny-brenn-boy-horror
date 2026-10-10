extends SceneTree
## P5-04 (doc 02 s21, doc 03 s22): trait overrides apply and clear, the seeded draw, savings, plot clamp, season debt.
## No scene; autoloads only.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_next_season.gd -- --host --phase1 --port=53701 --free-mouse

var _fails := 0


var _t := 0.0
var _done := false


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")  # autoloads and Campaign compile only once the game has loaded


func _process(delta: float) -> bool:
	_t += delta
	if _done or (current_scene == null or current_scene.get_node_or_null("Death") == null):
		if _t > 20.0 and not _done:
			print("test_next_season: FAIL (no Main)")
			quit(1)
		return false
	_done = true
	_run()
	return false


func _run() -> void:
	var data: Node = root.get_node("Data")
	var game: Node = root.get_node("Game")
	var Debt: GDScript = load("res://game/farming/debt.gd")
	var Camp: GDScript = load("res://game/core/campaign.gd")

	# overrides apply, then clear back to the files' numbers
	var walk0: float = data.value(&"creature", &"noise_step_walk", &"radius_m")
	var pit_d2: Variant = data.value(&"ramp_up", &"day_2", &"pit_4p")
	var pit_d7: Variant = data.value(&"ramp_up", &"day_7", &"pit_4p")
	var lock0: Variant = data.record(&"store", &"shed_lock").effect.broken_from_day
	data.apply_traits(["keen_ears", "more_pits", "lock_breaker", "tool_mimicry"])
	_check(is_equal_approx(data.value(&"creature", &"noise_step_walk", &"radius_m"), walk0 * 1.25), "keen_ears: noise x1.25")
	_check(data.value(&"ramp_up", &"day_2", &"pit_4p") == pit_d2 + 1, "more_pits: day 2 +1")
	_check(data.value(&"ramp_up", &"day_7", &"pit_4p") == pit_d7, "more_pits: day 7 (null) untouched")
	_check(int(data.record(&"store", &"shed_lock").effect.broken_from_day) == 3, "lock_breaker: dotted path set")
	_check(int(data.record(&"ai_director", &"lures").sound_no_tell_pct) == 80, "tool_mimicry: new field made")
	data.apply_traits([])
	_check(is_equal_approx(data.value(&"creature", &"noise_step_walk", &"radius_m"), walk0), "cleared: noise back")
	_check(data.value(&"ramp_up", &"day_2", &"pit_4p") == pit_d2, "cleared: pits back")
	_check(data.record(&"store", &"shed_lock").effect.broken_from_day == lock0, "cleared: lock back")
	_check(not data.record(&"ai_director", &"lures").has("sound_no_tell_pct"), "cleared: new field removed")

	# draw: repeatable, no repeats until every trait is gained
	var a: String = Camp.draw_trait(77, 2, [])
	_check(a != "" and a == Camp.draw_trait(77, 2, []), "same seed and season, same trait")
	var gained: Array = []
	var n: int = data.records(&"creature_traits").size()
	for s in n:
		var t: String = Camp.draw_trait(5, s + 2, gained)
		_check(t != "" and not gained.has(t), "draw %d is new" % s)
		gained.append(t)
	_check(Camp.draw_trait(5, 99, gained) == "", "none left after all %d" % n)

	# savings and plots (doc 02 s21.2)
	_check(Camp.savings(100) == 25 and Camp.savings(99) == 24 and Camp.savings(400) == 60 and Camp.savings(-5) == 0, "savings 25%, floor, cap 60")
	_check(Camp.clamp_plots([1, 2, 3, 4], 6, 8) == [1, 2] and Camp.clamp_plots([1, 2], 8, 8).is_empty(), "plots clamp to the ceiling")

	# season debt (doc 02 s21.4)
	game.season_no = 2
	var pct: int = Debt.pct_for(4)
	_check(Camp.debt_base(2, 4) == 1595 and Camp.debt_base(2, 2) == 1335, "season 2 bases 1595 / 1335")
	var total: int = Debt.total_for([pct, pct, pct, pct, pct, pct, pct], pct, 4)
	_check(total == Debt.rhu(1595 * pct * 7, 700), "season 2 total at 4p (%d)" % total)
	_check(Debt.first_of(total, 4) == Debt.rhu(255 * total, 1595), "season 2 first payment scales from 255")
	game.season_no = 1
	_check(Camp.debt_base(1, 4) == 0, "season 1 uses debt.json")

	print("test_next_season: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL", what)
