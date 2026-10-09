extends SceneTree
## P4-11 unit checks: dawn trample placement (doc 03 section 10), difficulty multipliers on the shipped
## difficulty.json (doc 02 section 16). The per-body jumpscare id (D-081) needs autoloads, so not here.
##   "$GODOT" --headless --path . -s res://tests/creature/test_p4_11.gd

const Sab := preload("res://game/ai_director/sabotage_logic.gd")

var _fails := 0


func _init() -> void:
	var data: Node = preload("res://game/core/data.gd").new()
	data.load_dir("res://data")
	var diff := {}
	for rec in data.records(&"difficulty"):
		diff[String(rec.id)] = rec
	data.free()
	# trample_pick: crops first, no repeats, bare plots fill the shortfall
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var plots := [{"d": 5.0, "crop": true}, {"d": 50.0, "crop": false}, {"d": 10.0, "crop": true}, {"d": 1.0, "crop": false}]
	var two := Sab.trample_pick(plots, 2, 20.0, rng.randf)
	_check(two.size() == 2 and 0 in two and 2 in two, "two wanted: both crops, no bare plot (got %s)" % str(two))
	var all := Sab.trample_pick(plots, 9, 20.0, rng.randf)
	_check(all.size() == 4 and all.slice(0, 2).all(func(i: int) -> bool: return plots[i].crop), "want past the plots: each once, crops first (got %s)" % str(all))
	_check(Sab.trample_pick(plots, 0, 20.0, rng.randf).is_empty(), "want 0 picks none")
	# weighting: 1 / (1 + d / 20); near (d 0) weight 1, far (d 60) weight 0.25, so near wins 80%
	var pair := [{"d": 0.0, "crop": true}, {"d": 60.0, "crop": true}]
	var near := 0
	for i in 2000:
		near += 1 if Sab.trample_pick(pair, 1, 20.0, rng.randf)[0] == 0 else 0
	_check(near > 1500 and near < 1700, "nearer plot picked about 80%% (got %d / 2000)" % near)
	# a repeat (same crop trampled before) halves: equal distance, repeat weight 0.5, so 1 : 0.5
	var rep := [{"d": 10.0, "crop": true}, {"d": 10.0, "crop": true, "repeat": true}]
	var fresh := 0
	for i in 2000:
		fresh += 1 if Sab.trample_pick(rep, 1, 20.0, rng.randf)[0] == 0 else 0
	_check(fresh > 1250 and fresh < 1420, "repeat plot halved, fresh about 67%% (got %d / 2000)" % fresh)
	# difficulty: applied after headcount scaling, rounded up (doc 02 s16)
	_check(_scale(4, diff.easy.trap_pct) == 3, "easy traps 4 -> 3")
	_check(_scale(3, diff.easy.trap_pct) == 3, "easy traps 3 -> 3 (2.25 rounds up)")
	_check(_scale(25, diff.easy.bill_pct) == 13, "easy bill 25 -> 13")
	_check(_scale(210, diff.nightmare.generator_tank_pct) == 158, "nightmare tank 210 -> 158")
	_check(_scale(4, diff.normal.trap_pct) == 4 and _scale(4, diff.nightmare.trap_pct) == 4, "normal and nightmare traps unchanged")
	print("test_p4_11: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _scale(v: int, pct: Variant) -> int:
	return preload("res://game/core/data.gd").scale_pct(v, int(pct))


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
