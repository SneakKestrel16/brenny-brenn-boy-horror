extends SceneTree
## P5-36 (QA): the host's dev console messages one player; only that player's screen shows it. Three peers.
## Modes: host (sends `msg <a's peer> ...`, opens the dev menu and saves a screenshot), a (must show it), b (must not).
##   uv run tools/qa/multi.py -n 3 --duration 90 --common "--audio-driver Dummy" \
##     --args "-s res://tests/net/test_p5_36_msg.gd -- --host --port=54830 --profile=qa_a --free-mouse --qa=host" \
##     --args "-s res://tests/net/test_p5_36_msg.gd -- --join=127.0.0.1 --port=54830 --profile=qa_b --free-mouse --qa=a" \
##     --args "-s res://tests/net/test_p5_36_msg.gd -- --join=127.0.0.1 --port=54830 --profile=qa_c --free-mouse --qa=b"
## Exits 0 on pass. Screenshots go to the folder in `--shots=<dir>` when given.

var _mode := ""
var _shots := ""
var _t := 0.0
var _in_main := 0.0
var _seen := ""
var _sent := false
var _done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
		elif a.begins_with("--shots="):
			_shots = a.substr(8)
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	var con := _find(main, "DevConsole")
	if con == null:
		return false
	_in_main += delta
	var game: Node = root.get_node("Game")
	if con._toast.visible and _seen == "":
		_seen = con._toast.text
		_shot("toast_" + _mode)
	if _mode == "host":
		if not _sent and _in_main > 4.0 and game.players.size() >= 3:
			_sent = true
			var peers: Array = game.players.keys().filter(func(p: int) -> bool: return p != 1)
			peers.sort()
			var target: int = peers[0]
			print("test_p5_36: ", con.run("msg %d the secret word" % target), " (a = peer %d)" % target)
			print("test_p5_36: ", con.run("msg nobody_here hi"))
			con._toggle()  # the menu, for a screenshot
			get_root_after(1.0, func() -> void:
				_shot("menu_host")
				con._picker.select(con._picker.get_item_index(target))
				con._menu_run("msg {p} via the menu"))
		if _t > 25.0:
			_end(true, "host done")
	elif _in_main > 14.0:
		var others: Array = game.players.keys().filter(func(p: int) -> bool: return p != 1)
		var want := "the secret word" if game.local_peer() == others.min() else ""  # peer ids are random: a/b is only a label
		_end(_seen == want,"saw '%s', wanted '%s'" % [_seen, want])
	return false


func get_root_after(s: float, f: Callable) -> void:
	create_timer(s).timeout.connect(f)


func _shot(name: String) -> void:
	if _shots == "" or root.get_viewport().get_texture() == null:
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, name])


func _find(main: Node, cls: String) -> Node:
	for c in main.get_children() if main else []:
		if c.get_script() and c.get_script().get_global_name() == cls:
			return c
	return null


func _end(ok: bool, why: String) -> void:
	if _done:
		return
	_done = true
	print("test_p5_36: ", _mode, " ", "PASS " if ok else "FAIL ", why)
	if _mode != "host" and ok:
		create_timer(2.0).timeout.connect(quit.bind(0))
		return
	quit(0 if ok else 1)
