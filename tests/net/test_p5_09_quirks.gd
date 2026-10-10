extends SceneTree
## P5-09 end to end (QA): Quirks on, two instances over ENet. One script, a mode per instance (`--qa=<mode>`):
##   host    the match starts with `--quirks`; both players hold a different quirk on the host; then the host ends the
##           season, and its card names both quirks.
##   client  learns only its own quirk (`Quirks.mine`), never anyone's on `Game.players`; then the Season Awards card
##           from the host names both quirks, its own among them.
##   uv run tools/qa/multi.py -n 2 --headless --duration 60 --common "--audio-driver Dummy" \
##     --args "-s res://tests/net/test_p5_09_quirks.gd -- --host --lobby --lobby-start=2 --quirks --port=53733 --profile=qa_a --free-mouse --qa=host" \
##     --args "-s res://tests/net/test_p5_09_quirks.gd -- --join=127.0.0.1 --port=53733 --profile=qa_b --free-mouse --qa=client"
## Exits 0 on pass, 1 on failure or after 50 s.

var _mode := ""
var _t := 0.0
var _step := 0
var _wait := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 50.0:
		_end(false, "timed out in mode %s at step %d" % [_mode, _step])
		return false
	var main := current_scene
	var game := root.get_node("Game")
	if main == null or main.get_node_or_null("TrapRace") == null or game.players.size() < 2:
		return false
	_wait -= delta
	if _wait > 0.0:
		return false
	var sa := _awards(main)
	if sa == null:
		return false
	if _mode == "host":
		_host(game, sa)
	else:
		_client(game, sa)
	return false


func _host(game: Node, sa: Node) -> void:
	var q: Object = load("res://game/player/quirks.gd")
	match _step:
		0:
			if game.quirks.size() < 2:
				return
			var held: Array = game.players.keys().map(func(p: int) -> StringName: return q.held(p))
			if held.has(&"") or held[0] == held[1]:
				_end(false, "host quirks missing or equal: %s" % [held])
				return
			print("test_p5_09: host table %s" % [game.quirks])
			_wait = 3.0  # the client reads its own first
			_step = 1
		1:
			sa._host_end()  # the client quits once it has seen its card, so the host reads its own card at once
			var lines := _quirk_lines(sa)
			_end(sa._open and lines.size() == 2, "host card names both quirks: %s" % [lines])


func _client(game: Node, sa: Node) -> void:
	var q: Object = load("res://game/player/quirks.gd")
	match _step:
		0:
			if q.mine == &"":
				return
			var leak: bool = game.players.values().any(func(st: Dictionary) -> bool: return st.has("quirk"))
			if leak:
				_end(false, "a quirk reached Game.players on the client")
				return
			print("test_p5_09: client quirk %s" % q.mine)
			_step = 1
		1:
			if not sa._open:
				return
			var lines := _quirk_lines(sa)
			var own: String = q.display_name(q.mine)
			var ok := lines.size() == 2 and lines.any(func(l: String) -> bool: return l.ends_with(": " + own))
			_end(ok, "client card %s, own quirk %s" % [lines, own])


func _quirk_lines(sa: Node) -> Array:
	var out: Array = []
	var q: Object = load("res://game/player/quirks.gd")
	var names: Array = q.ids().map(func(i: StringName) -> String: return q.display_name(i))
	for c in sa._box.get_children():
		if c is Label and names.any(func(n: String) -> bool: return c.text.ends_with(": " + n)):
			out.append(c.text)
	return out


func _awards(main: Node) -> Node:
	for c in main.get_children():
		if c.get_script() and c.get_script().get_global_name() == "SeasonAwards":
			return c
	return null


func _end(ok: bool, why: String) -> void:
	print("test_p5_09: ", "PASS " if ok else "FAIL ", why)
	quit(0 if ok else 1)
