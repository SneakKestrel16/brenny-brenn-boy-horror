extends Node3D
## Doc 01 "Testing" (Phase 1 gate), doc 05 section 20 step 8, doc 09 section 5: can a tester place a
## voice and a whistle at 10, 30 and 60 m by ear. Standalone scene:
##   godot --path . res://game/debug/spatial_audio_test.tscn [-- --trials=<per cell> --seed=<n> --auto-pick]
## The tester stands at `audio_listener` with a random heading each trial, sees the three candidate
## posts (not which one plays), hears ONE sound once, and picks 1/2/3 (near to far). Each pick logs
## `spatial_audio_trial` (doc 05 section 18). The tester turns with the mouse to face the sound before
## picking: `angle_error_deg` is the horizontal angle between that facing and the true source.
## (The three sources are collinear with the listener, so a marker pick alone has no angle.)
## Sources: voice = a synthetic vowel-buzz line (no real person's voice; `--voice-wav=<path>` swaps in
## a CEO-approved file), whistle = a synthetic chirp stand-in until the Audio Designer's `sfx_whistle`
## exists. Attenuation as doc 09 section 5: voice inverse distance unit 6 m max 80 m (doc 06 section 8);
## whistle unit 20 m max 220 m (doc 08, placeholder). `--auto-pick` answers at random, for headless runs.

const SOUNDS: Array[StringName] = [&"voice", &"whistle"]
const MARKER_IDS: Array[StringName] = [&"audio_10m", &"audio_30m", &"audio_60m"]
const DISTANCES := [10, 30, 60]
const REST_AFTER := 18  ## doc 09 section 5: rest after 18 of 36
const MIX := 44100
const EYE := 1.65  ## CONTRACTS section 4

var _per_cell := 6  ## doc 09 section 5 (placeholder)
var _auto := false
var _rng := RandomNumberGenerator.new()
var _trials: Array[Dictionary] = []
var _i := -1
var _cam: Camera3D
var _label: Label
var _markers: Dictionary = {}  ## id -> Marker3D
var _player: AudioStreamPlayer3D
var _streams: Dictionary = {}
var _state := "intro"  ## intro, listening, rest, done
var _correct := 0
var _pick_t := -1.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seeded := false
	for a in args:
		if a.begins_with("--trials="):
			_per_cell = int(a.substr(9))
		elif a.begins_with("--seed="):
			_rng.seed = int(a.substr(7))
			seeded = true
	if not seeded:
		_rng.randomize()
	_auto = args.has("--auto-pick")
	if Log.session_id.is_empty():  # standalone: Boot did not open a session log
		Log.open("audiotest_%s" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_"), 1)
	var farm := (load("res://game/world/farm_phase1.tscn") as PackedScene).instantiate()
	add_child(farm)
	for m in get_tree().get_nodes_in_group(&"spatial_audio_markers"):
		_markers[StringName(m.name)] = m
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.9)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for id in MARKER_IDS:  # a post and a number per candidate, the same for every trial
		var m: Marker3D = _markers[id]
		var cyl := CylinderMesh.new()
		cyl.height = 4.0
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		var post := MeshInstance3D.new()
		post.mesh = cyl
		post.position = m.global_position + Vector3(0, 2, 0)
		add_child(post)
		var tag := Label3D.new()
		tag.text = str(MARKER_IDS.find(id) + 1)
		tag.pixel_size = 0.03
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.position = m.global_position + Vector3(0, 5, 0)
		add_child(tag)
	_cam = Camera3D.new()
	_cam.position = _markers[&"audio_listener"].global_position + Vector3(0, EYE, 0)
	_cam.far = 400.0
	add_child(_cam)
	_cam.current = true
	_player = AudioStreamPlayer3D.new()
	add_child(_player)
	_streams[&"voice"] = _voice_stream(Voice._arg(args, "--voice-wav"))
	_streams[&"whistle"] = _whistle_stream()
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_label)
	add_child(layer)
	_trials = _build_trials()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show("SPATIAL AUDIO TEST\nWear stereo headphones, left on left.\nEach trial plays ONE sound ONCE.\nTurn to face it, then press 1 (nearest post), 2 or 3 (farthest).\n\nEnter to start (%d trials)" % _trials.size())
	if _auto:
		_start_next.call_deferred()


## Doc 09 section 5: every sound x distance x `_per_cell`, shuffled, no more than 2 in a row from one source.
func _build_trials() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for s in SOUNDS:
		for d in DISTANCES.size():
			for k in _per_cell:
				all.append({"sound": s, "marker": MARKER_IDS[d], "distance_m": DISTANCES[d]})
	for attempt in 500:
		for j in range(all.size() - 1, 0, -1):
			var r := _rng.randi_range(0, j)
			var t := all[j]
			all[j] = all[r]
			all[r] = t
		if _max_run(all) <= 2:
			break
	return all


static func _max_run(t: Array[Dictionary]) -> int:
	var run := 1
	var best := 1
	for j in range(1, t.size()):
		run = run + 1 if t[j].sound == t[j - 1].sound else 1
		best = maxi(best, run)
	return best


func _show(text: String) -> void:
	_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := float(Settings.get_value(&"mouse_sensitivity"))
		_cam.rotation.y -= event.relative.x * s
		_cam.rotation.x = clampf(_cam.rotation.x - event.relative.y * s, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER] and _state in ["intro", "rest"]:
			_start_next()
		elif _state == "listening" and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_pick(event.keycode - KEY_1)
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _start_next() -> void:
	_i += 1
	if _i >= _trials.size():
		_state = "done"
		_show("Done: %d of %d placed correctly.\nThanks. Esc to quit." % [_correct, _trials.size()])
		if _auto:
			get_tree().quit()
		return
	var t := _trials[_i]
	_cam.rotation = Vector3(0, _rng.randf() * TAU, 0)  # random heading (doc 09 section 5)
	_player.global_position = _markers[t.marker].global_position + Vector3(0, EYE, 0)
	_player.stream = _streams[t.sound]
	var voice: bool = t.sound == &"voice"
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_player.unit_size = 6.0 if voice else 20.0
	_player.max_distance = 80.0 if voice else 220.0
	_player.play()
	_state = "listening"
	_pick_t = 0.2
	_show("Trial %d of %d\nPress 1, 2 or 3" % [_i + 1, _trials.size()])


func _process(delta: float) -> void:
	if _auto and _state == "listening":
		_pick_t -= delta
		if _pick_t < 0.0:
			_pick(_rng.randi_range(0, 2))


func _pick(guess: int) -> void:
	var t := _trials[_i]
	var truth: Vector3 = _markers[t.marker].global_position - _markers[&"audio_listener"].global_position
	var fwd := -_cam.global_transform.basis.z
	var err := rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(truth.x, truth.z)))
	var ok: bool = MARKER_IDS[guess] == t.marker
	_correct += int(ok)
	Log.event(&"spatial_audio_trial", {"sound": String(t.sound), "distance_m": t.distance_m, "correct": ok,
			"angle_error_deg": snappedf(absf(err), 0.1), "marker": String(t.marker),
			"guessed_marker": String(MARKER_IDS[guess]), "listener": Game.local_peer()})
	_player.stop()  # once only: a late pick never replays (doc 09)
	_state = "between"
	if _i + 1 == REST_AFTER and _i + 1 < _trials.size():
		_state = "rest"
		_show("Rest. %d of %d done.\nEnter to continue." % [_i + 1, _trials.size()])
		if _auto:
			_start_next.call_deferred()
	else:
		_start_next.call_deferred()


# --- Synthetic sources ---------------------------------------------------------------------------

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for j in samples.size():
		bytes.encode_s16(j * 2, int(clampf(samples[j], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.data = bytes
	return w


## Doc 09 section 5: a generated test voice. Four vowel-ish syllables of a harmonic buzz shaped by
## two formants, 1.4 s. Placeholder for doc 08's stranger line.
func _voice_stream(wav_path: String) -> AudioStream:
	if not wav_path.is_empty() and FileAccess.file_exists(wav_path):
		return AudioStreamWAV.load_from_file(wav_path)
	var vowels := [Vector2(700, 1200), Vector2(300, 2300), Vector2(500, 900), Vector2(400, 1800)]
	var n := int(MIX * 1.4)
	var s := PackedFloat32Array()
	s.resize(n)
	for j in n:
		var t := float(j) / MIX
		var syl := mini(int(t / 0.35), 3)
		var env := sin(PI * fmod(t, 0.35) / 0.35) * 0.6
		var f0 := 120.0 + 20.0 * sin(t * 6.0)
		var v: Vector2 = vowels[syl]
		var acc := 0.0
		for h in range(1, 40):
			var f := f0 * h
			acc += sin(TAU * f * t) / h * (exp(-pow((f - v.x) / 150.0, 2)) + 0.6 * exp(-pow((f - v.y) / 250.0, 2)))
		s[j] = acc * env * 0.5
	return _wav(s)


## Placeholder whistle: a 2 to 3 kHz chirp, 1.1 s (doc 09 section 5).
func _whistle_stream() -> AudioStream:
	var n := int(MIX * 1.1)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for j in n:
		var t := float(j) / n
		phase += TAU * (2000.0 + 1000.0 * sin(PI * t)) / MIX
		s[j] = sin(phase) * sin(PI * t) * 0.5
	return _wav(s)
