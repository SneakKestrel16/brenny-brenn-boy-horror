extends SceneTree
## P5-66 (QA review): a real ghost client flies its crow with the normal keys. Windowed, the intro card holds
## `Game.console_open` until a key; a key press clears it. The host kills this client; the client (input events
## only, no --crow-fly) takes the nearest crow with `lantern`, flies with `move_forward`, turns with Player.look
## (what mouse motion calls), and checks the crow moved, then flew home and the perch crow shows again.
## `--quit-mid` instead quits mid-flight (the host must send the crow home: check its log).
##   uv run --no-project python tools/qa/multi.py -n 2 --duration 90 \
##     --args "--audio-driver Dummy -- --host --port=35066 --free-mouse --dev-exec=\"wait 8; kill 2\"" \
##     --args "--audio-driver Dummy -s res://tests/qa/qa_p5_66_crow_client.gd -- --join=127.0.0.1 --port=35066 --free-mouse"

var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node("Game")
	var hud: Node = null
	for i in 3000:
		await process_frame
		hud = root.find_child("Hud", true, false)
		if hud != null and hud.player != null and game.local_peer() != 1:
			break
	if hud == null or hud.player == null:
		_done("no Hud")
		return
	for i in 60:
		await process_frame
	var windowed := DisplayServer.get_name() != "headless"
	print("qa_p5_66: windowed=%s console_open at start=%s" % [windowed, game.console_open])
	if windowed:
		_check(game.console_open, "intro card holds console_open")
		_key(KEY_SPACE, true)
		_key(KEY_SPACE, false)
		await process_frame
		_check(not game.console_open, "a key closes the intro card and clears console_open")
	var player: Node3D = hud.player
	for i in 1200:  # the host kills us
		await process_frame
		if player.ghost:
			break
	_check(player.ghost, "client is a ghost")
	var perch := get_first_node_in_group(&"crow_perches") as Node3D
	player.global_position = perch.global_position + Vector3(2, 1, 2)  # the ghost floats there (client owns its movement)
	for i in 30:
		await physics_frame
	var powers: Node = current_scene.get_node("Death/GhostPowers")
	var near: Node3D = powers._nearest_perch(player.global_position)
	_press(&"lantern", true)
	_press(&"lantern", false)
	for i in 120:
		await process_frame
		if powers._my_crow != "":
			break
	_check(powers._my_crow == String(near.name), "lantern took crow %s (got '%s')" % [near.name, powers._my_crow])
	_check(not powers._perch_crow(near).visible, "perch crow hidden")
	var f: Dictionary = powers._flyers.get(game.local_peer(), {})
	if f.is_empty():
		_done("no flyer")
		return
	var start: Vector3 = f.node.global_position
	player.look(Vector2(0, 0))
	_press(&"move_forward", true)
	for i in 90:
		await physics_frame
	var p1: Vector3 = f.node.global_position
	player.look(Vector2(1200, 0))  # what mouse motion calls: turn hard
	for i in 60:
		await physics_frame
	_press(&"move_forward", false)
	var p2: Vector3 = f.node.global_position
	var leg1 := p1 - start
	var leg2 := p2 - p1
	print("qa_p5_66: start %s p1 %s p2 %s" % [start, p1, p2])
	_check(leg1.length() > 5.0, "W flew the crow %.1f m" % leg1.length())
	var turn := absf(rad_to_deg(Vector2(leg1.x, leg1.z).angle_to(Vector2(leg2.x, leg2.z))))
	_check(leg2.length() < 0.5 or turn > 20.0, "look turned the flight %.0f deg (leg2 %.1f m)" % [turn, leg2.length()])
	var cam: Camera3D = player._cam
	_check(cam.global_position.distance_to(p2) < 3.0, "ghost camera rides the crow (%.1f m)" % cam.global_position.distance_to(p2))
	if OS.get_cmdline_user_args().has("--quit-mid"):
		print("qa_p5_66: quitting mid-flight")
		quit(0)
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 35000:  # 20 s limit, then the flight home
		await process_frame
		if not powers._flyers.has(game.local_peer()):
			break
	_check(powers._my_crow == "", "crow let go")
	_check(not powers._flyers.has(game.local_peer()), "crow flew home and landed")
	_check(powers._perch_crow(near).visible, "perch crow shows again")
	var at := player.global_position
	_press(&"move_forward", true)
	for i in 30:
		await physics_frame
	_press(&"move_forward", false)
	_check(player.global_position.distance_to(at) > 1.0, "keys move the ghost again (camera back on the ghost)")
	_press(&"lantern", true)  # one crow a night: refused by the host
	_press(&"lantern", false)
	for i in 60:
		await process_frame
	_check(powers._my_crow == "", "second crow refused")
	_done("")


func _event(action: StringName) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.duplicate()
	return InputMap.action_get_events(action)[0].duplicate()


func _press(action: StringName, on: bool) -> void:
	var e := _event(action)
	e.pressed = on
	Input.parse_input_event(e)


func _key(code: Key, on: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = on
	Input.parse_input_event(e)


func _check(ok: bool, what: String) -> void:
	print("qa_p5_66: %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _done(why: String) -> void:
	if why != "":
		_fails += 1
		print("qa_p5_66: FAIL %s" % why)
	print("qa_p5_66: %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	quit(1 if _fails else 0)
