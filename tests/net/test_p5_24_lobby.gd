extends SceneTree
## P5-24 (QA): a season end, then season 2 through the lobby, on two peers (doc 01 "Next season").
## One script, a mode per instance (`--qa=<mode>`):
##   host    runs the dev console to the final dawn, waits for the Season Awards, forces the client as the imposter
##           (dev setting, like the gated console), calls `Game.start_next_season()`. In the lobby: roles empty, quirks
##           empty, no pick. Picks a role for the client, lets `--lobby-start` start season 2. In season 2: the pick
##           happened (uid host-only), quirks drawn for season 2, the season-start save exists and holds no imposter
##           uid, the carried upgrade is back.
##   client  after the awards: sees the lobby (in_lobby, no role, no `Imposter.me`), then season 2 with the same
##           season, trait count and role as the host, `Imposter.me` true, a quirk, the season-start save copy, and
##           no log event naming the imposter.
## Both print `STATE ...` with the shared fields for a side by side check.
##   uv run python tools/qa/multi.py -n 2 --headless --duration 120 --common "--audio-driver Dummy" \
##     --args "--time-scale 8 -s res://tests/net/test_p5_24_lobby.gd -- --host --phase1-farm --lobby --lobby-start=2 --quirks --port=54140 --profile=qa_a --free-mouse --qa=host" \
##     --args "--time-scale 8 -s res://tests/net/test_p5_24_lobby.gd -- --join=127.0.0.1 --port=54140 --profile=qa_b --free-mouse --qa=client"
## Exits 0 on pass, 1 on failure or after 100 s (game time).

var _mode := ""
var _t := 0.0
var _in_match := 0.0
var _ev: Array = []
var _step := 0
var _at := 0.0
var _client_peer := 0
var _client_uid := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 100.0:
		_end(false, "timed out in mode %s at step %d" % [_mode, _step])
		return false
	var game: Node = root.get_node("Game")
	var main := current_scene
	if _mode == "host" and _step == 0 and (main == null or main.get_node_or_null("Death") == null or game.players.size() < 2):
		return false
	_in_match += delta
	if _mode == "host":
		_host(game, main)
	else:
		_client(game, main)
	return false


func _has(name: String) -> bool:
	for e in _ev:
		if e[0] == name:
			return true
	return false


func _in_main(main: Node) -> bool:
	return main != null and main.get_node_or_null("Death") != null


func _state(game: Node) -> String:
	var role := ""
	for p in game.players:
		if p != 1:
			role = str(game.players[p].get("role", ""))
	return "season %d traits %d in_lobby %s client_role %s sting_pending %s" % [game.season_no, game.traits.size(), game.in_lobby, role, game.season_sting]


func _host(game: Node, main: Node) -> void:
	var Imp: GDScript = load("res://game/core/imposter.gd")
	var Rl: GDScript = load("res://game/player/roles.gd")
	match _step:
		0:
			if _in_match > 3.0 and _in_main(main):
				for p in game.players:
					if p != 1:
						_client_peer = p
						_client_uid = str(root.get_node("Net").profiles[p].uid)
				var con := _find(main, "DevConsole")
				print("test_p5_24: ", con.run("day 7"), " / ", con.run("coins 2000"), " / ", con.run("buy quiet_watering_can"), " / ", con.run("phase dawn"))
				_step = 1
		1:
			if _has("season_awards_shown"):
				Imp.forced = _client_uid  # what the gated `imposter` command does
				if not game.start_next_season():
					_end(false, "start_next_season refused")
					return
				_step = 2
				_at = _t + 4.0
		2:  # the lobby
			if _t >= _at:
				var ok: bool = game.in_lobby and game.season_no == 2 and game.roles.is_empty() and game.quirks.is_empty() \
						and Imp.uid == "" and not Imp.picked and str(game.players[_client_peer].get("role", "")) == ""
				print("test_p5_24: host lobby ", _state(game))
				if not ok:
					_end(false, "lobby state wrong: roles %s quirks %s uid '%s' picked %s" % [game.roles, game.quirks, Imp.uid, Imp.picked])
					return
				Rl.on_request(_client_peer, &"rancher")
				game.lobby_autostart = 2
				_step = 3
		3:  # season 2 running
			if not game.in_lobby and _in_main(main) and game.match_started():
				_step = 4
				_at = _t + 4.0
		4:
			if _t >= _at:
				var farm: Node = main.get_node("Farm")
				var path: String = root.get_node("Game").season_id
				var save_path: String = load("res://game/core/save.gd").root() + path + "/latest.json"
				var text := FileAccess.get_file_as_string(save_path)
				var env: Variant = JSON.parse_string(text)
				var st: Dictionary = env.state if env is Dictionary else {}
				var quirk_season := 0
				for e in _ev:
					if e[0] == "quirk_assigned":
						quirk_season = int(e[1].season)
				print("test_p5_24: host s2 ", _state(game), " imposter picked ", Imp.picked)
				var why := ""
				if Imp.uid != _client_uid or not Imp.picked:
					why += "no pick; "
				if text == "" or "imposter" in text.to_lower() or not bool(st.get("season_start", false)) or int(st.get("season_no", 0)) != 2:
					why += "season-start save wrong (exists %s); " % (text != "")
				if quirk_season != 2:
					why += "quirk season %d; " % quirk_season
				if game.roles.get(_client_uid, "") != &"rancher":
					why += "role; "
				if int(farm.store.team.get(&"quiet_watering_can", 0)) < 1:
					why += "upgrade not carried; "
				if game.season_no != 2 or game.traits.size() != 1:
					why += "season/trait; "
				_end(why == "", "ok" if why == "" else why)


func _client(game: Node, main: Node) -> void:
	var Imp: GDScript = load("res://game/core/imposter.gd")
	match _step:
		0:
			if _has("season_awards_shown") and game.in_lobby and game.season_no == 2:
				print("test_p5_24: client lobby ", _state(game))
				if Imp.me:
					_end(false, "imposter flag set in the lobby")
					return
				_step = 1
		1:
			if not game.in_lobby and _in_main(main):
				_step = 2
				_at = _t + 5.0
		2:
			if _t >= _at:
				var l: Array = []
				for u in ["Imposter", "imposter"]:
					for e in _ev:
						if u in e[0] or u in str(e[1]):
							l.append(e[0])
				var sroot: String = load("res://game/core/save.gd").root()  # the client does not know the host's season id
				var fname := ""
				for dname in DirAccess.get_directories_at(sroot):
					if dname.ends_with("_s2"):
						fname = sroot + dname + "/latest.json"
				var text := FileAccess.get_file_as_string(fname)
				print("test_p5_24: client s2 ", _state(game), " me ", Imp.me, " quirk '", load("res://game/player/quirks.gd").mine, "'")
				var why := ""
				if not Imp.me:
					why += "not told; "
				if game.season_no != 2 or game.traits.size() != 1:
					why += "season/trait; "
				if str(game.players[game.local_peer()].get("role", "")) != "rancher":
					why += "role %s; " % game.players[game.local_peer()].get("role", "")
				if load("res://game/player/quirks.gd").mine == &"":
					why += "no quirk; "
				if text == "" or "imposter" in text.to_lower():  # (a uid is in `uids` anyway; the pick must not be)
					why += "save copy wrong (exists %s); " % (text != "")
				if not l.is_empty():
					why += "client log names imposter: %s; " % l
				_end(why == "", "ok" if why == "" else why)


## Main's child whose script has this class_name (find_children's type does not see script classes).
func _find(main: Node, cls: String) -> Node:
	for c in main.get_children() if main else []:
		if c.get_script() and c.get_script().get_global_name() == cls:
			return c
	return null


func _end(ok: bool, why: String) -> void:
	print("test_p5_24: ", _mode, " ", "PASS " if ok else "FAIL ", why)
	if _mode != "host" and ok:  # linger so the host's sends do not hit a closed peer
		_step = 9
		create_timer(4.0).timeout.connect(quit.bind(0))
		return
	quit(0 if ok else 1)
