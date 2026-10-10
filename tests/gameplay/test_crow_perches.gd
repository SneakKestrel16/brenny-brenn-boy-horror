extends SceneTree
## P5-52: the Crowkeeper's bait perches (host logic): placing rules, the flush trigger, noise, cooldown, fake-out crows.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_crow_perches.gd -- --host --lobby --port=56510 --free-mouse

var _fails := 0
var _frames := 0
var _noises: Array = []


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 20:
		_run()
		print("test_crow_perches: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
		quit(0 if _fails == 0 else 1)
	return false


func _run() -> void:
	var Game := root.get_node("Game")
	var NoiseBus := root.get_node("NoiseBus")
	NoiseBus.noise_emitted.connect(func(p: Vector3, r: float, k: StringName, s: int) -> void: _noises.append([p, r, k, s]))
	for x in [0.0, 40.0]:  # two corn cover points: the edges
		var n := Node3D.new()
		n.add_to_group(&"creature_cover")
		root.add_child(n)
		n.global_position = Vector3(x, 0, 0)
	Game.players[1] = {"pos": Vector3(3, 0, 0), "role": &"crowkeeper"}
	Game.players[2] = {"pos": Vector3(60, 0, 0), "role": &""}
	var cp: Node = load("res://game/player/crow_perches.gd").new()
	root.add_child(cp)
	_check(cp.toggle(2) == &"not_crowkeeper", "only the Crowkeeper places")
	_check(cp.toggle(1) == &"" and cp.perches.size() == 1, "placed at a corn edge")
	_check(cp.toggle(1) == &"" and cp.perches.is_empty(), "pressing beside it takes it back up")
	cp.toggle(1)
	Game.players[1].pos = Vector3(20, 0, 0)
	_check(cp.toggle(1) == &"not_at_edge", "20 m from any edge is refused")
	Game.players[1].pos = Vector3(8, 0, 0)
	_check(cp.toggle(1) == &"too_close", "a second perch 5 m from the first is refused")
	Game.players[1].pos = Vector3(38, 0, 0)
	_check(cp.toggle(1) == &"" and cp.perches.size() == 2, "second perch at the other edge")
	Game.players[1].pos = Vector3(0, 0, 30)
	_check(cp.toggle(1) != &"" and cp.perches.size() == 2, "no third perch")

	# Perches at (3,0,0) and (38,0,0). Radius 8 m, eps 0.25 m, owner 1 never triggers its own.
	var src := {1: Vector3(3, 0, 1), 2: Vector3(9, 0, 0), "a0": Vector3(60, 0, 0)}
	cp.sources_override = func() -> Dictionary: return src.duplicate()
	_check(cp.step() == 0, "first look: nobody has moved yet")
	_check(cp.step() == 0 and _noises.is_empty(), "standing still near a perch (6 m) flushes nothing")
	src[1] = Vector3(4, 0, 0)
	_check(cp.step() == 0, "the owner moving beside their own perch flushes nothing")
	src[2] = Vector3(9.5, 0, 0)
	_check(cp.step() == 1, "a teammate moving 6 m away flushes the perch")
	_check(_noises.size() == 1 and _noises[0][2] == &"crow_flush" and _noises[0][3] == 0 and _noises[0][1] > 0.0, "the cawing is a noise the creature can hear")
	src[2] = Vector3(10.0, 0, 0)
	_check(cp.step() == 0, "cooldown: no second burst straight away")
	cp.perches[0].cd = 0.0
	src[2] = Vector3(20, 0, 0)
	src["a0"] = Vector3(60, 0, 0)
	_check(cp.step() == 0, "a mover 17 m out is not near")
	src["creature"] = Vector3(30, 0, 0)
	cp.step()
	src["creature"] = Vector3(31, 0, 0)
	_check(cp.step() == 1 and _noises.size() == 2, "the creature moving 7 m from the far perch flushes it too")
	cp.perches[0].cd = 0.0
	cp.perches[1].cd = 0.0
	root.get_node("Net").apply_received.emit(&"scare", [&"fake_out", -1, Vector3(3, 0, 5), ""])
	_check(_noises.size() == 3, "the creature's fake crows bursting 5 m from a perch flush it")
	root.get_node("Net").apply_received.emit(&"scare", [&"fake_out", -1, Vector3(3, 0, 5), ""])
	_check(_noises.size() == 3, "that perch is on cooldown for a second fake-out")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
