extends SceneTree
## P4-15: the clock ending the season shows the Season Awards on the host: a win card, then a loss card when the
## Debt says the final payment was missed; every player has an award line and a Back to menu button. One host.
## Q-130: a Harvest Moon wipe loses; a cart provider's cart_out gates the win.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/ui/test_season_awards.gd -- --host --phase1 --port=55621 --free-mouse

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
			print("test_season_awards: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var awards: CanvasLayer = null
	for c in main.get_children():
		if c.get_script() and c.get_script().get_global_name() == &"SeasonAwards":
			awards = c
	_check(awards != null, "Main has a SeasonAwards")
	var clock: Node = root.get_node("Clock")
	var debt: Node = main.get_tree().get_first_node_in_group(&"debt")
	var cart: Node = main.get_tree().get_first_node_in_group(&"cart")  # P4-12: the full farm's festival cart
	if cart == null:  # the gray-box farm has none: a stand-in provider
		var src := GDScript.new()
		src.source_code = "extends Node\nvar cart_out := false\n"
		src.reload()
		cart = Node.new()
		cart.set_script(src)
		cart.add_to_group(&"cart")
		main.add_child(cart)
	cart.cart_out = true  # Q-130: the win needs the cart out
	clock.end_season()
	_check(awards._open, "card opens when the season ends")
	var texts := _texts(awards._box)
	_check("SEASON'S END" in texts and "THE DEBT IS PAID" in texts, "win card: %s" % [texts])
	_check(texts.any(func(s: String) -> bool: return "Still Here" in s or "Trap Whisperer" in s or "Cash Crop" in s), "the local player has an award line")
	_check(awards._box.get_children().any(func(n: Node) -> bool: return n is Button), "Back to menu button")
	debt.lost = true
	clock.season_over = false
	clock.end_season()
	_check("THE BANK TOOK THE FARM" in _texts(awards._box), "loss card after a missed final payment")
	# Q-130: everyone dead on the Harvest Moon is a loss; with a cart provider (P4-12), cart_out gates the win
	debt.lost = false
	cart.cart_out = false  # a death after the cart is out is no wipe
	root.get_node("Log").event(&"death", {"player": main.multiplayer.get_unique_id(), "phase": "harvest_moon", "cause": "test", "position": [0.0, 0.0]})
	_check(awards._hm_wipe, "a Harvest Moon death of the last player alive is a wipe")
	_end(clock)
	_check("THE BANK TOOK THE FARM" in _texts(awards._box), "loss card after a Harvest Moon wipe")
	awards._hm_wipe = false
	_end(clock)
	_check("THE BANK TOOK THE FARM" in _texts(awards._box), "loss card while the cart is not out")
	cart.cart_out = true
	_end(clock)
	_check("THE DEBT IS PAID" in _texts(awards._box), "win card once the cart is out")
	print("test_season_awards: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(_fails)
	return true


func _end(clock: Node) -> void:
	clock.season_over = false
	clock.end_season()


func _texts(box: Node) -> Array:
	return box.get_children().filter(func(n: Node) -> bool: return n is Label and not n.is_queued_for_deletion()).map(func(n: Label) -> String: return n.text)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", what)
