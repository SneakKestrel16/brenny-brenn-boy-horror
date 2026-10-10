extends SceneTree
## P5-11 (Gameplay): the imposter secret over real ENet, 2 and 4 instances, plus a rejoin. One script, a role per
## instance (`--role=`); the host turns the toggle on and forces the FIRST client to join as the imposter through
## the dev setting (`I.dev_force`, the same path the gated console command uses), starts the match, checks
## the host-side rules, then broadcasts a final Dawn Report carrying the reveal line.
##   host        PASS when the host knows the imposter, is not told "me", the kit obeys sender/cooldown rules, and
##               a client's log would never be needed to know (the host broadcasts only the public report)
##   imposter    (`--designated`) PASS when `I.me` is true, then the Dawn Report shows the reveal line
##   honest      PASS when `I.me` stays false the whole run, then the Dawn Report shows the reveal line
##   rejoiner    like imposter, but launched late (`--wait=<s>`) with the imposter's `--profile`: the host replaces
##               the old peer (same uid) and the secret comes back to the new one
## 2 instances (port 53761), host plus one client (the imposter):
##   H=<this machine's hash from print_machine_hash.gd>
##   uv run tools/qa/multi.py -n 2 --headless --duration 60 \
##     --args "-s res://tests/net/test_imposter_sync.gd -- --role=host --n=2 --host --lobby --port=53761 --profile=imp_a --free-mouse --dev-gate-test-hash=$H" \
##     --args "-s res://tests/net/test_imposter_sync.gd -- --role=imposter --designated --join=127.0.0.1 --port=53761 --profile=imp_b --free-mouse"
## 4 instances (port 53762): the same host line with --n=4, a `--role=imposter --designated --profile=imp_b`
## client first, then `--role=honest --profile=imp_c` and `--profile=imp_d` clients.
## Rejoin (port 53763, 3 instances, --report-at=20 on the host): the third is `--role=rejoiner --designated
## --profile=imp_b --wait=8` and the second (the old imposter) is dropped by the host.
## Exits 0 on pass, 1 on failure or after 50 s.

var I: GDScript  ## game/core/imposter.gd, loaded once the autoloads exist (it names them)
var _role := "honest"
var _n := 2
var _wait := 0.0
var _report_at := 8.0
var _designated := false
var _t := 0.0
var _in_match := -1.0
var _stage := 0
var _target_peer := 0
var _target_uid := ""
var _actions := 0
var _line := ""
var _marked := false  ## host: pegboard_mark done; client: saw exactly one display mark arrive
var _saw_mark := false
var _fails: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): _role = a.substr(7)
		elif a.begins_with("--n="): _n = int(a.substr(4))
		elif a.begins_with("--wait="): _wait = float(a.substr(7))
		elif a.begins_with("--report-at="): _report_at = float(a.substr(12))
		elif a == "--designated": _designated = true
	create_timer(_wait).timeout.connect(func() -> void: change_scene_to_file("res://game/core/boot.tscn"))


func _net() -> Node:
	return root.get_node("Net")


func _end(ok: bool, what: String) -> void:
	print("test_imposter_sync[%s]: %s (%s)" % [_role, "PASS" if ok else "FAIL", what])
	if _role != "host" and ok:  # linger: a client gone first makes the host's sends log "max channels: 0"
		_stage = 9
		create_timer(6.0).timeout.connect(quit.bind(0))
		return
	quit(0 if ok else 1)


func _process(delta: float) -> bool:
	_t += delta
	if I == null:
		I = load("res://game/core/imposter.gd")
		root.get_node("Log").logged.connect(func(n: StringName, _d: Dictionary) -> void:
			if n == &"imposter_action":
				_actions += 1)
		return false
	if _t > 50.0 + _wait:
		_end(false, "timed out, stage %d, me %s" % [_stage, I.me])
		return false
	var game: Node = root.get_node("Game")
	var main := current_scene
	if main != null and main.get_node_or_null("Death") != null:
		_in_match = maxf(_in_match, 0.0) + delta
	if _role == "host":
		_host(game, main)
	else:
		_client(main)
	return false


func _host(game: Node, main: Node) -> void:
	if _stage == 0 and game.in_lobby and game.is_host() and game.humans() >= _n and _net().profiles.size() >= _n:
		I.set_enabled(true)
		for p in _net().profiles:
			if p != 1 and _target_peer == 0:
				_target_peer = p
				_target_uid = _net().profiles[p].uid
		print("test_imposter_sync[host]: ", I.dev_force(str(_target_peer)))
		_stage = 1
	if _stage == 1 and game.in_lobby:
		game.start_match()  # retried until the clip pre-share lets it go
	if _stage == 1 and not game.in_lobby:
		_stage = 2
	if _stage == 2 and _in_match > 5.0:
		if I.uid != _target_uid or I.peer() != _target_peer or I.me or not I.enabled:
			_fails.append("host state: uid %s peer %d me %s" % [I.uid == _target_uid, I.peer(), I.me])
		I.act(1, &"whistle_throw", Vector3(5, 0, 5))  # the host is not the imposter: dropped
		if _actions != 0:
			_fails.append("a non-imposter sender was obeyed")
		I.act(_target_peer, &"whistle_throw", Vector3(500, 0, 500))  # P5-25: no hold begun, dropped
		if _actions != 0:
			_fails.append("an act without a begun hold was obeyed")
		I.begin(1, &"whistle_throw")  # not the imposter: no begin recorded
		I.begin(_target_peer, &"whistle_throw")
		I.act(_target_peer, &"whistle_throw", Vector3(500, 0, 500))  # the hold has not run its time: dropped
		if _actions != 0:
			_fails.append("an act before the hold time was obeyed")
		I.begin(_target_peer, &"whistle_throw")
		I._began_ms[&"whistle_throw"] -= 2000  # the hold has run (host-timed)
		I.act(_target_peer, &"whistle_throw", Vector3(500, 0, 500))
		I.begin(_target_peer, &"whistle_throw")
		I._began_ms[&"whistle_throw"] -= 2000
		I.act(_target_peer, &"whistle_throw", Vector3(5, 0, 5))  # inside the 60 s cooldown: dropped
		if _actions != 1:
			_fails.append("whistle_throw count %d, wanted 1 (sender + cooldown + hold rules)" % _actions)
		var sweep := get_first_node_in_group(&"trap_sweep")
		var slot := get_first_node_in_group(&"pegboard_slots") as Node3D
		if sweep == null or slot == null:
			_fails.append("no pegboard in the match scene")
		else:
			var truth: Array = sweep.filled.duplicate()
			game.players[_target_peer].pos = slot.global_position + Vector3(0, 0, 1.0)
			I.begin(_target_peer, &"pegboard_mark")
			I._began_ms[&"pegboard_mark"] -= 4000
			I.act(_target_peer, &"pegboard_mark", slot.global_position)
			if _actions != 2 or sweep.pegboard_mark.count(true) != 1 or sweep.filled != truth:
				_fails.append("pegboard_mark: actions %d marks %s, filled changed %s" % [_actions, sweep.pegboard_mark, sweep.filled != truth])
			_marked = true
		var debt := get_first_node_in_group(&"debt")
		if debt:
			debt.lost = true  # a missed final payment is the only win
		_line = I.reveal_line()
		if not _line.contains(_net().profiles[_target_peer].name) or not _line.contains("imposter won"):
			_fails.append("reveal line '%s'" % _line)
		_stage = 3
	if _stage == 3 and _in_match > _report_at:
		var rep := {"day": 9, "ledger": [], "sections": [], "final": true, "streamer_safe": false, "imposter_line": _line}
		_net().to_peers(&"apply_dawn_report", [rep])
		_stage = 4
		_in_match = 0.0
	if _stage == 4 and _in_match > 2.0:
		var sw := get_first_node_in_group(&"trap_sweep")
		if sw != null and _marked:  # touching the board resets the lie
			sw.clear_marks()
			if sw.pegboard_mark.has(true):
				_fails.append("clear_marks left a mark")
		_end(_fails.is_empty(), "; ".join(_fails) if not _fails.is_empty() else "line: " + _line)


func _client(main: Node) -> void:
	if _stage == 9:
		return
	if _in_match > 3.0 and _stage == 0:
		_stage = 1
		if I.me != _designated:
			_end(false, "me is %s, wanted %s" % [I.me, _designated])
			return
	if _stage == 1:
		if I.me != _designated:
			_end(false, "me changed to %s" % I.me)
			return
		var sw := get_first_node_in_group(&"trap_sweep")
		if sw != null and sw.pegboard_mark.count(true) == 1:
			_saw_mark = true  # the display lie reached this client (and says nothing of who)
		var rep := _find_label(_dawn(main), "IMPOSTER WAS")
		if rep != "":
			_end(_saw_mark, "me %s, saw mark %s, report '%s'" % [I.me, _saw_mark, rep])


func _dawn(main: Node) -> Node:
	for c in main.get_children():
		if c.get_script() and c.get_script().get_global_name() == &"DawnReport":
			return c
	return main


func _find_label(n: Node, needle: String) -> String:
	if n is Label and (n as Label).text.contains(needle):
		return (n as Label).text
	for c in n.get_children():
		var r := _find_label(c, needle)
		if r != "":
			return r
	return ""
