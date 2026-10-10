extends SceneTree
## P5-03 end to end (QA): a day-4 spliced lure over ENet plays on its target only, and the Dawn Report replays
## the same splice. One script, a mode per instance (`--qa=<mode>`):
##   host    the host's WAV voice cuts live clips; once the client holds 2+ of them, day 4: the creature lures the
##           client until a lure in the host's voice comes out spliced, then dawn. Fails if the host played it.
##   target  client: passes when the spliced lure played here from the segments the host sent and the Dawn
##           Report replayed the same spec.
##   uv run tools/qa/multi.py -n 2 --headless --duration 90 \
##     --args "-s res://tests/net/test_p5_03_e2e.gd -- --host --lobby --lobby-start=2 --port=53201 --profile=qa_a --free-mouse --qa=host --voice-wav=<synthetic.wav>" \
##     --args "-s res://tests/net/test_p5_03_e2e.gd -- --join=127.0.0.1 --port=53201 --profile=qa_b --free-mouse --qa=target"
## The WAV must be synthetic (spikes/voice/make_test_wav.py), kept outside the repo.
## Exits 0 on pass, 1 on failure or after 80 s.

var _mode := ""
var _t := 0.0
var _ev: Array = []
var _step := 0
var _wait := 0.0
var _lure: Array = []  ## target: the spliced lure's args as they arrived
var _spec := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_mode = a.substr(5)
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	root.get_node("Net").apply_received.connect(_on_apply)
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t > 80.0:
		_end(false, "timed out in mode %s at step %d" % [_mode, _step])
		return false
	var main := current_scene
	if main == null or main.get_node_or_null("Creature") == null or (_step == 0 and root.get_node("Game").players.size() < 2):
		return false
	_wait -= delta
	if _wait > 0.0:
		return false
	if _mode == "host":
		_host(main)
	else:
		_target(main)
	return false


func _host(main: Node) -> void:
	var game: Node = root.get_node("Game")
	var clips: Object = root.get_node("Voice").clips
	var cr: Node = main.get_node("Creature")
	var dev: Node = _find(main, "DevConsole")
	match _step:
		0:  # the client must hold 2+ of the host's clips before a splice can play there
			if clips.clip_ids(1).size() >= 2 and clips.all_ready():
				print("test_p5_03_e2e: host clips %s" % [clips.clip_ids(1)])
				print("test_p5_03_e2e: ", dev.run("day 4"))
				_step = 1
		1:
			var c: int = game.players.keys().filter(func(q: int) -> bool: return q != 1)[0]  # ENet peer ids are random
			var spot: Vector3 = (get_nodes_in_group(&"trap_spots")[0] as Node3D).global_position
			_pin(c, spot + Vector3(20.0, 0.0, 0.0))  # 12 to 40 m from the spot (creature.gd LURE_MIN_M, LURE_MAX_M)
			_pin(1, spot + Vector3(-300.0, 0.0, 0.0))  # past COULD_NOT_BE_M and DAY_RULE_M from every spot near the client
			for i in 60:
				var n := _ev.size()
				if not cr._lure_at(c, true):
					continue
				var d: Dictionary = _ev.slice(n).filter(func(e: Array) -> bool: return e[0] == "lure_played")[0][1]
				if d.kind == "clip" and int(d.owner) == 1 and not d.exact:
					_spec = VoiceSplice.segments_spec(d.segments)
					print("test_p5_03_e2e: spliced lure %s after %d tries: %s" % [d.lure_id, i + 1, _spec])
					break
			if _spec.is_empty():
				_end(false, "no spliced lure in 60 tries")
				return
			# Only the spliced lure goes in tonight's report, so REPLAY_CAP cannot drop it behind the earlier tries.
			var dr: Node = _find(main, "DawnReport")
			dr._events = dr._events.filter(func(e: Array) -> bool:
				return e[0] != "lure_played" or (not e[1].exact and VoiceSplice.segments_spec(e[1].segments) == _spec))
			_step = 2
			_wait = 2.0
		2:
			if cr._clip_lures.any(func(e: Array) -> bool: return e[1] == _spec):
				_end(false, "the host played the day lure meant for the client: %s" % [cr._clip_lures])
				return
			print("test_p5_03_e2e: ", dev.run("phase dawn"))
			_step = 3
			_wait = 10.0  # the client checks the report's replay meanwhile
		3:
			var shown := _ev.any(func(e: Array) -> bool: return e[0] == "dawn_report_shown")
			_end(shown, "host stayed silent, dawn report shown %s" % shown)


func _target(main: Node) -> void:
	var clips: Object = root.get_node("Voice").clips
	var cr: Node = main.get_node("Creature")
	var dr: Node = _find(main, "DawnReport")
	match _step:
		0:
			if _lure.is_empty():
				return
			var src: String = _lure[1]
			var parts := src.split(":", true, 2)
			_spec = parts[2]
			var segs: Array = VoiceSplice.parse_spec(_spec)
			var want := 0
			for s: Array in segs:
				want += int(s[2])
			var got: int = clips.packets(int(parts[1]), _spec).size()
			var playing: bool = cr._clip_lures.any(func(e: Array) -> bool: return e[1] == _spec)
			var skipped := _ev.any(func(e: Array) -> bool: return e[0] == "lure_skipped")
			print("test_p5_03_e2e: target heard %s: %d segments, %d frames of %d, playing %s" % [src, segs.size(), got, want, playing])
			if segs.size() != 2 or got != want or want == 0 or not playing or skipped:
				_end(false, "spliced lure did not play here as sent")
				return
			_step = 1
		1:  # the Dawn Report replays it from this machine's copy of the clips
			if dr._playing.any(func(e: Array) -> bool: return e[1] == _spec):
				_end(true, "spliced lure played here and the Dawn Report replayed %s" % _spec)


func _on_apply(what: StringName, args: Array) -> void:
	if what == &"lure" and _mode == "target" and _lure.is_empty() and "@" in String(args[1]):
		_lure = args


func _pin(p: int, at: Vector3) -> void:
	var game: Node = root.get_node("Game")
	game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
	game.players[p].pos = at


## Main's child whose script has this class_name (find_children's type does not see script classes).
func _find(main: Node, cls: String) -> Node:
	for c in main.get_children() if main else []:
		if c.get_script() and c.get_script().get_global_name() == cls:
			return c
	return null


func _end(ok: bool, why: String) -> void:
	print("test_p5_03_e2e: ", "PASS " if ok else "FAIL ", why)
	quit(0 if ok else 1)
