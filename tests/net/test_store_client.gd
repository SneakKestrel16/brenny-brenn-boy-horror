extends SceneTree
## P4-22 (QA review): a client walks to the crate, opens the store menu with `interact`, buys scrap (the host
## validates and mirrors it), is refused a buy from 12 m away, closes the menu and sees the scrap on its hotbar.
## Run as the client of a 2-instance session (from QA's client_buy.gd):
##   uv run tools/qa/multi.py -n 2 --headless --duration 90 \
##     --args "-- --host --port=24704 --free-mouse --dev-exec=\"wait 4; coins 300\"" \
##     --args "-s res://tests/net/test_store_client.gd -- --join=127.0.0.1 --port=24704 --free-mouse"

var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")
	_run.call_deferred()


func _run() -> void:
	var hud: Node = null
	var game: Node = root.get_node("Game")
	for i in 3000:
		await process_frame
		hud = root.find_child("Hud", true, false)
		if hud != null and current_scene and current_scene.get_node_or_null("Farm") != null and hud.player != null and game.local_peer() != 1 and current_scene.get_node("Farm").coins >= 100:
			break
	if hud == null:
		print("test_store_client: FAIL (no Hud)")
		quit(1)
		return
	var farm: Node = current_scene.get_node("Farm")
	var store: Node = farm.store
	var me: int = game.local_peer()
	print("test_store_client: me=%d coins=%d" % [me, farm.coins])
	var crate := get_first_node_in_group(&"store_crate") as Node3D
	var player: Node3D = hud.player
	await _walk(player, crate.global_position + Vector3(1.6, 0.0, 0.0))
	player.look_at(crate.global_position + Vector3(1.6, 1.0, 6.0))
	for i in 30:
		await process_frame
	print("test_store_client: player %s crate %s me.pos %s" % [player.global_position, crate.global_position, game.players[me].get("pos")])
	_check(store.prompt_text(player.global_position) != "", "client: prompt at the crate")
	_press(&"interact")
	for i in 3:
		await process_frame
	var menu: Node = hud.get_child(-1)
	_check(menu._open and game.console_open, "client: interact opens the menu")
	var c0: int = farm.coins
	_row(menu, &"scrap")[3].pressed.emit()
	for i in 120:
		await process_frame
		if farm.coins != c0:
			break
	_check(farm.coins == c0 - 15 and store.scrap_bought == 1, "client buy scrap mirrored (coins %d -> %d, scrap %d)" % [c0, farm.coins, store.scrap_bought])
	# far away: the host must refuse even though the menu is open
	await _walk(player, crate.global_position + Vector3(12.0, 0.0, 0.0))
	for i in 30:
		await process_frame
	var c1: int = farm.coins
	menu._why.text = ""
	_row(menu, &"scrap")[3].pressed.emit()
	for i in 120:
		await process_frame
		if menu._why.text != "":
			break
	_check(farm.coins == c1 and store.scrap_bought == 1 and menu._why.text != "", "host refuses a far buy (why '%s', coins %d)" % [menu._why.text, farm.coins])
	_press(&"pause")
	for i in 3:
		await process_frame
	_check(not menu._open and not game.console_open, "client: Esc closes")
	var text := ""
	for s in hud._hotbar.get_children():
		text += s.get_child(0).text + " | "
	_check("Scrap x" in text, "client hotbar: " + text)
	print("test_store_client: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)


func _walk(player: Node3D, to: Vector3) -> void:
	for i in 3000:
		var d := Vector3(to.x - player.global_position.x, 0, to.z - player.global_position.z)
		if d.length() < 0.05:
			return
		await physics_frame
		var p := player.global_position + d.limit_length(2.5 / 60.0)
		p.y = 0.2 if d.length() < 0.2 else 12.0  # fly over buildings; the host speed check is horizontal only
		player.global_position = p
		if "velocity" in player:
			player.velocity = Vector3.ZERO


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
