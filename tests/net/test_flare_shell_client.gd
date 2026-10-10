extends SceneTree
## P4-38 (D-147): a client at the crate is refused a flare shell without the gun, buys the gun, is refused a shell
## while the gun is full, fires the shot, buys a shell and sees one shot loaded. The host validates; the client checks
## the mirrored `flare_shots`, coins and its own menu reason.
## Run as the client of a 2-instance session:
##   uv run tools/qa/multi.py -n 2 --headless --duration 90 \
##     --args "-- --host --port=48382 --free-mouse --dev-exec=\"wait 4; coins 300\"" \
##     --args "-s res://tests/net/test_flare_shell_client.gd -- --join=127.0.0.1 --port=48382 --free-mouse"

var _fails := 0
var _refused: Array = []


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
	if hud == null or game.local_peer() == 1:
		print("test_flare_shell_client: FAIL (no client Hud)")
		quit(1)
		return
	root.get_node("Net").apply_received.connect(func(what: StringName, args: Array) -> void:
		if what == &"refused":
			_refused.append(args[1]))
	var farm: Node = current_scene.get_node("Farm")
	var store: Node = farm.store
	var me: int = game.local_peer()
	var crate := get_first_node_in_group(&"store_crate") as Node3D
	await _walk(hud.player, crate.global_position + Vector3(1.6, 0.0, 0.0))
	for i in 30:
		await process_frame

	_check(await _refuse(&"flare_shell") == &"no_flare", "no gun: the host refuses a shell")
	_buy(&"flare_gun")
	await _until(func() -> bool: return store.flare_shots == 1)
	_check(store.flare_shots == 1, "the gun's shot is mirrored (%d)" % store.flare_shots)
	_check(store.why_not(me, &"flare_shell", false) == &"flare_full", "the client menu greys the shell: gun full")
	_check(await _refuse(&"flare_shell") == &"flare_full", "full gun: the host refuses a shell")
	root.get_node("Net").to_host(&"request_store", [&"flare", &""])
	await _until(func() -> bool: return store.flare_shots == 0)
	_check(store.flare_shots == 0, "fired: 0 shots mirrored")
	var c0: int = farm.coins
	_buy(&"flare_shell")
	await _until(func() -> bool: return store.flare_shots == 1 and farm.coins != c0)
	_check(store.flare_shots == 1 and c0 - farm.coins == 15, "a shell loads one shot (shots %d, coins %d -> %d)" % [store.flare_shots, c0, farm.coins])
	print("test_flare_shell_client: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)


func _buy(id: StringName) -> void:
	root.get_node("Net").to_host(&"request_store", [&"buy", id])


func _refuse(id: StringName) -> StringName:
	_refused.clear()
	_buy(id)
	await _until(func() -> bool: return not _refused.is_empty())
	return _refused[0] if not _refused.is_empty() else &""


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
