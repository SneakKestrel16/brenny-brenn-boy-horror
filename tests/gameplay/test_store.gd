extends SceneTree
## P4-06: every store.json row is bought at its price and gate, and each item does its job. One host, no client.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_store.gd -- --host --phase1 --port=45399 --free-mouse

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
			print("test_store: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var farm: Node = main.get_node("Farm")
	var store: Node = farm.store
	var death: Node = main.get_node("Death")
	var me: int = root.get_node("Game").local_peer()
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _log.append([String(n), d]))
	var st: Dictionary = farm.pstate(me)
	var crate := main.get_tree().get_first_node_in_group(&"store_crate") as Node3D
	_check(crate != null, "the shipping crate exists")

	# gate and range
	farm.coins = 1000
	st.pos = crate.global_position + Vector3(30, 0, 0)
	_check(store.buy(me, &"scrap") == &"too_far", "far from the crate: refused too_far")
	st.pos = crate.global_position + Vector3(1, 0, 0)
	farm.coins = 5
	_check(store.buy(me, &"scrap") == &"no_coins", "5 coins: scrap (15) refused no_coins")
	_check(store.buy(me, &"turnip_seed") == &"no_item", "the crate does not sell seeds or crops")
	farm.coins = 1000

	# every row at its price
	for r: Dictionary in root.get_node("Data").records(&"store"):
		var id := StringName(r.id)
		var before: int = farm.coins
		var open_before: int = store.open_plots()
		var why: StringName = store.buy(me, id)
		_check(why == &"", "%s buys (%s)" % [id, why])
		_check(before - farm.coins == int(r.price), "%s costs %d (took %d)" % [id, int(r.price), before - farm.coins])
		if id == &"plot_pair":
			_check(store.open_plots() - open_before == 2, "plot_pair opens 2 plots")
	var buys := _log.filter(func(e: Array) -> bool: return e[0] == "store_buy")
	_check(buys.size() == root.get_node("Data").records(&"store").size(), "one store_buy logged per purchase")
	_check(buys[0][1].has("item") and buys[0][1].has("price") and buys[0][1].has("buyer"), "store_buy has item, price and buyer")

	# per-item effects
	_check(store.owns(me, &"quiet_watering_can") and not store.owns(me + 1, &"quiet_watering_can"), "quiet can is the buyer's only")
	_check(store.buy(me, &"quiet_watering_can") == &"owned", "second quiet can refused")
	_check(is_equal_approx(store.lantern_mult(me), 1.5) and is_equal_approx(store.lantern_mult(me + 1), 1.0), "brighter lantern x1.5 for the buyer")
	_check(store.buy(me, &"shed_lock") == &"owned", "shed lock bought once")
	_check(main.get_tree().get_first_node_in_group(&"creature").shed_lock, "the creature sees the pegboard lock")
	store.buy(me, &"scarecrow")
	store.buy(me, &"scarecrow")
	_check(store.buy(me, &"scarecrow") == &"max_bought", "scarecrow stops at max_bought 3")
	_check(store.place_scarecrow(me) == &"", "scarecrow placed")
	_check(store.place_scarecrow(me) == &"too_close", "a second at the same spot refused")
	st.pos += Vector3(10, 0, 0)
	_check(store.place_scarecrow(me) == &"", "another placed 10 m on")
	_check(main.get_tree().get_nodes_in_group(&"bought_scarecrow").size() == 2, "two scarecrow nodes stand")
	var ceiling: int = farm.plot_ceiling()
	while store.buy(me, &"plot_pair") == &"":
		pass
	_check(store.open_plots() <= ceiling, "plot_pair never passes the ceiling %d (open %d)" % [ceiling, store.open_plots()])
	_check(store.seizable().has(&"plot_pair") and store.seizable().has(&"flare_gun") and not store.seizable().has(&"scrap"), "upgrades are seizable, scrap is not")

	# scrap: free first, then paid
	farm.free_scrap = 1
	var total: int = store.scrap_total()
	_check(store.take_scrap() and farm.free_scrap == 0 and store.scrap_total() == total - 1, "free scrap is spent first")
	farm.free_scrap = 0
	store.scrap_bought = 0
	_check(not store.take_scrap(), "no scrap left: take_scrap false")
	death.step_free_scrap(farm, false)
	death.step_free_scrap(farm, false)
	_check(farm.free_scrap == 1, "the free scrap does not stack")

	# flare gun
	var cr: Node = main.get_tree().get_first_node_in_group(&"creature")
	cr.global_position = st.pos + Vector3(20, 0, 0)
	root.get_node("Clock").phase = &"night"
	cr._night_t = 0.0
	_check(store.flare_shots == 1, "one flare shot loaded")
	_check(store.fire_flare(me) == &"", "flare fires")
	_check(cr.state == &"retreat", "a flare hit puts the creature in Retreat (%s)" % cr.state)
	_check(is_equal_approx(cr._flare_retreat_s, 30.0), "for 30 s")
	_check(store.fire_flare(me) == &"flare_empty", "one shot only")
	store.refill_flare()
	_check(store.flare_shots == 1, "dawn refills the shot")
	_check(_log.any(func(e: Array) -> bool: return e[0] == "flare_fired"), "flare_fired logged")

	# P4-09 roles: the Carpenter builds cheaper, the Warden gets a shot more and reloads in half the time
	var players: Dictionary = root.get_node("Game").players
	players[me].role = &"carpenter"
	_check(store.price(me, &"scarecrow") == 16 and store.price(me, &"flare_gun") == 50, "Carpenter: scarecrow 20 x0.8 = 16, other items full price")
	players[me].role = &"warden"
	store.refill_flare()
	_check(store.flare_shots == 2, "a Warden on the team: the gun holds 2 shots")
	cr.global_position = st.pos + Vector3(200, 0, 0)
	store._flare_ready_ms = 0  # the first shot's 8 s reload is not over yet
	_check(store.fire_flare(me) == &"" and store.fire_flare(me) == &"flare_reloading", "second shot waits for the reload")
	var wait: int = store._flare_ready_ms - Time.get_ticks_msec()
	_check(wait > 3000 and wait <= 4000, "Warden reload 8 s x0.5 = 4 s (%d ms)" % wait)
	players[me].role = &""
	print("test_store: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL ", what)
