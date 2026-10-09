extends SceneTree
## P4-15 unit checks for the Season Awards rules (doc 01 "Season Awards", doc 03 section 17.4), on the shipped templates.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/ui/test_season_awards_logic.gd

const Logic := preload("res://game/ui/season_awards_logic.gd")

var _fails := 0


func _init() -> void:
	var data: Node = preload("res://game/core/data.gd").new()
	data.load_dir("res://data")
	var tpl := {}
	for r in data.records(&"dawn_report_templates"):
		tpl[String(r.id)] = r.text
	data.free()
	var t := Logic.empty_tally()
	var ev: Array = [
		["trap_changed", {"state": "disarmed", "by": 1}], ["trap_changed", {"state": "filled", "by": 1}],
		["trap_changed", {"state": "set", "by": "creature"}], ["trap_changed", {"state": "disarmed", "by": 2}],
		["lure_fooled", {"target": 2}],
		["money_changed", {"reason": "start_coins", "delta": 100, "player": null}],
		["money_changed", {"reason": "sell", "delta": 30, "player": 2}], ["money_changed", {"reason": "dawn_cash_in", "delta": 20, "player": 1}],
		["money_changed", {"reason": "seed", "delta": -5, "player": 1}],
		["inside_at_night", {"player": 1, "seconds": 40.4}], ["inside_at_night", {"player": 2, "seconds": 90.0}],
	]
	for e: Array in ev:
		Logic.tally(t, e[0], e[1])
	var ctx := {"names": {1: "Ann", 2: "Ben", 3: "Cy"}, "players": [1, 2, 3], "day": 7}
	var r := Logic.build(t, ctx, tpl, false)
	var by := {}
	for a: Dictionary in r.awards:
		by[a.id] = a
	_check(by.award_traps_disarmed.line == "Ann: Trap Whisperer. Disarmed 2 traps this season.", "disarmed: %s" % by.award_traps_disarmed.line)
	_check(by.award_fooled_by_voice.player == 2, "fooled")
	_check(by.award_most_coins.player == 2 and "30" in by.award_most_coins.line, "coins: sales count, seeds and start coins do not")
	_check(by.award_barn_goblin.player == 2, "barn goblin: most inside seconds")
	_check(by.award_participation.player == 3 and r.awards.size() == 5, "a player with none gets Still Here")
	_check(not r.lost and Logic.build(t, ctx, tpl, true).lost, "lost flag")
	r = Logic.build(Logic.empty_tally(), ctx, tpl, false)
	_check(r.awards.size() == 3 and r.awards.all(func(a: Dictionary) -> bool: return a.id == "award_participation"), "quiet season: everyone gets one")
	print("test_season_awards_logic: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", what)
