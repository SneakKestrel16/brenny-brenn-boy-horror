extends SceneTree
## P5-20 lobby names (QA): two instances over ENet, a mode per instance (`--qa=<mode>`):
##   client  renames in the lobby to "Pip[b]" (brackets stripped -> "Pipb"); host and client rosters show it;
##           after the match starts a `request_name("Late")` is refused.
##   host    sees "Pipb"; renames itself to "Pipb" and gets "Pipb 2" (duplicates kept apart); starts the match;
##           a rename after the start changes nothing.
##   uv run tools/qa/multi.py -n 2 --headless --duration 40 --common "--audio-driver Dummy" \
##     --args "-s res://tests/net/test_p5_20_names.gd -- --host --lobby --port=53960 --profile=qa_a --free-mouse --qa=host" \
##     --args "-s res://tests/net/test_p5_20_names.gd -- --join=127.0.0.1 --port=53960 --profile=qa_b --free-mouse --qa=client"
## Exits 0 on pass, 1 on failure or after 30 s. Restores the saved `player_name` setting on exit.

var _mode := ""
var _t := 0.0
var _step := 0
var _wait := 0.0
var _saved_name := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if not root.has_node("Net") or not root.has_node("Game"):
		return false
	var game := root.get_node("Game")
	var net := root.get_node("Net")
	if _t > 30.0:
		_end(false, "timed out in mode %s at step %d, profiles %s" % [_mode, _step, net.profiles])
		return false
	_wait -= delta
	if _wait > 0.0 or (_step < 3 and (game.players.size() < 2 or net.profiles.size() < 2)):  # the client may be gone by the last host step
		return false
	if _saved_name.is_empty():
		_saved_name = str(root.get_node("Settings").get_value(&"player_name"))
	if _mode == "host":
		_host(game, net)
	else:
		_client(game, net)
	return false


func _name(net: Node, peer: int) -> String:
	return str(net.profiles.get(peer, {}).get("name", ""))


func _roster_has(lobby: Node, s: String) -> bool:
	return lobby != null and lobby.get("_roster") != null and lobby._roster.text.contains(s)


func _host(game: Node, net: Node) -> void:
	var lobby := current_scene
	match _step:
		0:
			var peers: Array = net.profiles.keys().filter(func(p: int) -> bool: return p != 1)
			if _name(net, peers[0]) != "Pipb" or not _roster_has(lobby, "Pipb"):
				return
			lobby.rename("Pipb")  # same as the client's: kept apart
			_wait = 1.0
			_step = 1
		1:
			if _name(net, 1) != "Pipb 2":
				_end(false, "host duplicate name is '%s'" % _name(net, 1))
				return
			game.start_match()
			_wait = 1.0
			_step = 2
		2:
			if game.in_lobby:
				_end(false, "match did not start")
				return
			net.request_name("Late")  # host-side call, as `to_host` does for the host
			_wait = 3.0  # the client's refused request arrives too
			_step = 3
		3:
			var names: Array = net.profiles.values().map(func(v: Dictionary) -> String: return v.name)
			_end(not names.has("Late") and _name(net, 1) == "Pipb 2", "after start names %s" % [names])


func _client(game: Node, net: Node) -> void:
	var lobby := current_scene
	var me: int = game.local_peer()
	match _step:
		0:
			if lobby == null or not lobby.has_method("rename"):
				return
			lobby.rename("Pip[b]")
			_step = 1
		1:
			if _name(net, me) == "Pipb" and _roster_has(lobby, "Pipb") and _name(net, 1) == "Pipb 2":
				_step = 2
		2:
			if not game.in_lobby:  # the match started
				net.rpc_id(1, &"request_name", "Late")
				_wait = 2.0
				_step = 3
		3:
			var names: Array = net.profiles.values().map(func(v: Dictionary) -> String: return v.name)
			_end(not names.has("Late") and _name(net, me) == "Pipb", "client after start names %s" % [names])


func _end(ok: bool, why: String) -> void:
	var s := root.get_node("Settings")
	if not _saved_name.is_empty():
		s.set_value(&"player_name", _saved_name)
		s.save()
	print("test_p5_20: ", "PASS " if ok else "FAIL ", why)
	quit(0 if ok else 1)
