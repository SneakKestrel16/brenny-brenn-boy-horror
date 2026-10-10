extends SceneTree
## P5-09: quirks (pure helpers, host assignment, effects, save round trip, reveal lines). No scene beyond boot.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_quirks.gd -- --host --lobby --port=53731 --free-mouse
var Quirks
var Watch

var _fails := 0
var _frames := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _pure() -> void:
	var ids: Array = Quirks.ids()
	_check(ids.size() == 10 and not &"assign" in ids, "ten quirks, the assign record is not one")
	var u := ["c", "a", "b", "d"]
	var a: Dictionary = Quirks.draw(u, 7, 1, {}, ids)
	var b: Dictionary = Quirks.draw(["d", "b", "a", "c"], 7, 1, {}, ids)
	_check(a == b and a.size() == 4, "same seed, season and roster: same draw, whatever the join order")
	_check(a.values().size() == 4 and a.values().all(func(q: Variant) -> bool: return a.values().count(q) == 1), "drawn without replacement in the team")
	_check(Quirks.draw(u, 8, 1, {}, ids) != a or Quirks.draw(u, 7, 2, {}, ids) != a, "a new seed or season redraws")
	var c: Dictionary = Quirks.draw(u + ["e"], 7, 1, a, ids)
	_check(c.a == a.a and c.b == a.b and c.c == a.c and c.d == a.d and not c.e in a.values(), "a rejoiner or latecomer: held quirks stay, the new one gets a fresh one")
	var ten: Array = []
	for i in 12:
		ten.append("p%02d" % i)
	_check(Quirks.draw(ten, 1, 1, {}, ids).size() == 12, "a team over ten still draws (repeats)")
	_check(Quirks.reveal({"ua": &"adhd", "ub": &"ocd", "ux": &"dyspraxia"}, {"ua": "Ann", "ub": "Bo"}) == ["Ann: ADHD", "Bo: OCD", "A farmhand: Dyspraxia"], "reveal names every holder, one who left too, with the real disorder name")
	# data numbers, cited by data/quirks.json
	_check(Quirks.effects(&"anxiety_disorder").shaken_duration_mult == 2 and Quirks.effects(&"adhd").voice_radius_mult == 1.5, "effects read from data")
	_check(Quirks.effects(&"") == {} and Quirks.display_name(&"hoarding_disorder") == "Hoarding disorder", "no quirk, no effects; names are the real disorders (D-052)")
	var g := Vector3(0, 0, 0)  # scarecrow, facing -Z
	_check(Watch.in_gaze(g, Vector3(0, 0, -5), 6.0, 120.0), "OCD: 5 m in front is in the gaze")
	_check(not Watch.in_gaze(g, Vector3(0, 0, 5), 6.0, 120.0), "OCD: behind the scarecrow is not")
	_check(not Watch.in_gaze(g, Vector3(0, 0, -7), 6.0, 120.0), "OCD: 7 m is out of range")
	_check(Watch.in_gaze(g, Vector3(3, 0, -2), 6.0, 120.0) and not Watch.in_gaze(g, Vector3(4, 0, -2), 6.0, 120.0) and not Watch.in_gaze(g, Vector3(5, 0, 1), 6.0, 120.0), "OCD: the arc is 120 degrees")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 20:
		Quirks = load("res://game/player/quirks.gd")
		Watch = load("res://game/player/quirk_watch.gd")
		_pure()
		_host()
		print("test_quirks: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
		quit(0 if _fails == 0 else 1)
	return false


func _host() -> void:
	var Game := root.get_node("Game")
	var Net := root.get_node("Net")
	var Roles = load("res://game/player/roles.gd")
	Net.profiles[1] = {"uid": "a".repeat(32), "name": "h"}
	Net.profiles[-2] = {"uid": "b".repeat(32), "name": "bot"}
	Game.players[-2] = {}
	Game.players[1] = {}
	Roles.sync()
	_check(Game.quirks.is_empty() and Quirks.mine == &"", "option off: nobody has a quirk")
	Quirks.set_on(true)  # lobby: the option flips, nobody is drawn yet
	_check(Game.quirks_on and Game.quirks.is_empty(), "lobby: option on, no draw before the match")
	Game.in_lobby = false
	Roles.sync()  # match start
	var qa: StringName = Quirks.held(1)
	var qb: StringName = Quirks.held(-2)
	_check(qa != &"" and qb != &"" and qa != qb and Quirks.mine == qa, "match start: each draws one, different; the host knows its own")
	var snap: Dictionary = Game.quirks.duplicate()
	Game.players[1] = {"rejoin": true}  # a rejoin rebuilds the dictionary
	Roles.sync()
	_check(Quirks.held(1) == qa and Game.quirks == snap, "a rejoiner keeps their quirk")
	Game.players[1].ghost = true
	_check(Quirks.of(1) == &"" and Quirks.held(1) == qa, "a ghost has none (held remembers it for Narcolepsy)")
	Game.players[1].ghost = false
	# effects
	Game.players[1].quirk = &"hoarding_disorder"
	_check(Quirks.carry_cap(Game.players[1]) == 5 and Quirks.carry_cap({}) == 4, "Hoarding: five slots, else four (labor.json carry 4)")
	Game.players[1].quirk = &"anxiety_disorder"
	_check(Quirks.effect(1, &"shaken_duration_mult") == 2 and Quirks.effect(-2, &"shaken_duration_mult") == 1.0, "Anxiety doubles Shaken for its owner only")
	Game.players[1].quirk = &"schizophrenia"  # scares.gd _day_for compares Clock.day with this data number
	var fx: Dictionary = Quirks.effects(&"schizophrenia")
	var was: Variant = fx.hallucination_opens_day
	_check(Quirks.effect(1, &"hallucination_opens_day", 99) == was and Quirks.effect(-2, &"hallucination_opens_day", 99) == 99, "Schizophrenia: the opening day is the data number; others get the 99 fallback")
	fx.hallucination_opens_day = 3
	_check(Quirks.effect(1, &"hallucination_opens_day", 99) == 3, "changing the data number changes the day")
	fx.hallucination_opens_day = was
	Quirks.mine = &"hoarding_disorder"
	_check(Quirks.local(&"walk_speed_mult") == 0.9 and Quirks.local(&"crouch_speed_mult") == 0.9 and Quirks.local(&"sprint_refill_mult") == 1.0, "Hoarding slows walk and crouch, not sprint")
	Quirks.mine = &"anxiety_disorder"
	_check(Quirks.local(&"sprint_refill_mult") == 0.5, "Anxiety refills sprint twice as fast")
	# save round trip
	var Save = load("res://game/core/save.gd")
	_check("quirks_on" in Save.GAME_FLAGS, "the option is saved with the season")
	Game.quirks = snap.duplicate()
	var again: Dictionary = JSON.parse_string(JSON.stringify(Game.quirks))
	Game.quirks = again
	Game.in_lobby = false
	Game.players[1] = {}
	Roles.sync()
	_check(Quirks.held(1) == qa, "quirks come back from the save by uid")
	Quirks.reroll(2)
	_check(Game.quirks.size() == 2, "reroll redraws the season's quirks")
	Game.quirks_on = false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
