class_name RecordingScreen
extends CanvasLayer
## Doc 06 section 11 "Recording" (P2-03): the staged barn recording, made by `Voice.open_recording()`.
## Flow: intro (names who this machine won't hear, D-011) -> each fixed line from voice_lines.json
## and one per teammate's name, 2 to 3 takes each (the best kept by the P2-12 weights, the rest never
## leave memory) -> barn chatter for Lobby-lines players -> review (play back or delete every clip)
## -> `Voice.clips.share()`. Accepting the first line makes the setting Lobby lines (D-013).
##
## Staging: "lantern_out" blows the barn lantern out (one instant step, doc 07 s4) before
## the prompt; "door_bang" bangs the barn door. The lantern is the LightRig in group `barn_lantern`
## (`LightRig.stage_blown`); until the world has one, a staging rig stands at the marker while this
## screen is open.
##
## Debug (after `--`): `--record-auto` (open at session start, every take, accept, 20 s chatter, done),
## `--record-shot=<png>` (screenshot during the "help me" take), `--clip-wav-out=<path>` (after an auto
## run, decode the kept "help me" through the clip player and write it as WAV, for QA to listen to;
## the path must be outside the repo: no real voices in the repo).

const TAKE_S := 3.0  ## placeholder: long enough for the longest line said slowly
const CUE_LEAD_S := 0.6  ## placeholder: the staged moment lands, then the prompt
const TRIM_PAD_FRAMES := 5  ## 100 ms kept either side of the voiced part, like the VAD pre-roll
const CHATTER_MIN_S := 20.0  ## doc 01 "Barn chatter": 20 to 40 s
const CHATTER_MAX_S := 40.0
const DECIMATE := 12  ## pitch estimate on the left channel at mix rate / 12 (4 kHz at 48 kHz)
const PITCH_MIN_HZ := 70.0
const PITCH_MAX_HZ := 400.0
const PITCH_WINDOW := 200  ## samples per pitch estimate (50 ms at 4 kHz)
const PITCH_MIN_R := 0.5  ## normalised autocorrelation needed to call a window voiced
const BLOW_SFX := "res://assets/audio/sfx_lantern_blow_out.wav"
const BANG_SFX := "res://assets/audio/cre_door_bang_01.wav"

signal _chosen(choice: String)

var _auto := false
var _shot_path := ""
var _wav_out := ""
var _opened_in_lobby := false
var _opened_in_session := false
var _was_console := false
var _closed := false
var _changed := false  ## a clip was saved or deleted: share again on close
var _take := {}  ## the capture in progress: packets, db, pcm, discarded, off
var _stop_pressed := false
var _lantern: LightRig
var _staging: LightRig  ## our own lantern while the world has none
var _title: Label
var _body: Label
var _list: VBoxContainer
var _buttons: HBoxContainer
var _tally: Control


func _ready() -> void:
	layer = 130
	var args := OS.get_cmdline_user_args()
	_auto = args.has("--record-auto")
	_shot_path = Voice._arg(args, "--record-shot")
	_wav_out = Voice._arg(args, "--clip-wav-out")
	_opened_in_lobby = Game.in_lobby
	_opened_in_session = Game.in_session
	_was_console = Game.console_open
	_build()
	Voice.clips.recording = true
	Voice.frame_captured.connect(_on_frame)
	Game.voice_setting_changed.connect(_on_setting_changed)
	Log.event(&"recording_open", {"auto": _auto})
	_flow()


func _flow() -> void:
	await _run()
	_finish()


func _process(_delta: float) -> void:
	if _closed:
		return
	if (_opened_in_lobby and not Game.in_lobby) or (_opened_in_session and not Game.in_session):
		_close()
		return
	Game.console_open = true  # the barn body keeps still while the screen has the keyboard
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # the Player captures it when the lobby loads
	_tally.visible = Voice.capturing
	_find_lantern()  # lit from the start, so the blow-out reads


func _build() -> void:
	var dim := ColorRect.new()  # the lobby labels behind stop competing with the prompt
	dim.color = Color(0, 0, 0, 0.4)  # light enough that the staged blow-out still reads
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.95
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.04, 0.94)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override(&"panel", sb)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()  # title, and the tally at its right in the same row
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 26)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override(&"separation", 12)
	box.add_child(_buttons)
	# Doc 06 s11 "The recording light": a steady tally while capture is live, never blinking.
	var tally := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.75, 0.05, 0.04)
	ts.set_corner_radius_all(6)
	ts.set_content_margin_all(8)
	tally.add_theme_stylebox_override(&"panel", ts)
	var tl := Label.new()
	tl.text = "REC  recording"
	tl.add_theme_font_size_override(&"font_size", 22)
	tally.add_child(tl)
	tally.visible = false
	head.add_child(tally)
	_tally = tally


## Shows a page and waits for one of `options`. Auto runs pick `auto_pick` (or the last option).
func _ask(title: String, text: String, options: Array, auto_pick: String) -> String:
	_title.text = title
	_body.text = text
	_set_buttons(options)
	if _auto:
		_chosen.emit.call_deferred(auto_pick if auto_pick in options else str(options.back()))
	return await _chosen


func _set_buttons(options: Array) -> void:
	for c in _buttons.get_children():
		c.queue_free()
	for o in options:
		var b := Button.new()
		b.text = o
		b.pressed.connect(func() -> void: _chosen.emit(o))
		_buttons.add_child(b)


func _run() -> void:
	await get_tree().process_frame
	Voice.ensure_capture()
	if not Voice.has_capture():
		await _ask("No microphone", "Voice capture isn't running on this machine, so nothing can be recorded.",
				["Close"], "Close")
		return
	var intro := "The creature learns how your voice sounds when you're scared. Say each line when it " \
			+ "appears, like you mean it. A few of them are staged in the barn. You can skip any line, " \
			+ "re-record later from the menu, and play back or delete every clip before the match."
	if await _ask("Record in the barn", intro + _muted_note(), ["Start", "Skip"], "Start") != "Start":
		return
	var scoring := Data.record(&"voice_lines", &"take_scoring")
	var lines := _lines()
	for i in lines.size():
		await _record_line(lines[i], i + 1, lines.size(), scoring)
		if _closed:
			return
	if Game.wire_voice_setting() == "lobby_lines":
		await _chatter()
		if _closed:
			return
	await _review()


## Doc 06 s11 "Lines": the seven fixed lines, then each teammate's name.
func _lines() -> Array:
	var out := []
	for r in Data.records(&"voice_lines"):
		if r.get("kind") == "line":
			out.append({"clip_id": str(r.id), "line_id": str(r.id), "text": str(r.text),
					"cue": str(r.get("staging_cue", "none"))})
	var seen := {Net.player_uid(): true}
	for p in Game.players:
		var prof: Dictionary = Net.profiles.get(p, {})
		var uid := str(prof.get("uid", ""))
		if p == Game.local_peer() or uid.is_empty() or seen.has(uid):
			continue
		seen[uid] = true
		var n := VoiceClips.name_line(uid)
		out.append({"clip_id": n.clip_id, "line_id": n.line_id, "text": "%s!" % prof.get("name", "?"), "cue": "none"})
	return out


## D-011 copy: "While you record, you won't hear: Sam (voice Off)."
func _muted_note() -> String:
	var names: Array = Voice.muted_while_capturing()
	if names.is_empty():
		return ""
	return "\n\nWhile you record, you won't hear: %s." % ", ".join(names.map(func(n: String) -> String:
		return "%s (voice Off)" % n))


func _record_line(line: Dictionary, n: int, total: int, scoring: Dictionary) -> void:
	var takes_min := int(scoring.get("takes_min", 2))
	var takes_max := int(scoring.get("takes_max", 3))
	var takes := []
	var more := true
	while true:
		if more or takes.size() < takes_min:
			more = false
			var t := await _do_take(line, n, total, takes.size() + 1, scoring)
			if _closed:
				return
			if t.discarded:
				var c := await _ask("Take thrown away", "%s switched their voice to Off while you recorded, so that take was deleted." % t.off,
						["Again", "Skip line"], "Again")
				if c != "Again":
					return
				more = true
				continue
			takes.append(t)
			if takes.size() < takes_min:
				continue
		var best: Dictionary = {}
		for t in takes:
			if t.voiced and (best.is_empty() or t.score > best.score):
				best = t
		var opts := []
		if not best.is_empty():
			opts.append("Play kept take")
		if takes.size() < takes_max:
			opts.append("One more take")
		opts.append("Redo")
		if not best.is_empty():
			opts.append("Accept")
		opts.append("Skip line")
		var text := ("Kept the strongest of %d takes." % takes.size()) if not best.is_empty() \
				else "We didn't hear that line. Check your mic and try again."
		var c := await _ask("\"%s\"" % line.text, text, opts, "Accept")
		if _closed:
			return
		match c:
			"Play kept take":
				Voice.clips.play_packets(best.packets)
			"One more take":
				more = true
			"Redo":
				takes.clear()
				more = true
			"Accept":
				_accept(line, best)
				return
			_:
				return


## One take: the staged moment, the prompt with the light on for TAKE_S, then trim and score.
func _do_take(line: Dictionary, n: int, total: int, take: int, scoring: Dictionary) -> Dictionary:
	_set_buttons([])
	_title.text = "Line %d of %d, take %d" % [n, total, take]
	_body.text = "Get ready..."
	await _cue(str(line.cue))
	if _closed:
		return {}
	_body.text = "Say it now:  \"%s\"" % line.text + _muted_note()
	_take = {"packets": [], "db": [], "pcm": [], "discarded": false, "off": ""}
	Voice.set_capturing(true)
	if not _shot_path.is_empty() and line.clip_id == "help_me":
		get_tree().create_timer(1.0).timeout.connect(_screenshot)
	await get_tree().create_timer(TAKE_S).timeout
	Voice.set_capturing(false)
	var t := _take
	_take = {}
	_relight()
	if _closed or t.discarded:
		return t
	_score(t, scoring)
	Log.event(&"take_scored", {"line_id": line.line_id, "take": take, "frames": t.packets.size(),
			"mean_db": snappedf(t.mean_db, 0.1), "pitch_sd": snappedf(t.pitch_sd, 0.01), "score": snappedf(t.score, 0.1)})
	return t


func _accept(line: Dictionary, best: Dictionary) -> void:
	if Voice.clips.save_own(line.clip_id, line.line_id, best.packets) != OK:
		push_warning("RecordingScreen: could not write %s" % line.clip_id)
		return
	_changed = true
	if not bool(Settings.get_value(&"lines_recorded")):
		Settings.set_value(&"lines_recorded", true)
		Settings.save()
	if str(Settings.get_value(&"voice_setting")) != "lobby_lines":
		Game.set_voice_setting("lobby_lines")  # D-013: accepting a line is choosing Lobby lines


func _on_frame(opus: PackedByteArray, db: float, pcm: PackedVector2Array) -> void:
	if _take.is_empty() or not Voice.capturing:
		return
	_take.packets.append(opus)
	_take.db.append(db)
	var dec := PackedFloat32Array()
	dec.resize(pcm.size() / DECIMATE)
	for i in dec.size():
		var s := 0.0
		for j in DECIMATE:
			s += pcm[i * DECIMATE + j].x
		dec[i] = s / DECIMATE  # box filter, enough for a 400 Hz ceiling
	_take.pcm.append(dec)


## D-011: a teammate going Off mid-capture throws the capture away (doc 06 s11).
func _on_setting_changed(peer: int) -> void:
	if _take.is_empty() or peer == Game.local_peer() or Game.voice_setting_of(peer) == "lobby_lines":
		return
	_take.discarded = true
	_take.off = str(Net.profiles.get(peer, {}).get("name", "A teammate"))


## Doc 06 s11 "Takes": trim to the voiced part, score = loudness weight * mean dB of voiced frames
## + pitch weight * standard deviation of the pitch in semitones (P2-12 weights).
func _score(t: Dictionary, scoring: Dictionary) -> void:
	var first := -1
	var last := -1
	var sum_db := 0.0
	var voiced_pcm := PackedFloat32Array()
	for i in t.db.size():
		if t.db[i] >= Voice.VAD_OPEN_DB:
			if first < 0:
				first = i
			last = i
			sum_db += t.db[i]
			voiced_pcm.append_array(t.pcm[i])
	t.voiced = first >= 0
	t.mean_db = -100.0
	t.pitch_sd = 0.0
	t.score = -INF
	if not t.voiced:
		t.packets = []
		return
	t.packets = t.packets.slice(maxi(first - TRIM_PAD_FRAMES, 0), mini(last + TRIM_PAD_FRAMES, t.packets.size() - 1) + 1)
	var voiced_n := 0
	for d in t.db:
		voiced_n += 1 if d >= Voice.VAD_OPEN_DB else 0
	t.mean_db = sum_db / voiced_n
	t.pitch_sd = pitch_spread(voiced_pcm, AudioServer.get_mix_rate() / DECIMATE)
	t.score = float(scoring.get("loudness_weight_per_db", 1.0)) * t.mean_db \
			+ float(scoring.get("pitch_spread_weight_per_semitone", 3.0)) * t.pitch_sd


## Standard deviation (semitones) of the pitch over PITCH_WINDOW windows, by normalised
## autocorrelation. Windows join across trimmed gaps, a small error at each join.
## ponytail: plain autocorrelation, swap for YIN if octave errors show up in playtests.
static func pitch_spread(x: PackedFloat32Array, rate: float) -> float:
	var lag_min := maxi(int(rate / PITCH_MAX_HZ), 1)
	var lag_max := int(rate / PITCH_MIN_HZ)
	var semis := []
	var start := 0
	while start + PITCH_WINDOW + lag_max <= x.size():
		var best_r := 0.0
		var best_lag := 0
		for lag in range(lag_min, lag_max + 1):
			var xy := 0.0
			var xx := 0.0
			var yy := 0.0
			for i in PITCH_WINDOW:
				var a := x[start + i]
				var b := x[start + i + lag]
				xy += a * b
				xx += a * a
				yy += b * b
			var r := xy / sqrt(xx * yy) if xx > 0.0 and yy > 0.0 else 0.0
			if r > best_r:
				best_r = r
				best_lag = lag
		if best_r >= PITCH_MIN_R:
			semis.append(12.0 * log(rate / best_lag / 100.0) / log(2.0))
		start += PITCH_WINDOW
	if semis.size() < 2:
		return 0.0
	var mean := 0.0
	for s in semis:
		mean += s
	mean /= semis.size()
	var v := 0.0
	for s in semis:
		v += (s - mean) * (s - mean)
	return sqrt(v / semis.size())


# --- Barn chatter and review ----------------------------------------------------------------------

func _chatter() -> void:
	while true:
		var c := await _ask("Barn chatter", "Now just talk with everyone for 20 to 40 seconds, about anything. "
				+ "It's kept as barn chatter." + _muted_note(), ["Start", "Skip"], "Start")
		if c != "Start" or _closed:
			return
		_take = {"packets": [], "db": [], "pcm": [], "discarded": false, "off": ""}
		_stop_pressed = false
		_set_buttons([])
		var stop := Button.new()
		stop.text = "Stop"
		stop.disabled = true
		stop.pressed.connect(func() -> void: _stop_pressed = true)
		_buttons.add_child(stop)
		Voice.set_capturing(true)
		var t0 := Time.get_ticks_msec()
		var t := 0.0
		while t < CHATTER_MAX_S and not _closed and not _take.discarded:
			if t >= CHATTER_MIN_S and (_stop_pressed or _auto):
				break
			_body.text = "Recording barn chatter: %d s (stop from 20 s, ends at 40 s)." % int(t)
			stop.disabled = t < CHATTER_MIN_S
			await get_tree().process_frame
			t = (Time.get_ticks_msec() - t0) / 1000.0
		Voice.set_capturing(false)
		var take := _take
		_take = {}
		if _closed:
			return
		if take.discarded:
			if await _ask("Chatter thrown away", "%s switched their voice to Off, so the chatter so far was deleted." % take.off,
					["Again", "Skip"], "Skip") != "Again":
				return
			continue
		if Voice.clips.save_own("chatter_0", "chatter", take.packets) == OK:
			_changed = true
			Log.event(&"chatter_kept", {"frames": take.packets.size()})
		return


func _review() -> void:
	if _auto and not _wav_out.is_empty():
		await _write_wav(_wav_out)
	while not _closed:
		for c in _list.get_children():
			c.queue_free()
		var own := Voice.clips.own_clips()
		for clip in own:
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = "%s  (%.1f s)" % [_clip_label(clip), clip.frames * VoiceClips.FRAME_S]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			for verb in ["Play", "Delete"]:
				var b := Button.new()
				b.text = verb
				b.pressed.connect(func() -> void: _chosen.emit("%s:%s" % [verb, clip.clip_id]))
				row.add_child(b)
			_list.add_child(row)
		var text := "Play back or delete anything before the match." if not own.is_empty() else "Nothing is recorded."
		var c := await _ask("Your clips", text, ["Done"], "Done")
		if c.begins_with("Play:"):
			Voice.clips.play(Game.local_peer(), c.trim_prefix("Play:"))
		elif c.begins_with("Delete:"):
			Voice.clips.delete_own(c.trim_prefix("Delete:"))
			_changed = true
		else:
			for row in _list.get_children():
				row.queue_free()
			return


func _clip_label(clip: Dictionary) -> String:
	if clip.clip_id.begins_with("chatter_"):
		return "Barn chatter"
	if clip.line_id.begins_with("name:"):
		for p in Net.profiles:
			if Net.profiles[p].get("uid") == clip.line_id.trim_prefix("name:"):
				return "\"%s!\"" % Net.profiles[p].get("name", "?")
		return "A teammate's name"
	return "\"%s\"" % Data.record(&"voice_lines", StringName(clip.line_id)).get("text", clip.line_id)


## QA (`--clip-wav-out`): the kept "help me", decoded by the same clip player, written as WAV.
func _write_wav(path: String) -> void:
	var bus := Voice._bus("ClipOut", "Master", true)  # muted like Mic: captured, not heard
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 0.5
	AudioServer.add_bus_effect(bus, cap)
	var pcm := PackedByteArray()
	var p := Voice.clips.play(Game.local_peer(), "help_me", &"ClipOut")
	var end_ms := Time.get_ticks_msec() + int((Voice.clips.packets(Game.local_peer(), "help_me").size() * VoiceClips.FRAME_S + 0.4) * 1000)
	while p and Time.get_ticks_msec() < end_ms:
		await get_tree().process_frame
		for f in cap.get_buffer(cap.get_frames_available()):
			var s := int(clampf(f.x, -1.0, 1.0) * 32767.0)
			pcm.append_array(PackedByteArray([s & 0xFF, (s >> 8) & 0xFF]))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.data = pcm
	var err := wav.save_to_wav(path) if not pcm.is_empty() else ERR_DOES_NOT_EXIST
	Log.event(&"clip_wav_out", {"clip_id": "help_me", "ok": err == OK, "samples": pcm.size() / 2})
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)


func _screenshot() -> void:
	if is_inside_tree():
		get_viewport().get_texture().get_image().save_png(_shot_path)



# --- Staging --------------------------------------------------------------------------------------

func _cue(cue: String) -> void:
	match cue:
		"lantern_out":
			_find_lantern()
			if _lantern:
				_lantern.stage_blown(true)  # one instant step with a smoke puff (doc 07 s4)
			_sfx(BLOW_SFX, false)
		"door_bang":
			_sfx(BANG_SFX, true)
		_:
			await get_tree().create_timer(0.3).timeout
			return
	await get_tree().create_timer(CUE_LEAD_S).timeout


## Lit again after the take, rising once through the rig's slew like a lantern being re-lit.
func _relight() -> void:
	if _lantern and is_instance_valid(_lantern):
		_lantern.stage_blown(false)


## The LightRig in group `barn_lantern` (or under that marker); until the world has one, a staging
## rig at the marker while this screen is open (QUESTIONS: the Level Designer places the real one).
func _find_lantern() -> void:
	if _lantern and is_instance_valid(_lantern):
		return
	for n in get_tree().get_nodes_in_group(&"barn_lantern"):
		var rig: Node = n if n is LightRig else n.find_children("*", "LightRig", true, false).pop_front()
		if rig is LightRig:
			_lantern = rig
			return
	var marker := get_tree().get_first_node_in_group(&"barn_lantern") as Node3D
	if marker == null:
		return
	_lantern = LightRig.new()
	_lantern.name = "StagingLantern"
	_lantern.ground_pool = false
	_lantern.range_m = 6.0
	marker.add_child(_lantern)
	_staging = _lantern



## Placeholder sounds until the Audio Designer's files exist: filtered noise bursts.
func _sfx(path: String, bang: bool) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(path) if ResourceLoader.exists(path) else _noise(bang)
	p.bus = &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func _noise(bang: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * (0.3 if bang else 0.45))
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var a := 0.05 if bang else 0.2
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 18.0) if bang else sin(PI * t / 0.45) * exp(-t * 4.0)
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		data.encode_s16(i * 2, int(clampf(lp * env * (6.0 if bang else 2.0), -1.0, 1.0) * 30000))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _close() -> void:
	if _closed:
		return
	_closed = true
	Voice.set_capturing(false)
	_take = {}
	_relight()
	if _staging and is_instance_valid(_staging):
		_staging.queue_free()
	Voice.clips.recording = false
	Game.console_open = _was_console
	if Game.in_session and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hide()
	_chosen.emit("")


func _finish() -> void:
	_close()
	if _changed:
		Voice.clips.share()
	Log.event(&"recording_closed", {"clips": Voice.clips.own_clips().size()})
	queue_free()
