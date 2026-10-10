extends SceneTree
## P5-04 end to end (QA): a won season end, the host starts season 2 (doc 01 "Next season", doc 02 s21, doc 03 s22).
## One script, a mode per instance (`--qa=<mode>`):
##   host    runs the dev console to day 7 with spare coins and one upgrade, ends the season, waits for the Season Awards,
##           calls `Game.start_next_season()`; passes on `trait_gained` (season 2), `season_started` (savings = 25% of the
##           spare coins, cap 60, the upgrade carried), `Game.season_no == 2`, 5 s later
##   client  passes once the awards were shown, then Main reloaded with `Game.season_no == 2` and one trait
## Both instances use the Phase 1 farm (no cart: a paid debt is a win) and `--time-scale`:
##   uv run tools/qa/multi.py -n 2 --headless --duration 120 \
##     --args "--time-scale 8 -s res://tests/net/test_p5_04_e2e.gd -- --host --phase1-farm --lobby --lobby-start=2 --port=53742 --profile=qa_a --free-mouse --qa=host" \
##     --args "--time-scale 8 -s res://tests/net/test_p5_04_e2e.gd -- --join=127.0.0.1 --port=53742 --profile=qa_b --free-mouse --qa=client"
## Exits 0 on pass, 1 on failure or after 100 s (game time).

var _mode := ""
var _t := 0.0
var _in_match := 0.0
var _ev: Array = []
var _step := 0
var _spare := 0
var _done_at := -1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 100.0:  # game seconds (delta is scaled by --time-scale)
		_end(false, "timed out in mode %s at step %d" % [_mode, _step])
		return false
	var game: Node = root.get_node("Game")
	var main := current_scene
	if _step < 2 and (main == null or main.get_node_or_null("Death") == null or game.players.size() < 2):
		return false
	_in_match += delta
	if _mode == "host":
		_host(game, main)
	else:
		_client(game, main)
	return false


func _first(name: String) -> Variant:
	for e in _ev:
		if e[0] == name:
			return e[1]
	return null


func _host(game: Node, main: Node) -> void:
	var farm: Node = main.get_node_or_null("Farm") if main else null
	match _step:
		0:
			if _in_match > 3.0:
				var con := _find(main, "DevConsole")
				print("test_p5_04_e2e: ", con.run("day 7"), " / ", con.run("coins 2000"), " / ", con.run("buy quiet_watering_can"),
						" / ", con.run("phase dawn"))
				_step = 1
		1:  # the final dawn runs out, the season ends, the awards card shows
			if _first("season_awards_shown") != null:
				_spare = farm.coins  # the season end is before the reload
				print("test_p5_04_e2e: season over, spare coins ", _spare, " season_lost ", game.season_lost, " can start ", game.can_start_next_season())
				if not game.can_start_next_season():
					_end(false, "a won season cannot start the next")
					return
				game.lobby_autostart = 2  # P5-24: season 2 goes through the lobby; the QA autostart leaves it
				game.start_next_season()
				_step = 2
				_done_at = _t + 5.0
		2:
			if _t >= _done_at:
				var s: Variant = _first("season_started")
				var g: Variant = _first("trait_gained")
				if s == null or g == null:
					_end(false, "season_started %s trait_gained %s" % [s, g])
					return
				var want := mini(_spare * 25 / 100, 60)
				var ok: bool = game.season_no == 2 and int(g.season) == 2 and game.traits == [g.trait] and int(s.season) == 2 \
						and int(s.spare) == _spare and int(s.savings) == want and s.upgrades.has("quiet_watering_can") and s.traits == [g.trait]
				_end(ok, "season %d trait %s seed %s savings %d (want %d) spare %d upgrades %s" % [game.season_no, g.trait, g.seed, s.savings, want, s.spare, s.upgrades])


func _client(game: Node, _main: Node) -> void:
	if _first("season_awards_shown") != null and game.season_no == 2 and game.traits.size() == 1:
		_end(true, "client in season %d with trait %s" % [game.season_no, game.traits])


## Main's child whose script has this class_name (find_children's type does not see script classes).
func _find(main: Node, cls: String) -> Node:
	for c in main.get_children() if main else []:
		if c.get_script() and c.get_script().get_global_name() == cls:
			return c
	return null


func _end(ok: bool, why: String) -> void:
	print("test_p5_04_e2e: ", "PASS " if ok else "FAIL ", why)
	quit(0 if ok else 1)
