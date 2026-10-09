extends SceneTree
## P4-18: two plant holds started on the last seed's coins. The host rechecks at completion
## (Interactable.recheck), so the second hold cancels `no_coins` and the bank never goes negative.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_seed_race.gd -- --host --port=52141 --free-mouse

var _t := 0.0
var _done := false
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Farm") == null:
		if _t > 30.0:
			print("test_seed_race: FAIL (no Farm after 30 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var Plot: GDScript = load("res://game/farming/plot.gd")
	var Crops: GDScript = load("res://game/farming/crops.gd")
	var game: Node = root.get_node("Game")
	var farm: Node = main.get_node("Farm")
	var reg: Node = farm.registry
	var empty: Array = farm.targets.values().filter(func(t: Node) -> bool:
		return t.get_script() == Plot and not t.locked and t.state == &"empty")
	_check(empty.size() >= 2, "two empty unlocked plots")
	if empty.size() < 2:
		quit(1)
		return false
	var seed := int(Crops.rec(Crops.default_seed()).seed)
	farm.coins = seed  # enough for one seed only
	if not game.players.has(-2):
		game.players[-2] = {}
	var a := {"verb": &"plant", "target": empty[0], "progress": 1.0, "hold_s": 1.0, "started": 0.0}
	var b := {"verb": &"plant", "target": empty[1], "progress": 1.0, "hold_s": 1.0, "started": 0.0}
	reg.holds[1] = a
	reg.holds[-2] = b
	reg._complete(1, a)
	_check(empty[0].state == &"growing" and farm.coins == 0, "first hold plants and spends the seed")
	reg._complete(-2, b)
	_check(not reg.holds.has(-2), "second hold ended")
	_check(empty[1].state == &"empty", "second plot stays empty")
	_check(farm.coins == 0, "bank never below 0 (was %d)" % farm.coins)
	print("test_seed_race: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("  FAIL ", what)
