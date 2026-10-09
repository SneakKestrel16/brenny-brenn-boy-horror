extends SceneTree
## P4-33: a client places flags up to its limit, is refused one more, pulls one up, and mirrors the host's
## list with owners (the drawn flag offers `remove_flag` to its owner only). Run as the client of a 2-instance session:
##   uv run tools/qa/multi.py -n 2 --headless --duration 60 \
##     --args "-- --host --port=24862 --free-mouse" \
##     --args "-s res://tests/net/test_flags_sync.gd -- --join=127.0.0.1 --port=24862 --free-mouse"

var _t := 0.0
var _step := 0
var _sent := 0.0
var _ids: Array = []
var _answers: Array = []  ## [what, args] from the host
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 50.0:
		print("test_flags_sync: FAIL (timed out at step %d)" % _step)
		quit(1)
		return false
	var net: Node = root.get_node("Net")
	var game: Node = root.get_node("Game")
	var sweep := get_first_node_in_group(&"trap_sweep")
	var players := current_scene.get_node_or_null("Players") if current_scene else null
	var me: int = game.local_peer()
	var body: Node3D = players.player(me) if players and me > 1 else null
	if sweep == null or body == null or _t < 4.0:
		return false
	var FS: GDScript = load("res://game/traps_player/flag_spot.gd")
	var lim: int = sweep.limit()
	if _step == 0:
		net.apply_received.connect(func(what: StringName, args: Array) -> void:
			if what in [&"hold_done", &"refused"]:
				_answers.append([what, args]))
		for i in lim + 1:
			_ids.append(FS.make_id(body.global_position + Vector3(i * 1.2 - 2.0, 0, 1.0)))
		_step = 1
	if _answers.size() < _step - 1 or _t - _sent < 0.2:
		return false  # waiting for the host's answer to the last request
	if _step <= lim + 2:
		var n := _step - 1
		if n > 0:
			var a: Array = _answers[n - 1]
			if n <= lim:
				_check(a[0] == &"hold_done", "flag %d placed (%s)" % [n, a])
			else:
				_check(a[0] == &"refused" and a[1][1] == &"flag_limit", "flag %d over the limit refused (%s)" % [n, a])
		if n < lim + 1:
			net.to_host(&"request_hold", [&"place_flag", _ids[n]])
		else:
			_check(sweep.count_of(me) == lim, "client mirror: %d of my flags" % sweep.count_of(me))
			var offered := 0
			for s in sweep.find_children("*", "", true, false):
				if s.get_script() == FS and s.by == me and s.verbs_for({}) == [&"remove_flag"]:
					offered += 1
			_check(offered == lim, "each of my drawn flags offers remove_flag (%d)" % offered)
			net.to_host(&"request_hold", [&"remove_flag", _ids[0]])
		_sent = _t
		_step += 1
		return false
	if _t - _sent < 1.0:
		return false  # the remove hold is 0.5 s; let apply_flags arrive
	var last: Array = _answers[_answers.size() - 1]
	_check(last[0] == &"hold_done" and last[1][0] == &"remove_flag", "remove_flag done (%s)" % [last])
	_check(sweep.count_of(me) == lim - 1, "client mirror after remove: %d" % sweep.count_of(me))
	print("test_flags_sync: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
	else:
		print("ok: ", what)
