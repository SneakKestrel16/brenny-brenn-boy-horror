extends SceneTree
## Doc 05 section 7 unit checks for the hold rate maths (P1-05).
##   "$GODOT" --headless --path . -s res://tests/gameplay/test_hold_math.gd

const HoldMath := preload("res://game/interaction/hold_math.gd")

var _fails := 0


func _init() -> void:
	_check(is_equal_approx(HoldMath.rate([]), 1.0), "no multipliers: rate 1")
	_check(is_equal_approx(HoldMath.rate([0.6]), 1.0 / 0.6), "x0.6 multiplier: rate 1/0.6")
	_check(is_equal_approx(HoldMath.rate([0.6, 1.5]), 1.0 / 0.9), "multipliers multiply")
	# 3 s hold at rate 1 in 60 Hz ticks finishes at 3 s
	var p := 0.0
	var ticks := 0
	while p < 1.0:
		p = HoldMath.advance(p, 1.0 / 60.0, 1.0, 3.0)
		ticks += 1
	_check(absi(ticks - 180) <= 1, "3 s hold takes 180 ticks at 60 Hz, +-1 for float sums (got %d)" % ticks)
	# mid-hold change: half done at rate 1, then x0.5 multiplier (rate 2) finishes in 0.75 s of a 3 s hold
	p = HoldMath.advance(0.0, 1.5, 1.0, 3.0)
	_check(is_equal_approx(p, 0.5), "half done after 1.5 s")
	p = HoldMath.advance(p, 0.75, HoldMath.rate([0.5]), 3.0)
	_check(is_equal_approx(p, 1.0), "rate change mid-hold finishes at 1.0 without restarting")
	_check(HoldMath.advance(0.9, 10.0, 1.0, 3.0) == 1.0, "progress clamps at 1")
	print("test_hold_math: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
