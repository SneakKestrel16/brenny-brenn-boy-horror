extends SceneTree
## P5-11 (Gameplay): the imposter's pure rules. Run:
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_imposter.gd
## Checks the data row (doc 01 / D-155 / D-161), the roll (off by default, 4 player minimum, 50%), the
## season-end line, and that the win needs the final payment missed (Debt.lost) and nothing else.

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("test_imposter: FAIL ", what)


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)  # the autoloads exist by then


func _run() -> void:
	var I: GDScript = load("res://game/core/imposter.gd")
	var rule: Dictionary = root.get_node("Data").record(&"imposter", &"rule")
	_check(rule.get("chance_pct") == 50 and rule.get("max_imposters") == 1 and rule.get("min_players") == 4, "rule row: 50 percent, one, min 4")
	_check(rule.get("wins_when") == "final_payment_missed" and rule.get("kills") == false and rule.get("keeps_role") == true, "rule row: final payment only, never kills, keeps role")
	_check(I.enabled == false, "default off (D-158)")
	_check(I.rolls(false, 4, 0.0, 50.0, 4) == false, "toggle off never rolls")
	_check(I.rolls(true, 3, 0.0, 50.0, 4) == false, "below 4 players never rolls (D-161)")
	_check(I.rolls(true, 4, 0.49, 50.0, 4) and not I.rolls(true, 4, 0.5, 50.0, 4), "50 percent edge")
	var hits := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 2000:
		hits += 1 if I.rolls(true, 4, rng.randf(), 50.0, 4) else 0
	_check(hits > 900 and hits < 1100, "about half of 2000 rolls hit (%d)" % hits)
	_check(I.line("", false) == "There was no imposter.", "no imposter line")
	_check(I.line("Ann", true).contains("IMPOSTER WAS Ann") and I.line("Ann", true).contains("imposter won"), "win line")
	_check(I.line("Ann", false).contains("imposter lost"), "loss line")
	_check(I.KINDS.has(&"pegboard_mark") and I.KINDS.has(&"whistle_throw") and I.KINDS.has(&"gate_prop"), "kit kinds (P5-25)")
	_check(is_equal_approx(I.hold_s(&"pegboard_mark"), 3.0) and is_equal_approx(I.hold_s(&"gate_prop"), 2.0), "kit hold seconds from imposter.json")
	_check(I.hold_s(&"whistle_throw") > 0.0, "the whistle has a hold time")
	_check(I.won() == false, "no imposter, no win")
	I.uid = "x"  # a host-only value set directly: with no Debt in the tree the imposter has not won
	_check(I.won() == false, "no Debt node, no win")
	var debt := Node.new()
	debt.set_script(load("res://game/farming/debt.gd"))
	debt.add_to_group(&"debt")
	root.add_child(debt)
	_check(I.won() == false, "a kept farm is not an imposter win")
	debt.lost = true
	_check(I.won() == true, "final payment missed is the win (D-155)")
	I.picked = true
	I.enabled = true
	I.picked_name = "Ann"
	_check(I.reveal_line().contains("Ann"), "reveal names the imposter")
	I.enabled = false
	_check(I.reveal_line() == "", "toggle off and nothing forced: nothing to reveal")
	I.reset()
	_check(I.uid == "" and not I.me and not I.picked, "reset clears everything")
	print("test_imposter: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
