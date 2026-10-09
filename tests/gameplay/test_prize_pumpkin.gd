extends SceneTree
## P4-05: Prize Pumpkin sizes, payouts, guarding, gnaw log, carrying and judging. One host, no client.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_prize_pumpkin.gd -- --host --phase1 --port=45398 --free-mouse

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
			print("test_prize_pumpkin: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var P: GDScript = load("res://game/farming/prize_pumpkin.gd")
	var farm: Node = main.get_node("Farm")
	var clock: Node = root.get_node("Clock")
	var me: int = root.get_node("Game").local_peer()
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _log.append([String(n), d]))
	var pk: Node = farm.targets.get("prize_pumpkin")
	_check(pk != null, "pumpkin_patch has a pumpkin target")
	# size table (doc 02 s6): ranks and payouts at 4p
	_check(P.rank_of(7, 2, 0) == 3 and P.rank_of(7, 1, 0) == 2, "giant needs 7 watered and 2 guarded")
	_check(P.rank_of(5, 0, 0) == 2 and P.rank_of(4, 0, 0) == 1 and P.rank_of(3, 0, 0) == 1 and P.rank_of(2, 0, 0) == 0, "large 5+, medium 3-4, sad 0-2")
	_check(P.rank_of(7, 2, 5) == 0 and P.rank_of(7, 2, 1) == 2, "drops lower the size, sad is the floor")
	_check([P.payout_for(3, 4), P.payout_for(2, 4), P.payout_for(1, 4), P.payout_for(0, 4)] == [250, 150, 75, 20], "4p payouts")
	_check([P.payout_for(3, 3), P.payout_for(3, 2), P.payout_for(0, 2)] == [200, 150, 12], "3p and 2p payouts")
	# plant, water, carry
	var st: Dictionary = farm.pstate(me)
	st.pos = pk._home.global_position
	_check(pk.can_start(&"plant", st) == &"", "plant allowed")
	pk.complete(&"plant", me, st)
	_check(pk.planted and pk.can_start(&"plant", st) == &"not_empty", "planted once")
	st.held_kind = &"water"
	st.can = 5
	for d in 7:
		st.can = 5
		_check(pk.can_start(&"water_prize_pumpkin", st) == &"", "water day %d" % (d + 1))
		pk.complete(&"water_prize_pumpkin", me, st)
		_check(pk.can_start(&"water_prize_pumpkin", st) == &"already_watered", "once a day")
		pk.watered = false  # next day
	_check(pk.size_name() == &"large", "7 watered, 0 guarded is large (got %s)" % pk.size_name())
	_check(pk.can_start(&"lift_prize", st) == &"", "lift")
	pk.complete(&"lift_prize", me, st)
	_check(pk.carrier == me and pk.can_start(&"set_down_prize", st) == &"", "carried by me, can set down")
	st.pos = Vector3(10, 0, 10)
	pk.complete(&"set_down_prize", me, st)
	_check(pk.carrier == 0 and pk._home.global_position.is_equal_approx(Vector3(10, 0, 10)), "set down where I stand")
	# guarding: 60 s of a living player near on night 1 counts; far or a ghost does not
	clock.day = 1
	pk._on_phase(&"night")
	clock.phase = &"night"
	st.pos = pk._home.global_position + Vector3(5, 0, 0)
	for i in 61:
		pk._physics_process(1.0)
	pk._on_phase(&"dawn")
	_check(pk.guarded_nights == 1, "one guarded night (got %d)" % pk.guarded_nights)
	clock.day = 2
	pk._on_phase(&"night")
	st.pos = pk._home.global_position + Vector3(25, 0, 0)
	for i in 61:
		pk._physics_process(1.0)
	pk.end_night()
	_check(pk.guarded_nights == 1, "25 m away does not guard")
	pk.guarded_nights = 2
	_check(pk.size_name() == &"giant", "giant with 7 watered and 2 guarded")
	# gnaw: not before night 3, then a size lost and the guarding time logged (D-083)
	_check(not pk.gnaw(), "no gnaw on day 2")
	clock.day = 3
	_check(pk.gnaw() and pk.size_name() == &"large", "gnaw drops one size")
	_check(not pk.gnaw(), "one gnaw per night")
	_check(root.get_node("Game").player_left.is_connected(pk._set_down), "a leaving carrier sets it down")
	var g := _last(&"pumpkin_gnaw")
	_check(g.has("guard_max_s") and g.has("guard_total_s") and g.has("repair_s"), "pumpkin_gnaw logs guard and repair time")
	_check(pk.bite() and pk.bite() and not pk.bite(), "two escort bites at most")
	_check(pk.size_name() == &"sad", "sad floor")
	# judging
	farm.coins = 0
	var r: Dictionary = pk.judge(farm)
	_check(r.size == &"sad" and r.payout == Data_scaled(20), "judged sad pays 20 at this headcount (got %s)" % str(r))
	_check(_last(&"pumpkin_judged").get("payout", -1) == r.payout, "pumpkin_judged logged")
	_check(pk.judge(farm).is_empty(), "judged once")
	print("test_prize_pumpkin: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
	return false


func Data_scaled(v: int) -> int:
	return root.get_node("Data").scaled(v, &"pumpkin")


func _last(n: String) -> Dictionary:
	for i in range(_log.size() - 1, -1, -1):
		if _log[i][0] == n:
			return _log[i][1]
	return {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
