extends SceneTree
## P5-05 (doc 02 s21.5): cosmetics over ENet. One script for both instances (run host and client with it):
## - not sold before the debt is paid; the host buys and wears a hat for itself, gets the save round trip right;
## - the client, at the crate, is refused while far, then buys a top hat (70) and flat cap-free overalls (15) from
##   the host-held 100 coins; every peer sees the other's look, and the client's body on the host wears the hat.
##   uv run tools/qa/multi.py -n 2 --headless --audio-driver Dummy --duration 90 \
##     --args "-s res://tests/net/test_cosmetics.gd -- --host --port=53750 --free-mouse" \
##     --args "-s res://tests/net/test_cosmetics.gd -- --join=127.0.0.1 --port=53750 --free-mouse"
## Each prints `test_cosmetics: PASS` or `FAIL`.

var _fails := 0
var _refused: Array = []
var _is_host := false


func _initialize() -> void:
	_is_host = OS.get_cmdline_user_args().has("--host")
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node("Game")
	var cos: Node = root.get_node("Cosmetics")
	var net: Node = root.get_node("Net")
	net.apply_received.connect(func(what: StringName, args: Array) -> void:
		if what == &"refused" and args[0] == &"cosmetic":
			_refused.append(args[1]))
	for i in 3000:
		await process_frame
		if current_scene and current_scene.get_node_or_null("Farm") != null and current_scene.get_node_or_null("Players") != null \
				and game.players.size() >= 2 and game.local_peer() != 0 and (_is_host or game.local_peer() != 1):
			break
	if current_scene == null or game.players.size() < 2:
		print("test_cosmetics: FAIL (no 2-player Main)")
		quit(1)
		return
	for i in 60:
		await process_frame
	var farm: Node = current_scene.get_node("Farm")
	var me: int = game.local_peer()
	if _is_host:
		await _host(game, cos, farm, me)
	else:
		await _client(game, cos, farm, net, me)
	print("test_cosmetics: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)


func _host(game: Node, cos: Node, farm: Node, me: int) -> void:
	var clock: Node = root.get_node("Clock")
	var debt: Node = get_first_node_in_group(&"debt")
	var other := 0
	for p in game.players:
		if p != me:
			other = p
	_check(cos.ids().size() == 11, "11 cosmetics in data (%d)" % cos.ids().size())
	_check(not cos.sold_now(), "not sold before the debt is paid")
	if ResourceLoader.exists("res://assets/models/char_overalls_denim.glb"):  # P5-06 models: extras on the Armature
		_check(cos.tint(&"overalls_denim").to_html(false).to_upper() == "3F5F8F", "denim tint from the glb")
		_check(cos.tint(&"overalls_gold").to_html(false).to_upper() == "D9AE2C", "gold tint from the glb")
		_check(cos.tint(&"overalls_plaid").a == 0.0, "tint player: no override")
	cos.reset()
	_check(cos.owned_of(me).is_empty(), "reset forgets")
	farm.coins = 150
	_check(cos.buy(me, &"flat_cap") == &"not_sold", "buy refused before the debt is paid")
	_check(cos.wear(me, &"flat_cap") == &"not_owned", "cannot wear what is not owned")
	debt.paid = 1000000  # past any total: owed refreshes to 0
	debt._refresh_owed()
	debt._send()
	_check(cos.sold_now(), "sold once the debt is paid")
	_check(cos.buy(me, &"flat_cap") == &"too_far", "season running: buying needs the crate")
	clock.season_over = true  # the Season's End card sells anywhere (doc 02 s21.5)
	_check(cos.buy(me, &"flat_cap") == &"", "host buys a flat cap")
	_check(farm.coins == 135, "paid from team coins: 150 -> %d" % farm.coins)
	_check(cos.look(me).get(&"hat") == &"flat_cap", "a bought hat is worn")
	_check(cos.buy(me, &"flat_cap") == &"owned", "no second copy")
	var json: Variant = JSON.parse_string(JSON.stringify(cos.save_state()))
	cos.load_state({})
	_check(cos.owned_of(me).is_empty(), "load_state({}) clears")
	cos.load_state(json)
	_check(cos.owned_of(me) == [&"flat_cap"] and cos.look(me).get(&"hat") == &"flat_cap", "save round trip keeps owned and worn")
	farm.coins = 150
	clock.season_over = false
	var body: Node = current_scene.get_node("Players").player(other)
	for i in 9000:
		await process_frame
		if cos.look(other).get(&"hat") == &"top_hat" and cos.look(other).get(&"overalls") == &"overalls_plaid":
			break
	_check(cos.look(other).get(&"hat") == &"top_hat", "client's top hat reached the host table")
	_check(farm.coins == 40, "client paid 70 + 40 from 150: %d left" % farm.coins)
	for i in 10:
		await process_frame
	_check(body != null and body.find_child("CosmeticHat", true, false) != null, "the client's body wears the hat on the host")
	_check(body != null and body.find_child("CosmeticHat", true, false).get_parent() is BoneAttachment3D, "on the hat bone")
	if ResourceLoader.exists("res://assets/models/char_overalls_plaid.glb"):  # P5-06: the pattern is skinned overlay meshes
		var ov: Array = body._mesh.overlay()
		_check(not ov.is_empty() and ov.all(func(m: Node) -> bool: return m.get_parent() is Skeleton3D and m.is_inside_tree()), "plaid overlay meshes on the body's skeleton")
	_check(me == 1 and cos.look(me).get(&"hat") == &"flat_cap", "host still wears the flat cap")
	for i in 600:  # the client takes the hat off, then the overalls
		await process_frame
		if cos.look(other).get(&"overalls", &"x") == &"":
			break
	for i in 10:
		await process_frame
	_check(body._mesh.overlay().is_empty(), "overalls off: overlay meshes gone")
	for i in 900:  # the client finishes its own checks and quits; stay up until then
		await process_frame


func _client(game: Node, cos: Node, farm: Node, net: Node, me: int) -> void:
	var hud: Node = null
	for i in 3000:
		await process_frame
		hud = root.find_child("Hud", true, false)
		if hud != null and hud.player != null and cos.sold_now() and farm.coins >= 100:
			break
	if hud == null or not cos.sold_now():
		_check(false, "client sees the paid debt and 100 coins")
		return
	var crate := get_first_node_in_group(&"store_crate") as Node3D
	_check(await _ask(net, &"buy", &"top_hat") == &"too_far", "far from the crate: refused too_far")
	await _walk(hud.player, crate.global_position + Vector3(1.6, 0.0, 0.0))
	for i in 30:
		await process_frame
	var r := await _ask(net, &"buy", &"top_hat")
	_check(r == &"", "at the crate: top hat bought (%s)" % r)
	_check(await _ask(net, &"buy", &"overalls_plaid") == &"", "plaid overalls bought")
	await _until(func() -> bool: return cos.look(me).get(&"overalls") == &"overalls_plaid")
	_check(cos.look(me).get(&"hat") == &"top_hat" and cos.look(me).get(&"overalls") == &"overalls_plaid", "client sees its own look")
	_check(cos.look(1).get(&"hat") == &"flat_cap", "client sees the host's flat cap")
	for i in 30:
		await process_frame
	var host_body: Node = current_scene.get_node("Players").player(1)
	_check(host_body != null and host_body.find_child("CosmeticHat", true, false) != null, "the host's body wears the hat on the client")
	for i in 300:  # the host checks the hat on this body first
		await process_frame
	net.to_host(&"request_cosmetic", [&"wear", &"", &"hat"])
	await _until(func() -> bool: return cos.look(me).get(&"hat", &"x") == &"")
	_check(cos.look(me).get(&"hat", &"x") == &"" and cos.owned_of(me).has(&"top_hat"), "take off keeps ownership")
	_check(await _ask(net, &"buy", &"overalls_gold") == &"no_coins", "40 coins: gold overalls refused")
	net.to_host(&"request_cosmetic", [&"wear", &"", &"overalls"])
	await _until(func() -> bool: return cos.look(me).get(&"overalls", &"x") == &"")
	for i in 120:  # let the host's checks finish first
		await process_frame


## The albedo of the farmer's `mat_farmer_overalls` surface override.
func _overalls_col(player: Node) -> Color:
	for mi in player._mesh.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name == "mat_farmer_overalls":
				return (m.get_surface_override_material(i) as StandardMaterial3D).albedo_color
	return Color(0, 0, 0, 0)


func _ask(net: Node, op: StringName, id: StringName) -> StringName:
	_refused.clear()
	var cos: Node = root.get_node("Cosmetics")
	var before: int = cos.owned_of(root.get_node("Game").local_peer()).size()
	net.to_host(&"request_cosmetic", [op, id, &""])
	for i in 180:
		await process_frame
		if not _refused.is_empty():
			return _refused[0]
		if cos.owned_of(root.get_node("Game").local_peer()).size() > before:
			return &""
	return &"timeout"


func _until(ok: Callable) -> void:
	for i in 180:
		await process_frame
		if ok.call():
			return


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


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL ", what)
