extends SceneTree
## P4-14: walkie battery, holding and static on the host (doc 06 s10, doc 08 s7.2). One host, no client;
## the two-machine radio path is the multi.py run in production/handoffs/P4-14.md.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/net/test_walkie.gd -- --host --phase1 --port=50231 --free-mouse

var _t := 0.0
var _done := false
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null:
		if _t > 20.0:
			print("test_walkie: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var game: Node = root.get_node("Game")
	var store: Node = main.get_node("Farm").store
	var walkie: Node = root.get_node("Voice").walkie
	var me: int = game.local_peer()
	var full := float(root.get_node("Data").record(&"store", &"walkie_battery").effect.transmit_s)
	_check(is_equal_approx(full, 180.0), "a battery is 180 s of transmitting (%s)" % full)

	_check(not walkie.transmit(me), "no walkie: the radio flag is refused")
	store.farm.coins = 1000
	_check(store.buy(me, &"walkie_talkie", false) == &"", "walkie bought")
	_check(walkie.holds(me), "the buyer holds it")
	_check(walkie.transmit(me), "a held walkie transmits")
	_check(is_equal_approx(walkie.battery[me], full - 0.02), "its included battery went in and drains 20 ms a frame (%s)" % walkie.battery[me])
	_check(int(store.team.get(&"walkie_battery", 0)) == 0, "the included battery left the spare pool")

	walkie.battery[me] = 0.03
	_check(walkie.transmit(me) and walkie.transmit(me), "the last frames go out")
	_check(not walkie.transmit(me), "battery flat, no spare: refused")
	_check(store.buy(me, &"walkie_battery", false) == &"", "spare battery bought")
	_check(walkie.transmit(me) and is_equal_approx(walkie.battery[me], full - 0.02), "the spare loads on the next frame")

	game.players[me]["ghost"] = true
	_check(not walkie.holds(me) and not walkie.transmit(me), "a ghost holds no walkie")
	game.players[me]["ghost"] = false

	var role: Variant = game.players[me].get("role")
	game.players[me]["role"] = &"radio_operator"
	_check(is_equal_approx(walkie.full_s(me), 270.0), "Radio Operator battery 270 s (%s)" % walkie.full_s(me))
	game.players[me]["role"] = role if role != null else &""

	walkie.apply(me, true, 5)
	_check(walkie.powered(me), "apply: powered with charge")
	walkie.apply(me, true, 0)
	_check(not walkie.powered(me), "apply: flat is not powered")

	_check(is_equal_approx(walkie.static_db(40.0), -20.0), "static -20 dB beyond 30 m")
	_check(is_equal_approx(walkie.static_db(5.0), -6.0), "static -6 dB at 5 m")
	_check(is_equal_approx(walkie.static_db(17.5), -13.0), "static halfway in dB at 17.5 m")
	_check(is_equal_approx(walkie.static_db(INF), -20.0), "no creature: base static")

	print("test_walkie: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
