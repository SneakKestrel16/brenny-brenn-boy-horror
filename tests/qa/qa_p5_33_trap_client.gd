extends SceneTree
## P5-33 QA (two instances): the trap race seen from the CLIENT. `--qa=victim` walks the client onto the host's
## armed bear trap and prints its HUD banner while pinned, until it dies or is freed. `--qa=helper` waits for the
## host to be pinned (`--force-spring` on the host), prints the friend alert, walks to the trap and pries it.
## The client walks with player.gd `nav_path` (walking speed), out of the barn door first.
##   uv run tools/qa/multi.py -n 2 --headless --duration 90 --common "--audio-driver Dummy" \
##     --args "-- --host --port=54960 --dev '--dev-exec=wait 6;day 2;trap bear' --free-mouse --seed=1" \
##     --args "-s res://tests/qa/qa_p5_33_trap_client.gd -- --join=127.0.0.1 --port=54960 --free-mouse --qa=victim"
## `--qa=watch` only prints (crow models seen on the client every 5 s).
## Helper: host `--force-spring '--dev-exec=wait 6;day 2;wait 20;trap bear'`, client `--qa=helper --at=17.6,-14`
## (trap_03, the spot `trap bear` picks nearest the barn spawn).

var _mode := ""
var _t := 0.0
var _last := ""
var _goal := Vector3.INF
var _pried := false
var _done := false
var _walking := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
		if a.begins_with("--at="):  # helper: wait here (x,z) before the spring, so the pry starts inside the race
			var xz := a.substr(5).split_floats(",")
			_goal = Vector3(xz[0], 0, xz[1])
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _say(s: String) -> void:
	print("[qa %.1f] %s" % [_t, s])


func _physics_process(delta: float) -> bool:
	_t += delta
	if _done or not root.has_node("Game") or not root.has_node("Main/TrapRace"):
		return false
	var game := root.get_node("Game")
	var me: int = game.local_peer()
	var pl: Node = root.get_node_or_null("Main/Players/%d" % me)
	if pl == null or game.players.size() < 2:
		return false
	var race := root.get_node("Main/TrapRace")
	var banner: String = pl.get_node("Hud").get("_banner").text
	if banner != _last:
		_last = banner
		_say("banner: %s | ends %s | pinned %s" % [banner.replace("\n", " / "), race.ends, pl.pinned])
	if _goal != Vector3.INF and not _walking and not pl.pinned:
		_walking = true  # out of the barn door as hold_controller's autochore walks (door at (0, 0)), then to the trap
		pl.nav_path = [Vector3(0, 0, -4), Vector3(0, 0, 4), Vector3(_goal.x, 0, 4), _goal]
	elif _walking and pl.nav_path.is_empty() and Vector2(pl.global_position.x - _goal.x, pl.global_position.z - _goal.z).length() > 0.3:
		pl.nav_path = [_goal]
	if fmod(_t, 5.0) < delta:
		_say("at %s nav %s, crow models %d, phase %s" % [pl.global_position, pl.nav_path,
				root.find_children("animal_crow*", "", true, false).size(), root.get_node("Clock").phase])
	if _mode == "victim":
		if game.is_ghost(me):
			_say("dead: %s" % banner.replace("\n", " / "))
			_done = true
		elif _goal == Vector3.INF:
			for id in race.traps:
				if race.traps[id].kind == &"bear" and race.traps[id].state == &"set":
					_goal = race.traps[id].position
					_say("walking onto %s at %s" % [id, _goal])
	elif _mode == "helper":
		for id in race.victims:
			if race.victims[id] == me:
				continue
			_goal = race.traps[id].position + Vector3(1.6, 0, 0)  # in pry range (2 m), out of spring range (1 m)
			var hold: Node = pl.get_node("HoldController")
			var farm: Node = pl.get_tree().get_first_node_in_group(&"farm")
			if not _pried and Vector2(pl.global_position.x - _goal.x, pl.global_position.z - _goal.z).length() < 0.5 and farm.targets.has(id):
				_pried = true
				hold.start(&"pry", farm.targets[id])
				hold.set("_scripted", true)
				_say("prying %s for peer %d" % [id, race.victims[id]])
		if _pried and race.victims.is_empty():
			_say("victim freed; banner now: '%s'" % banner)
			_done = true
	return false
