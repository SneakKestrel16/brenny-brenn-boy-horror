extends SceneTree
## Doc 05 section 21 unit checks for Data (P1-02).
##   "$GODOT" --headless --path . -s res://tests/gameplay/test_data.gd
## Exits 0 on pass, 1 on any failure.

const DataScript := preload("res://game/core/data.gd")

var _fails := 0


func _init() -> void:
	var d: Node = DataScript.new()

	# Duplicate ids are rejected.
	d.load_text(&"crops", '{"table":"crops","schema_version":1,"records":[{"id":"a","source":"doc01"},{"id":"a","source":"doc01"}]}')
	_check(d.errors.size() == 1 and "duplicate" in d.errors[0], "duplicate id rejected")
	# Envelope: wrong table, wrong version, bad source.
	d.errors.clear()
	d.load_text(&"crops", '{"table":"x","schema_version":2,"records":[{"id":"a","source":"guess"}]}')
	_check(d.errors.size() == 3, "wrong table, version and source each reported (%d)" % d.errors.size())

	# Real files load with no errors, with and without --phase1.
	_check(d.load_dir("res://data"), "data/ loads: %s" % [d.errors])
	_check(d.load_dir("res://data", true), "data/ + phase1 loads: %s" % [d.errors])
	_check(is_equal_approx(d.hold_s(&"plant"), 3.0), "hold_s(plant) is 3")
	_check(is_equal_approx(d.speed(&"sprint"), 5.0), "speed(sprint) is 5")
	_check(d.value(&"crops", &"turnip", &"sell") == 10, "turnip sells for 10")
	_check(not d.load_dir("res://no_such_dir"), "missing required files fail loudly")

	# Data.scaled: ceil(v * pct / 100) in integer math; debt rounds to nearest (doc 02 section 4, D-017).
	_check(d.scale_pct(250, 80) == 200 and d.scale_pct(250, 60) == 150, "250 at 80% and 60%")
	_check(d.scale_pct(4, 80) == 4 and d.scale_pct(2, 60) == 2, "ceil(3.2) = 4, ceil(1.2) = 2 (doc 02 section 4)")
	_check(d.scale_pct(3, 60) == 2 and d.scale_pct(3, 60, true) == 2, "3 at 60% is 1.8")
	_check(d.scale_pct(5, 60) == 3 and d.scale_pct(1, 60, true) == 1 and d.scale_pct(1, 40, true) == 0, "nearest rounding for debt")
	var agree := true
	for n in range(0, 2001):  # doc 02 section 4: integer form agrees with float ceil up to 2,000
		agree = agree and d.scale_pct(n, 60) == int(ceil(n * 0.6)) and d.scale_pct(n, 80) == int(ceil(n * 0.8))
	_check(agree, "integer scale_pct equals float ceil for n up to 2000")

	d.free()
	print("test_data: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
