extends SceneTree
## P5-13 (D-165): the host's colour slots. A leaver's slot is kept for a rejoiner while free, a newcomer takes the
## lowest free one, and a rejoiner whose slot is taken gets another.
##   godot --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_colour_slots.gd

var _fails := 0


func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	net.profiles = {1: {"uid": "u1"}, 2: {"uid": "u2"}, 3: {"uid": "u3"}}
	game.players = {1: {}, 2: {}, 3: {}}
	game.assign_colours()
	_check(game.colour_slots == {1: 0, 2: 1, 3: 2}, "first join order: %s" % game.colour_slots)
	game.players.erase(2)  # u2 leaves
	game.assign_colours()
	_check(game.colour_slots == {1: 0, 3: 2}, "others keep slots after a leave: %s" % game.colour_slots)
	net.profiles[4] = {"uid": "u4"}
	game.players[4] = {}  # u4 joins while u2 is away: takes the free slot 1
	game.assign_colours()
	_check(game.colour_slots[4] == 1, "newcomer takes lowest free: %s" % game.colour_slots)
	net.profiles[5] = {"uid": "u2"}
	game.players.erase(4)
	game.players[5] = {}  # u2 rejoins as a new peer with slot 1 free again
	game.assign_colours()
	_check(game.colour_slots[5] == 1, "rejoiner keeps a free slot: %s" % game.colour_slots)
	net.profiles[6] = {"uid": "u4"}
	game.players[6] = {}  # u4 rejoins, its slot 1 is taken by u2
	game.assign_colours()
	_check(game.colour_slots[6] == 3 and game.colour_slots[5] == 1, "rejoiner whose slot is taken gets another: %s" % game.colour_slots)
	game.players = {}
	game.colours.clear()
	game.colour_slots.clear()
	net.profiles = {}
	print("test_colour_slots: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + what)
