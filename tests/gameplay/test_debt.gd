extends SceneTree
## P4-07 (doc 02 s7): debt by headcount, the payment dawns, early payment, Foreclosure. One host, no client.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_debt.gd -- --host --phase1 --port=45398 --free-mouse

var _t := 0.0
var _done := false
var _fails := 0
var _log: Array = []


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null:
		if _t > 20.0:
			print("test_debt: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var Debt: GDScript = load("res://game/farming/debt.gd")
	var Crops: GDScript = load("res://game/farming/crops.gd")
	var farm: Node = main.get_node("Farm")
	var death: Node = main.get_node("Death")
	var d: Node = death.debt
	var clock: Node = root.get_node("Clock")
	var me: int = root.get_node("Game").local_peer()
	root.get_node("Log").logged.connect(func(n: StringName, data: Dictionary) -> void: _log.append([String(n), data]))

	# doc 01 table with D-079 scaling (59/85/101): total / first / final
	for row: Array in [[4, 1313, 258, 1055], [3, 1105, 217, 888], [2, 767, 150, 617]]:
		var pct: int = Debt.pct_for(row[0])
		var total: int = Debt.total_for([pct, pct, pct, pct, pct, pct, pct], pct, row[0])
		_check(total == row[1] and Debt.first_of(total) == row[2] and total - Debt.first_of(total) == row[3],
				"%dp: %d / %d / %d (got %d / %d)" % [row[0], row[1], row[2], row[3], total, Debt.first_of(total)])
	# past days keep their recorded pct, future days follow the current one (doc 01 "Debt formula")
	_check(Debt.total_for([101], 85, 3) == Debt.rhu(1300 * (101 + 6 * 85), 700), "one dawn recorded, six at the current pct")
	_check(Debt.penalty_for(101) == 152 and Debt.penalty_for(100) == 150, "penalty is ceil(1.5 x shortfall)")

	var pumpkin := &""
	for id: StringName in Crops.ids():
		if String(Crops.rec(id).unlock_rule) == "first_payment_made":
			pumpkin = id
	var unlock_day := int(Crops.rec(pumpkin).unlock_day)
	var pct1: int = Debt.pct_for(root.get_node("Game").player_count())

	# 1. first payment made at dawn 4
	_reset(farm, d)
	farm.coins = 1000
	clock.day = 3
	_log.clear()
	death.dawn()
	var due1: int = Debt.first_of(Debt.total_for([pct1, pct1], pct1, root.get_node("Game").player_count()))
	_check(Debt.first_made and Crops.is_unlocked(pumpkin, unlock_day), "first payment made: pumpkins on sale")
	_check(d.paid == due1 and farm.coins == 1000 - due1, "dawn 4 took the first payment (%d, paid %d)" % [due1, d.paid])
	_check(not _find("payment_made").is_empty() and not _find("payment_made")[0].late, "payment_made logged on time")

	# 2. early payment fills the first payment first, then dawn 4 takes the rest
	_reset(farm, d)
	farm.coins = 1000
	clock.day = 1
	var n: int = d.pay_early(me)
	_check(n == d.EARLY_STEP and d.paid == n and farm.coins == 1000 - n, "early payment of %d" % n)
	_check(not Debt.first_made, "an early payment alone does not unlock pumpkins before the first-payment dawn")
	clock.day = 3
	death.dawn()
	_check(d.paid == due1 and farm.coins == 1000 - due1 and Debt.first_made, "dawn 4 takes only what early payments left")
	farm.coins = 4
	_check(d.early_blocked() == &"no_coins", "early payment never takes the 4-coin floor")

	# 3. missed first payment: partial payment to the floor, penalty, a seizure, pumpkins stay locked
	_reset(farm, d)
	farm.coins = 10
	clock.day = 3
	_log.clear()
	death.dawn()
	var short: int = due1 - 6
	_check(d.foreclosed and not Debt.first_made and d.paid == 6 and farm.coins == 4, "partial payment down to the floor")
	_check(d.penalty == Debt.penalty_for(short), "penalty %d on shortfall %d" % [d.penalty, short])
	_check(not Crops.is_unlocked(pumpkin, unlock_day), "pumpkins stay locked after a missed first payment")
	_check(not _find("foreclosure").is_empty(), "foreclosure logged")
	var locked := 0
	for t in farm.targets.values():
		if t is Node and t.get("locked") == true:
			locked += 1
	_check(locked >= 2, "the bank seized plots (%d locked)" % locked)
	_check(not _find("payment_made").is_empty() and _find("payment_made")[0].late, "payment_made logged late")

	# 4. final dawn: the penalty and deferred bills are added; short is a lost season
	var total7: int = Debt.total_for([pct1, pct1, pct1, pct1, pct1, pct1, pct1], pct1, root.get_node("Game").player_count())
	clock.day = 7
	farm.final_extra = 11
	farm.coins = total7 - d.paid + d.penalty + 11 - 1
	_log.clear()
	death.dawn()
	_check(d.lost and not _find("season_lost").is_empty(), "one coin short at the final dawn loses the season")
	_reset(farm, d)
	farm.final_extra = 0
	farm.coins = total7 + 5
	d.first_due = 0
	death.dawn()
	_check(not d.lost and farm.coins == 5 and d.paid == total7, "final payment made: %d" % total7)

	print("test_debt: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)
	return false


func _reset(farm: Node, d: Node) -> void:
	d.paid = 0
	d.penalty = 0
	d.foreclosed = false
	d.lost = false
	load("res://game/farming/debt.gd").first_made = false
	farm.final_extra = 0
	for t in farm.targets.values():
		if t.get("locked") == true:
			t.locked = false
	d._pcts.clear()
	d._pcts.append(d.pct_for(root.get_node("Game").player_count()))


func _find(name: String) -> Array:
	return _log.filter(func(e: Array) -> bool: return e[0] == name).map(func(e: Array) -> Dictionary: return e[1])


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL", what)
