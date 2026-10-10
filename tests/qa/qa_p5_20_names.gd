extends SceneTree
## P5-20 QA extra checks (two instances, `--qa=host|client`): a long unicode name with BBCode and a line break,
## a blank name, a duplicate of the host's name ("Hosty" -> "Hosty 2") that must not overwrite the client's saved
## `player_name`, the lobby name tag, and after the start the pause menu's roster on both ends.
##   uv run tools/qa/multi.py -n 2 --headless --duration 60 --common "--audio-driver Dummy" \
##     --args "-s res://tests/qa/qa_p5_20_names.gd -- --host --lobby --port=54021 --profile=qa_a --free-mouse --qa=host" \
##     --args "-s res://tests/qa/qa_p5_20_names.gd -- --join=127.0.0.1 --port=54021 --profile=qa_b --free-mouse --qa=client"

const LONG := "Ωmegä🐄Ωmegä🐄Ωmegä🐄Ωmegä🐄Ωmegä🐄Ωmegä🐄Ωmegä🐄\n[color=red]x[/color]"

var _mode := ""
var _t := 0.0
var _step := 0
var _wait := 0.0
var _saved := ""
var _settings: Node
var _ok := false


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
	_settings = root.get_node("Settings")
	if _t > 45.0:
		_end(false, "timeout step %d profiles %s" % [_step, net.profiles])
		return false
	_wait -= delta
	if _wait > 0.0 or (_step == 0 and (game.players.size() < 2 or net.profiles.size() < 2)):
		return false
	if _saved.is_empty():
		_saved = str(_settings.get_value(&"player_name"))
	if _mode == "host":
		_host(game, net)
	else:
		_client(game, net)
	return false


func _name(net: Node, peer: int) -> String:
	return str(net.profiles.get(peer, {}).get("name", ""))


func _texts(n: Node, out: Array) -> Array:
	if n is Label or n is Label3D:
		out.append(n.text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _pause_names(game: Node) -> Array:
	for c in current_scene.get_children():
		if c.has_method("set_open") and c.get_script().resource_path.ends_with("pause_menu.gd"):
			c.set_open(true)
			return _texts(c, [])
	return ["<no pause menu in %s>" % current_scene.name]


func _host(game: Node, net: Node) -> void:
	var other: int = net.profiles.keys().filter(func(p: int) -> bool: return p != 1)[0] if net.profiles.size() > 1 else 0
	match _step:
		0:
			current_scene.rename("Hosty")
			_step = 1
		1:
			if _name(net, other) == "Hosty 2":
				_wait = 2.0
				_step = 2
		2:
			game.start_match()
			_wait = 4.0
			_step = 3
		3:
			var t := _pause_names(game)
			print("qa_p5_20 host pause labels: ", t)
			_ok = t.has(_name(net, other)) and _name(net, other) == "Hosty 2"
			_wait = 6.0  # the client checks its pause menu before the host leaves
			_step = 4
		4:
			_end(_ok, "host pause shows client as 'Hosty 2'")


func _client(game: Node, net: Node) -> void:
	var me: int = game.local_peer()
	var lobby := current_scene
	match _step:
		0:
			if lobby == null or not lobby.has_method("rename"):
				return
			lobby.rename(LONG)
			_step = 1
		1:
			var n := _name(net, me)
			if n.begins_with("Ωmeg"):
				print("qa_p5_20 long -> '%s' (%d chars)" % [n, n.length()])
				if n.length() > 24 or n.contains("[") or n.contains("\n"):
					_end(false, "long name not cleaned: '%s'" % n)
					return
				lobby.rename(" \t \n ")
				_step = 2
		2:
			var n := _name(net, me)
			if n.begins_with("Farmer"):
				print("qa_p5_20 blank -> '%s'" % n)
				_step = 3
		3:
			if _name(net, 1) != "Hosty":
				return
			lobby._name_edit.text = "Hosty"  # typed, then Enter
			lobby.rename("Hosty")
			_step = 4
		4:
			if _name(net, me) != "Hosty 2":
				return
			var tags := _texts(lobby, []).filter(func(s: String) -> bool: return s == "Hosty 2")
			var saved := str(_settings.get_value(&"player_name"))
			lobby.rename(lobby._name_edit.text)  # focus-out after the host's suffix
			var saved2 := str(_settings.get_value(&"player_name"))
			print("qa_p5_20 dup: profile 'Hosty 2', field '%s', saved '%s' then '%s', tags %s" % [lobby._name_edit.text, saved, saved2, tags])
			if saved != "Hosty" or saved2 != "Hosty" or tags.is_empty():
				_end(false, "dup check failed")
				return
			_step = 5
		5:
			if game.in_lobby or current_scene == null or current_scene.has_method("rename"):
				return
			_wait = 3.0
			_step = 6
		6:
			var t := _pause_names(game)
			print("qa_p5_20 client pause labels: ", t)
			_ok = t.has("Hosty")
			_wait = 6.0  # stay until the host has checked its pause menu
			_step = 7
		7:
			_end(_ok, "client pause shows host")


func _end(ok: bool, why: String) -> void:
	if _settings and not _saved.is_empty():
		_settings.set_value(&"player_name", _saved)
		_settings.save()
	print("qa_p5_20: ", "PASS " if ok else "FAIL ", why)
	quit(0 if ok else 1)
