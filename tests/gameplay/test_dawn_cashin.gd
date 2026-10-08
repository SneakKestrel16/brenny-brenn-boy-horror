extends SceneTree
## QA P2-06: dawn cash-in with a full bag (doc 02 s9 step 1) and the dead losing their bag, one host, no client.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_dawn_cashin.gd -- --host --phase1 --port=45399 --free-mouse
## Gives the host a bag of 6 turnips (10 coins each, crops.json), adds a second player record with a bag of 4
## that is dead, runs dawn, and checks: living bag sold as `dawn_cash_in`, dead bag lost, bag zeroed.

var _t := 0.0
var _stage := 0
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null:
		if _t > 20.0:
			print("test_dawn_cashin: FAIL (no Main after 20 s)")
			quit(1)
		return false
	var farm: Node = main.get_node("Farm")
	var death: Node = main.get_node("Death")
	if _stage == 0:
		_stage = 1
		var Game: Node = root.get_node("Game")
		var me: int = Game.local_peer()
		var st: Dictionary = farm.pstate(me)
		st.bag = 6
		var before: int = farm.coins
		death.dawn()
		_check(int(farm.pstate(me).bag) == 0, "bag emptied")
		_check(farm.coins - before == 60, "6 turnips sold for 60 coins (got %d)" % (farm.coins - before))
		# a dead player with a bag: the bag is lost, not sold
		Game.players[777] = {"pos": Vector3.ZERO, "ghost": true, "can": 0, "bag": 4}
		before = farm.coins
		death.dawn()
		_check(farm.coins == before, "dead player's bag is not sold (coins moved by %d)" % (farm.coins - before))
		_check(int(Game.players[777].bag) == 0, "dead player's bag cleared")
		print("test_dawn_cashin: ", "PASS" if _fails == 0 else "FAIL")
		quit(1 if _fails > 0 else 0)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL", what)
