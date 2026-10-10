extends SceneTree
## P5-53 end to end: the Horror role's scares appear only on the Horror player's peer. Two instances over ENet.
##   host    a non-Horror player: after the client is made Horror and 3 s pass, no `horror_scare` line, world not darker.
##   client  the Horror player: scares fire (`horror_scare` lines, all local), the world is darker (ambient < 1, fog > 1).
##   uv run tools/qa/multi.py -n 2 --headless --duration 40 --common "--audio-driver Dummy" \
##     --args "-s res://tests/net/test_p5_53_horror.gd -- --host --lobby --lobby-start=2 --port=56640 --profile=qa_a --free-mouse --qa=host" \
##     --args "-s res://tests/net/test_p5_53_horror.gd -- --join=127.0.0.1 --port=56640 --profile=qa_b --free-mouse --qa=client"
## Exits 0 on pass, 1 on failure or after 35 s.

var _mode := ""
var _t := 0.0
var _since := -1.0
var _seen := 0
var _hooked := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 35.0:
		_end(false, "timed out")
		return false
	var main := current_scene
	var game := root.get_node("Game")
	if main == null or main.get_node_or_null("TrapRace") == null or (game.players.size() < 2 and _since < 0.0):
		return false
	var hs: Node = null
	for c in main.get_children():
		if c.get_script() and c.get_script().get_global_name() == "HorrorScares":
			hs = c
	if hs == null:
		return false
	var roles: Object = load("res://game/player/roles.gd")
	if not _hooked:
		_hooked = true
		root.get_node("Log").logged.connect(func(n: StringName, _d: Dictionary) -> void:
			if n == &"horror_scare":
				_seen += 1)
	if _mode == "host":
		if _since < 0.0:
			for p in game.players:
				if p != 1:
					game.roles[roles._uid(p)] = &"horror"
			roles.sync()
			_since = _t
		elif _t - _since > 3.0:
			var dark: bool = hs.ambient_mult != 1.0 or hs.fog_mult != 1.0 or hs.lamp_mult != 1.0
			_end(_seen == 0 and not dark and roles.of(1) != &"horror", "host: scares %d, darker %s" % [_seen, dark])
	else:
		if roles.of(game.local_peer()) != &"horror":
			return false
		if _since < 0.0:
			_since = _t
			for k in hs.KINDS:
				hs._due[k] = 0.0  # all due at once
		elif _seen >= 2 and _t - _since > 2.0:
			var dark: bool = hs.ambient_mult < 1.0 and hs.fog_mult > 1.0 and hs.lamp_mult < 1.0
			_end(dark, "client: scares %d, darker %s" % [_seen, dark])
	return false


func _end(ok: bool, why: String) -> void:
	print("test_p5_53: ", "PASS " if ok else "FAIL ", why)
	quit(0 if ok else 1)
