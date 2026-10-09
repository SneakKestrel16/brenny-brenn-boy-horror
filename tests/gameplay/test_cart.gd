extends SceneTree
## P4-12: the festival cart (doc 03 s14): speed by pushers, loading, knock-offs and bites, the gate run, the cap
## rule (x > 78) and the short season's length. One host on the full farm, no client; the cart is ticked by hand.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_cart.gd -- --host --port=45412 --free-mouse

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
		if _t > 30.0:
			print("test_cart: FAIL (no Main after 30 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var C: GDScript = load("res://game/items/cart.gd")
	var data: Node = root.get_node("Data")
	var game: Node = root.get_node("Game")
	var clock: Node = root.get_node("Clock")
	var farm: Node = main.get_node("Farm")
	var me: int = game.local_peer()
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _log.append([String(n), d]))
	var pr: Dictionary = data.record(&"ai_director", &"profile_harvest_moon")
	_check([C.speed_for(0, pr), C.speed_for(1, pr), C.speed_for(2, pr), C.speed_for(3, pr), C.speed_for(4, pr), C.speed_for(6, pr)]
			== [0.0, 1.0, 1.6, 2.0, 2.4, 2.4], "cart speed by pushers (doc 02 s9)")
	var cart: Node = farm.cart
	_check(cart != null and cart.is_in_group(&"cart") and cart.length > 100.0, "the full farm has a cart in group cart")
	if cart == null:
		quit(1)
		return false
	var gate_out := [false]
	cart.left_gate.connect(func() -> void: gate_out[0] = true)
	var pk: Node = farm.targets["prize_pumpkin"]
	var st: Dictionary = farm.pstate(me)
	st.pos = pk._home.global_position
	pk.complete(&"plant", me, st)
	# act 1: the final dusk turns into the Harvest Moon
	clock.day = int(data.value(&"season", &"season_days"))
	clock.phase = &"harvest_moon"
	cart.on_phase(&"harvest_moon")
	_check(cart.act == C.LOADING and _last(&"cart_act").get("act") == 1, "act 1 loading")
	st.pos = cart.target_pos()
	_check(cart.can_start(&"push_cart", st) == &"not_loaded", "a planted pumpkin must be loaded first")
	_check(cart.can_start(&"load_cart", st) == &"not_holding", "loading needs the pumpkin in hand")
	st.pos = pk._home.global_position
	pk.complete(&"lift_prize", me, st)
	st.pos = cart.target_pos()
	_check(cart.can_start(&"load_cart", st) == &"", "load allowed while carrying")
	cart.complete(&"load_cart", me, st)
	_check(cart.loaded and pk.carrier == 0 and pk.on_cart() and cart.act == C.PUSH, "loaded: act 2")
	_check(farm.targets["generator"].gen.damaged, "act 2: the generator fails (doc 01 Harvest Moon)")
	# act 2: one pusher moves it 1.0 m/s
	farm.registry.request(me, &"push_cart", "cart")
	_check(farm.registry.holds.has(me), "push hold starts")
	cart._physics_process(0.0)  # the first tick reads the holds
	cart._physics_process(1.0)
	_check(cart.pushers == [me] and is_equal_approx(cart.offset, 1.0), "one pusher: 1.0 m in 1 s (got %.2f)" % cart.offset)
	# knock-off: stall, one bite per stall, cooldown
	_check(cart.knock_ready() and cart.knock(me), "knock the pusher off")
	_check(not farm.registry.holds.has(me) and cart.pushers.is_empty() and cart.stall_s == float(pr.knock_stall_s), "hold cancelled, stall set")
	_check(cart.bite() and not cart.bite() and pk.bites == 1, "one bite per stall")
	_check(not cart.knock_ready() and not cart.knock(me), "no knock in the stall")
	var off: float = cart.offset
	for i in int(pr.knock_stall_s) + 1:
		cart._physics_process(1.0)
	_check(cart.stall_s == 0.0 and cart.offset == off, "the cart stands through the stall")
	_check(not cart.knock_ready(), "cooldown still running at %d s" % (int(pr.knock_stall_s) + 1))
	for i in int(pr.knock_cooldown_s):
		cart._physics_process(1.0)
	_check(cart.knock_ready(), "cooldown over after knock_cooldown_s")
	# act 3: the final gate_run_m
	cart.offset = cart.length - float(pr.gate_run_m) - 0.5
	st.pos = cart.target_pos()
	farm.registry.request(me, &"push_cart", "cart")
	cart._physics_process(0.1)
	_check(cart.act == C.PUSH, "still act 2 before the last %d m" % int(pr.gate_run_m))
	cart._physics_process(1.0)
	_check(cart.act == C.GATE_RUN and _last(&"cart_act").get("act") == 3, "act 3 at the last %d m" % int(pr.gate_run_m))
	_check(not cart.knock_ready(), "no knock-offs in the gate run")
	cart.offset = cart.length - 0.1
	cart._physics_process(1.0)
	_check(cart.act == C.DONE and cart.cart_out and gate_out[0], "out the gate: cart_out, left_gate")
	_check(_last(&"cart_out").get("alive", 0) >= 1 and _last(&"cart_finished").get("reason") == "gate", "cart_out and cart_finished logged")
	_check(pk.judged and _last(&"pumpkin_judged").get("bites") == 1, "judged at the gate with its bite")
	_check(not farm.registry.holds.has(me), "the push hold ends with the cart")
	# the cap: out only past the fields (x > 78)
	var x78 := 0.0
	while cart.pos_at(x78).x <= C.OUT_X:
		x78 += 1.0
	for case in [[x78 - 5.0, false], [x78 + 1.0, true]]:
		cart.act = C.PUSH
		cart.cart_out = false
		cart.offset = case[0]
		cart._place()
		cart.settle()
		_check(cart.act == C.DONE and cart.cart_out == case[1], "cap at x %.1f: out %s" % [cart.body.global_position.x, case[1]])
	# short season (doc 02 s16): 3 days
	game.difficulty = &"short_season"
	_check(int(data.value(&"season", &"season_days")) == 3, "short season is 3 days")
	game.difficulty = &"normal"
	_check(int(data.value(&"season", &"season_days")) == 7, "normal season is 7 days")
	print("test_cart: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
	return false


func _last(n: String) -> Dictionary:
	for i in range(_log.size() - 1, -1, -1):
		if _log[i][0] == n:
			return _log[i][1]
	return {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
