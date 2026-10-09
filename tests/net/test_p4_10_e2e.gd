extends SceneTree
## P4-10 end to end (QA): the clean host quit (`net_host_left` how `quit` and the host-left card) and the waiting
## card at a real dawn with one human left. One script, a mode per instance (`--qa=<mode>`):
##   host_quit        host: once a client has been in the match 3 s, quit the game cleanly (Game.quit)
##   expect_host_quit client: pass on `net_host_left` how `quit` with the pause menu's host-left card up
##   leave            client: 3 s into the match, quit cleanly (the host logs `net_peer_left` how `quit`)
##   expect_wait      host: once the client has left, run to the next dawn; pass on `waiting_for_farmhand`
##                    with the clock stopped, the card shown and that dawn's `save_written`
## Clean quit:
##   uv run tools/qa/multi.py -n 2 --headless --duration 60 \
##     --args "-s res://tests/net/test_p4_10_e2e.gd -- --host --lobby --lobby-start=2 --port=51801 --profile=qa_a --free-mouse --qa=host_quit" \
##     --args "-s res://tests/net/test_p4_10_e2e.gd -- --join=127.0.0.1 --port=51801 --profile=qa_b --free-mouse --qa=expect_host_quit"
## Waiting card:
##   uv run tools/qa/multi.py -n 2 --headless --duration 60 \
##     --args "-s res://tests/net/test_p4_10_e2e.gd -- --host --lobby --lobby-start=2 --port=51802 --profile=qa_a --free-mouse --qa=expect_wait" \
##     --args "-s res://tests/net/test_p4_10_e2e.gd -- --join=127.0.0.1 --port=51802 --profile=qa_b --free-mouse --qa=leave"
## Distinct `--profile`s matter: without them both instances share one player_uid, the roster has one entry
## and the waiting card (2+ player roster) never shows.
## Exits 0 on pass, 1 on failure or after 50 s.

var _mode := ""
var _t := 0.0
var _in_match := -1.0  ## seconds since this peer reached Main with two players (host) or at all (client)
var _had_two := false
var _ev: Array = []
var _acted := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 50.0:
		_end(false, "timed out in mode %s" % _mode)
		return false
	var game: Node = root.get_node("Game")
	var main := current_scene
	if main != null and main.get_node_or_null("Death") != null and (_in_match >= 0.0 or game.players.size() >= 2):
		_in_match = maxf(_in_match, 0.0) + delta
		_had_two = _had_two or game.players.size() >= 2
	match _mode:
		"host_quit", "leave":
			if _in_match > 3.0 and not _acted:
				_acted = true
				print("test_p4_10_e2e: %s quits now" % _mode)
				game.quit()  # its own get_tree().quit() ends the process
		"expect_host_quit":
			for e in _ev:
				if e[0] == "net_host_left":
					var menu: Node = _find(main, "PauseMenu")
					_end(e[1].how == "quit" and menu != null and menu._host_left and menu._open,
							"net_host_left how %s, card %s" % [e[1].how, menu != null and menu._host_left])
					return false
		"expect_wait":
			if _had_two and game.humans() == 1 and not _acted:
				_acted = true
				print("test_p4_10_e2e: alone, ", _find(main, "DevConsole").run("phase dawn"))
			if _acted:
				for e in _ev:
					if e[0] == "waiting_for_farmhand":
						var card: Node = _find(main, "WaitingCard")
						var clock: Node = root.get_node("Clock")
						var saved := _ev.any(func(x: Array) -> bool: return x[0] == "save_written" and int(x[1].day) == int(e[1].day))
						var left := _ev.any(func(x: Array) -> bool: return x[0] == "net_peer_left" and x[1].how == "quit")
						var rescaled := _ev.any(func(x: Array) -> bool: return x[0] == "debt_rescaled" and int(x[1].players) == 1)
						_end(card.waiting and card._root.visible and not clock.running and clock.phase == &"dawn" and saved and left and rescaled,
								"waiting at day %d: card %s, clock running %s, saved %s, peer left by quit %s, debt rescaled %s"
								% [e[1].day, card._root.visible, clock.running, saved, left, rescaled])
						return false
	return false


## Main's child whose script has this class_name (find_children's type does not see script classes).
func _find(main: Node, cls: String) -> Node:
	for c in main.get_children() if main else []:
		if c.get_script() and c.get_script().get_global_name() == cls:
			return c
	return null


func _end(ok: bool, why: String) -> void:
	print("test_p4_10_e2e: ", "PASS " if ok else "FAIL ", why)
	quit(0 if ok else 1)
