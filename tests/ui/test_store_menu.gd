extends SceneTree
## P4-22: `interact` at the shipping crate opens the store menu (every store.json row and every crop's seed), Buy goes
## through the host's `request_store`, a seed row sets the seed planting uses, and the hotbar lists what is held.
## Windowed with `--shot=<dir>` it saves store_menu.png and hotbar.png there.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/ui/test_store_menu.gd -- --host --phase1 --port=24701 --free-mouse

var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")
	_run.call_deferred()


func _run() -> void:
	var hud: Node = null
	for i in 1200:
		await process_frame
		hud = root.find_child("Hud", true, false)
		if hud != null and current_scene.get_node_or_null("Farm") != null:
			break
	if hud == null:
		print("test_store_menu: FAIL (no Hud)")
		quit(1)
		return
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
	var farm: Node = current_scene.get_node("Farm")
	var store: Node = farm.store
	var game: Node = root.get_node("Game")
	var me: int = game.local_peer()
	var crate := get_first_node_in_group(&"store_crate") as Node3D
	var player: Node3D = hud.player
	player.global_position = crate.global_position + Vector3(1.6, 0.0, 0.0)
	player.look_at(crate.global_position + Vector3(1.6, 1.0, 6.0))  # away from the crate's plots: nothing aimed
	game.players[me].pos = player.global_position
	farm.coins = 100
	for i in 10:
		await process_frame
	_check(store.prompt_text() != "", "at the crate the prompt offers the store")
	_check(hud.hold.aimed_verb == &"", "nothing aimed (%s)" % hud.hold.aimed_verb)
	_press(&"interact")
	for i in 3:
		await process_frame
	var menu: Node = hud.get_child(-1)
	_check(menu._open and game.console_open, "interact at the crate opens the menu")
	var crops: Array = root.get_node("Data").records(&"crops")
	_check(menu._rows.size() == store.items().size() + crops.size(), "one row per store.json item and per crop (%d)" % menu._rows.size())

	# Buy goes through the host's request_store
	_row(menu, &"scrap")[3].pressed.emit()
	await process_frame
	_check(farm.coins == 85 and store.scrap_bought == 1, "Buy scrap: 15 coins, one scrap (coins %d)" % farm.coins)
	farm.coins = 0
	_row(menu, &"flare_gun")[3].pressed.emit()
	await process_frame
	_check(menu._why.text != "", "a refused Buy says why (%s)" % menu._why.text)
	farm.coins = 100

	# seeds: locked rows are greyed; a chosen seed is what a field plot plants
	_check(_row(menu, &"pumpkin")[3].disabled, "pumpkin seed locked before the first payment")
	root.get_node("Clock").day = 4
	load("res://game/farming/debt.gd").first_made = true
	await process_frame
	_check(not _row(menu, &"pumpkin")[3].disabled, "pumpkin seed on sale after the first payment")
	_row(menu, &"pumpkin")[3].pressed.emit()
	await process_frame
	_check(farm.seed_pick == &"pumpkin" and _row(menu, &"pumpkin")[3].text == "Chosen", "the pumpkin seed is chosen")
	var plot: Node = null
	for t in farm.targets.values():
		if t.has_method(&"wire_state") and not t.locked and not t.bed and t.state == &"empty":
			plot = t
			break
	var verb: StringName = plot.verbs_for({})[0]
	_check(verb == &"plant:pumpkin", "an empty field plot offers plant:pumpkin (%s)" % verb)
	var st: Dictionary = farm.pstate(me)
	_check(plot.can_start(verb, st) == &"", "the host accepts it")
	plot.complete(verb, me, st)
	_check(plot.crop == &"pumpkin" and farm.coins == 90, "planted a pumpkin for its 10-coin seed (coins %d)" % farm.coins)
	if shot != "":
		await create_timer(0.5).timeout
		root.get_viewport().get_texture().get_image().save_png(shot.path_join("store_menu.png"))

	# closing gives the keys back; the hotbar shows the seed and the scrap
	_press(&"pause")
	for i in 3:
		await process_frame
	_check(not menu._open and not game.console_open, "Esc closes the menu")
	var text := ""
	for s in hud._hotbar.get_children():
		text += s.get_child(0).text + "\n"
	_check("Pumpkin seed" in text and "Scrap x" in text, "the hotbar shows the seed and the scrap:\n" + text)
	if shot != "":
		await create_timer(0.5).timeout
		root.get_viewport().get_texture().get_image().save_png(shot.path_join("hotbar.png"))
	print("test_store_menu: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)


func _press(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _row(menu: Node, id: StringName) -> Array:
	for r in menu._rows:
		if r[0] == id:
			return r
	return []


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL ", what)
