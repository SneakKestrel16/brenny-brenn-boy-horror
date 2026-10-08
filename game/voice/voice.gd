extends Node
## Doc 06 section 8: the voice pipeline. Autoload `Voice` (CONTRACTS section 8), runs on every peer.
## Capture -> Opus -> one frame per 20 ms on channel 2 to the host; the host reads the volume byte,
## relays the frame (volume dropped) to every other peer and reports the loudest byte per speaker to
## `NoiseBus.emit_voice` every 100 ms. Each receiver plays a speaker through the `VoiceEmitter` on
## that speaker's Player node. Moved from spikes/voice/spike_voice.gd and voice_spike.gd (PP-02).
##
## Capture: an AudioStreamPlayer plays the mic (or a looping WAV, `--voice-wav <path>`) into the muted
## `Mic` bus holding an AudioEffectCapture, so everything after the capture is the same for both.
## Nothing is stored: no audio and no volume reaches disk or the log (doc 01 "Senses").
##
## User args (after `--`): `--voice-wav <path>` (or `=path`), `--ptt` (start in push-to-talk),
## `--voice-off` (no capture at all), `--voice-setting=<off|lobby_lines|unchosen>` (QA: this run's
## setting, in memory; two local copies share one settings file), `--voice-off-after=<s>` (switches to
## Off that many seconds into the session, as the menu does: deletes this profile's clips).
##
## P2-03 (doc 06 s11): `clips` (VoiceClips) holds the recorded lines and the pre-share; the recording
## screen opens on `Game.recording_requested`, and in the lobby for players who haven't chosen Off and
## have no lines (a window only). While `capturing`, no Off player's voice plays here (D-011) and the recording light
## shows on this player's character for everyone (`apply_recording_light`).
##
## P3-10 (doc 06 s9): each emitter plays on a `VoiceChain` bus with the crackle layer; a dead speaker heard by
## a living listener plays on `VoiceGhost` with the static layer (`hears_static`); ghosts hear each other clean.
## The layers run only while the speaker talks. The host logs each ghost talk spurt as `ghost_action`
## `static_voice`; ghost frames still never feed the creature (D-011).
##
## Not built yet (doc 06 sections 10 to 12): the radio bus, walkies, mic check (NORMAL_DB is a fixed placeholder).

## Doc 06 section 7 type bytes. 0x01/0x02 were doc 06's, but movement (game/player/move_frame.gd)
## took 1 and 2 on the same `peer_packet` signal; voice moved to 0x10/0x11 (Q-042).
const VOICE_FRAME := 0x10  ## client -> host: type, flags, seq u16, volume, Opus
const VOICE_RELAY := 0x11  ## host -> peers: type, slot, flags, seq u16, Opus
const CHANNEL := 2  ## CONTRACTS section 7

# Doc 06 section 8 "Encode" (placeholders): 48 kHz mono, 20 ms, VOIP, 24 kbps, complexity 8.
const OPUS_RATE := 48000
const FRAME_SAMPLES := 960
const BITRATE := 24000
const COMPLEXITY := 8
## Doc 06 "The volume byte": the player's normal speaking level. No mic check yet, so a fixed
## -20 dBFS RMS stands in (placeholder, as in the spike).
const NORMAL_DB := -20.0
# Doc 06 "Mic modes": VAD opens at normal - 15 dB, holds 300 ms, sends a 100 ms pre-roll.
const VAD_OPEN_DB := NORMAL_DB - 15.0
const VAD_HANG_FRAMES := 15
const PREROLL_FRAMES := 5
const HEARING_EVERY_S := 0.1  ## doc 06 "The volume byte": report at most every 100 ms (placeholder)
const STATS_EVERY_S := 10.0  ## doc 06 section 14

const FLAG_RADIO := 1
const FLAG_TALK_START := 2
const FLAG_TALK_END := 4
const FLAG_GHOST := 8

## Every encoded 20 ms frame, sent or not: the Opus packet, its level and the PCM it came from (the
## recording screen keeps them while capturing).
signal frame_captured(opus: PackedByteArray, db: float, pcm: PackedVector2Array)

var push_to_talk := false  ## doc 01 "Mic mode": open mic with VAD by default
var muted := false
var transmitting := false
var level_db := -100.0
var input_name := "off"
var clips: VoiceClips
## A take or barn chatter is being written on this machine (doc 06 s11 "The recording light").
var capturing := false

# Sender stats since start (`voice_sent`).
var frames_encoded := 0
var frames_sent := 0
var bytes_sent := 0
var talk_spurts := 0

var _capture: AudioEffectCapture
var _source: AudioStreamPlayer
var _encoder: TwovoipOpusEncoder
var _in_chunk := 0
var _seq := 0
var _hang := 0
var _preroll: Array[PackedByteArray] = []  ## [volume byte + Opus], newest last
var _emitters: Dictionary = {}  ## speaker peer -> VoiceEmitter
var _loudest: Dictionary = {}  ## host only: speaker peer -> loudest byte since the last report
var _hearing_t := 0.0
var _stats_t := 0.0
var _relayed := 0
var _lit := {}  ## peer -> true while their recording light is on
var _light_nodes := {}  ## peer -> the light on their character
var _screen: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	push_to_talk = args.has("--ptt")
	# The settings toggle (doc 05 section 16) once Gameplay adds the key (Q-042); `--ptt` until then.
	if Settings.DEFAULTS.has("push_to_talk"):
		push_to_talk = push_to_talk or Settings.get_value(&"push_to_talk") == true
		Settings.changed.connect(func(key: StringName) -> void:
			if key == &"push_to_talk":
				push_to_talk = Settings.get_value(key) == true)
	Net.bytes_received.connect(_on_bytes)
	Game.player_left.connect(_on_player_left)
	Game.player_joined.connect(_on_player_joined)
	clips = VoiceClips.new()
	clips.name = "Clips"
	add_child(clips)
	var vs := _arg(args, "--voice-setting")
	if vs in ["off", "lobby_lines", "unchosen"]:
		Settings.set_value(&"voice_setting", vs)
	Game.recording_requested.connect(open_recording)
	Game.session_started.connect(func() -> void:
		ensure_capture()
		# P2-17: a headless copy never gets the offer. Nobody can press Skip there, so the open screen
		# (ready report "") held the lobby start for ever.
		if args.has("--record-auto") or (Game.in_lobby and should_offer_recording() and DisplayServer.get_name() != "headless"):
			open_recording.call_deferred()
		if _arg(args, "--voice-off-after").is_valid_float():  # QA: the menu's Off, N seconds in
			get_tree().create_timer(float(_arg(args, "--voice-off-after"))).timeout.connect(
					Game.set_voice_setting.bind("off")))


static func _arg(args: PackedStringArray, key: String) -> String:
	for i in args.size():
		if args[i].begins_with(key + "="):
			return args[i].substr(key.length() + 1)
		if args[i] == key and i + 1 < args.size():
			return args[i + 1]
	return ""


static func _bus(bus_name: String, send: String, mute: bool) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	AudioServer.set_bus_mute(idx, mute)
	return idx


## Doc 06 "Capture": starts the mic (or `--voice-wav`) once; the recording screen needs it outside a session too.
func ensure_capture() -> void:
	if _source == null and not OS.get_cmdline_user_args().has("--voice-off"):
		_start_capture(_arg(OS.get_cmdline_user_args(), "--voice-wav"))


func has_capture() -> bool:
	return _encoder != null


## Doc 06 s11 "Before recording": unchosen and Lobby-lines players with no lines are offered it.
func should_offer_recording() -> bool:
	return str(Settings.get_value(&"voice_setting")) != "off" and clips.own_clips().is_empty()


func open_recording() -> void:
	if _screen and is_instance_valid(_screen):
		return
	_screen = RecordingScreen.new()
	add_child(_screen)


## Doc 06 s11 "Recording": a take or the chatter window is being captured on this machine.
func set_capturing(on: bool) -> void:
	if on == capturing:
		return
	capturing = on
	_apply_buses()
	if Game.in_session:
		Net.to_host(&"request_recording_light", [on])


## wav_path empty: the microphone.
func _start_capture(wav_path: String) -> void:
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5  # placeholder
	AudioServer.add_bus_effect(_bus("Mic", "Master", true), _capture)
	# CONTRACTS section 9: VoiceBase sits under `Voice` from the layout file once the Audio Designer
	# ships it; until then under Master. Levels come from game/audio/mix_levels.gd later (Q-033).
	_bus("VoiceBase", "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Master", false)
	_bus("VoiceMuted", "Master", true)  # D-011: Off players while this machine captures (still decoded)
	_source = AudioStreamPlayer.new()
	_source.bus = "Mic"
	if wav_path.is_empty():
		_source.stream = AudioStreamMicrophone.new()
		input_name = "mic"
	else:
		var wav := AudioStreamWAV.load_from_file(wav_path) if FileAccess.file_exists(wav_path) else null
		if wav == null:
			push_warning("Voice: cannot read --voice-wav %s; voice off" % wav_path)
			return
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_source.stream = wav
		input_name = "wav"  # the file name is not logged: it could name a person
	add_child(_source)
	_source.play()
	var enc := TwovoipOpusEncoder.new()
	# Capture runs at the output mix rate; TwoVoIP resamples to 48 kHz. RNNoise on, AGC off (doc 06).
	if enc.initialize(int(AudioServer.get_mix_rate()), OPUS_RATE, 1, TwovoipOpusEncoder.DENOISER_RNNOISE,
			TwovoipOpusEncoder.AGC_DISABLED, FRAME_SAMPLES) != OK or not enc.create_opus_encoder(BITRATE, COMPLEXITY, true):
		push_warning("Voice: Opus encoder failed to start; voice off")
		return
	_encoder = enc
	_in_chunk = _encoder.get_required_input_chunk_size()
	Log.event(&"voice_capture", {"input": input_name, "mix_rate": int(AudioServer.get_mix_rate()),
			"push_to_talk": push_to_talk})


func _process(delta: float) -> void:
	if _encoder:
		_pump_capture()
	if not Game.in_session:
		return
	_attach_emitters()
	_apply_buses()
	_show_lights()
	if Game.is_host():
		_hearing_t += delta
		if _hearing_t >= HEARING_EVERY_S:
			_hearing_t = 0.0
			_report_hearing()
	_stats_t += delta
	if _stats_t >= STATS_EVERY_S:
		_stats_t = 0.0
		log_stats()


# --- Send ---------------------------------------------------------------------------------------

func _wants_to_talk(db: float) -> bool:
	if muted:
		return false
	if push_to_talk:
		return Input.is_action_pressed(&"voice_push_to_talk")
	if db >= VAD_OPEN_DB:
		_hang = VAD_HANG_FRAMES
		return true
	if _hang > 0:
		_hang -= 1
		return true
	return false


func _pump_capture() -> void:
	while _capture.get_frames_available() >= _in_chunk:
		var chunk := _capture.get_buffer(_in_chunk)
		if _encoder.process_chunk(chunk) < 0:
			break
		var rms := _encoder.get_rms()
		level_db = linear_to_db(rms) if rms > 0.0 else -100.0
		# The encoder runs on every frame, sending or not, so the pre-roll is real audio.
		var opus := _encoder.encode_chunk()
		frames_encoded += 1
		frame_captured.emit(opus, level_db, chunk)
		if not Game.in_session:
			continue
		var vol := volume_byte(level_db)
		var talk := _wants_to_talk(level_db)
		if talk and not transmitting:
			talk_spurts += 1
			var first := true
			for old in _preroll:
				_emit(old.slice(1), old[0], FLAG_TALK_START if first else 0)
				first = false
			_emit(opus, vol, FLAG_TALK_START if first else 0)
		elif talk:
			_emit(opus, vol, 0)
		elif transmitting:
			_emit(opus, vol, FLAG_TALK_END)
		transmitting = talk
		var entry := PackedByteArray([vol])
		entry.append_array(opus)
		_preroll.append(entry)
		if _preroll.size() > PREROLL_FRAMES:
			_preroll.pop_front()


## Doc 06 "The volume byte": clamp(round((db_rel + 30) * 255 / 48), 1, 255). 0 means not sending.
static func volume_byte(db: float) -> int:
	return clampi(roundi((db - NORMAL_DB + 30.0) * 255.0 / 48.0), 1, 255)


func _emit(opus: PackedByteArray, vol: int, flags: int) -> void:
	var f := PackedByteArray([VOICE_FRAME, flags, (_seq >> 8) & 0xFF, _seq & 0xFF, vol])
	f.append_array(opus)
	_seq = (_seq + 1) & 0xFFFF
	frames_sent += 1
	bytes_sent += f.size()
	if Game.is_host():
		_take(1, f)  # the host's own frames take the same path minus the network hop
	else:
		Net.send_bytes(1, f, CHANNEL)


# --- Host relay ---------------------------------------------------------------------------------

## Doc 06 "Host relay": the sender is keyed by the transport id, never by the header. Read the volume,
## send the relay form (volume dropped, ghost bit from the host's own state) to every other peer.
func _take(from: int, f: PackedByteArray) -> void:
	var slot := Game.players.keys().find(from)
	if slot < 0:
		return
	var ghost := Game.is_ghost(from)
	if not ghost:  # D-011: ghosts never feed the creature
		_loudest[from] = maxi(int(_loudest.get(from, 0)), f[4])
	elif f[1] & FLAG_TALK_START:  # doc 09 s13: a ghost talk spurt, tallied with the ghost powers
		Log.event(&"ghost_action", {"kind": "static_voice", "peer": from})
	# No walkies in DD Phase 1, so the radio bit is never valid yet (doc 06 section 7 check).
	var flags := (f[1] & ~FLAG_RADIO) | (FLAG_GHOST if ghost else 0)
	var relay := PackedByteArray([VOICE_RELAY, slot, flags, f[2], f[3]])
	relay.append_array(f.slice(5))
	for id in multiplayer.get_peers():
		if id != from:
			Net.send_bytes(id, relay, CHANNEL)
	_relayed += 1
	if from != 1:
		_play(from, flags, (f[2] << 8) | f[3], f.slice(5))


## Every 100 ms: the loudest byte per speaker at the host's copy of their position. Not logged, not kept.
func _report_hearing() -> void:
	for peer in _loudest:
		var st: Dictionary = Game.players.get(peer, {})
		if st.has("pos"):
			NoiseBus.emit_voice(st.pos, _loudest[peer], peer)
	_loudest.clear()


# --- Receive ------------------------------------------------------------------------------------

func _on_bytes(from: int, pkt: PackedByteArray) -> void:
	if pkt.size() <= 5:
		return
	if pkt[0] == VOICE_FRAME and Game.is_host() and Game.players.has(from):
		_take(from, pkt)
	elif pkt[0] == VOICE_RELAY and not Game.is_host() and from == 1:
		var keys := Game.players.keys()
		if pkt[1] < keys.size():
			_play(keys[pkt[1]], pkt[2], (pkt[3] << 8) | pkt[4], pkt.slice(5))


func _play(speaker: int, flags: int, seq: int, opus: PackedByteArray) -> void:
	var e := _emitter(speaker)
	if e:
		e.receive(flags, seq, opus)


## The speaker's emitter, or null once its body is gone (a scene change frees it before
## _attach_emitters runs; assigning the freed object to a typed variable is a SCRIPT ERROR).
func _emitter(peer: int) -> VoiceEmitter:
	var e: Variant = _emitters.get(peer)
	return e if is_instance_valid(e) else null


## Adds a VoiceEmitter to each remote player's node once the Players node has spawned it.
func _attach_emitters() -> void:
	var players := get_tree().current_scene.get_node_or_null("Players") if get_tree().current_scene else null
	if players == null:
		return
	for peer in Game.players:
		if peer == Game.local_peer() or (_emitters.has(peer) and is_instance_valid(_emitters[peer])):
			continue
		var body: Node = players.player(peer)
		if body:
			var e := VoiceEmitter.new(peer, &"VoiceBase")
			body.add_child(e)
			VoiceChain.attach_crackle(e, &"none", e.bus)  # doc 06 s9: every proximity voice crackles faintly
			_emitters[peer] = e


func _on_player_left(peer: int) -> void:
	var e := _emitter(peer)
	if e:
		Log.event(&"voice_stats", e.stats())
	_emitters.erase(peer)
	_loudest.erase(peer)
	_lit.erase(peer)


# --- The voice chain, capture mute and the recording light (doc 06 s9 and s11, D-011) -------------

## Doc 06 s9 "Who hears ghosts": a dead speaker's voice reaches a living listener only through the ghost
## static; ghosts hear each other clean. The same test picks the chain for a fake in that voice (doc 01 "The
## dead-voice twist"), so static alone never tells a real ghost from the creature.
func hears_static(speaker: int) -> bool:
	return Game.is_ghost(speaker) and not Game.is_ghost(Game.local_peer())


## Each emitter's bus and layers: muted while capturing for every speaker who isn't Lobby lines (Off,
## unchosen, unknown), else the ghost static chain or the base chain. The layers play only while the speaker talks.
func _apply_buses() -> void:
	for peer in _emitters:
		var e := _emitter(peer)
		if e == null:
			continue
		var ghost := hears_static(peer)
		var want := VoiceChain.bus_for(&"none", ghost)
		if capturing and Game.voice_setting_of(peer) != "lobby_lines":
			want = &"VoiceMuted"
		var st := e.get_node_or_null(^"GhostStatic")
		if ghost and st == null:
			VoiceChain.attach_static(e, want)
		elif not ghost and st:
			st.free()
		if e.bus != want:
			e.bus = want
		for layer in e.get_children():
			if layer is AudioStreamPlayer3D:
				layer.bus = want
				layer.stream_paused = not e.talking()


## Names of the players this machine won't hear while it captures (the recording screen lists them).
func muted_while_capturing() -> Array:
	var out := []
	for p in Game.players:
		if p != Game.local_peer() and Game.voice_setting_of(p) != "lobby_lines":
			out.append(str(Net.profiles.get(p, {}).get("name", "Player %d" % p)))
	return out


## Host: the owner says capture is live (or not); the owner's machine is the authority.
func on_recording_light_request(peer: int, on: bool) -> void:
	if not Game.is_host() or not Game.players.has(peer):
		return
	apply_recording_light(peer, on)
	Net.to_peers(&"apply_recording_light", [peer, on])
	Log.event(&"recording_light", {"player": peer, "on": on})


func apply_recording_light(peer: int, on: bool) -> void:
	if on:
		_lit[peer] = true
	else:
		_lit.erase(peer)


func _on_player_joined(peer: int) -> void:
	if Game.is_host() and peer != 1:
		for p in _lit:
			Net.to_peers(&"apply_recording_light", [p, true], [peer])


## A steady red tally lamp over each recording player's head (doc 06 s11): an emissive bulb, not a
## light, so it stays outside the light rules (doc 07 s4.4); on for the whole capture, then gone.
func _show_lights() -> void:
	for peer in _light_nodes.keys():
		if not _lit.has(peer) or not is_instance_valid(_light_nodes[peer]):
			if is_instance_valid(_light_nodes[peer]):
				_light_nodes[peer].queue_free()
			_light_nodes.erase(peer)
	var players := get_tree().current_scene.get_node_or_null("Players") if get_tree().current_scene else null
	if players == null:
		return
	for peer in _lit:
		var body: Node = players.player(peer)
		if peer == Game.local_peer() or _light_nodes.has(peer) or body == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.1, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.1, 0.08)
		mat.emission_energy_multiplier = 4.0
		var m := SphereMesh.new()
		m.radius = 0.06
		m.height = 0.12
		m.material = mat
		var lamp := MeshInstance3D.new()
		lamp.name = "RecordingLight"
		lamp.mesh = m
		lamp.position = Vector3(0, 2.05, 0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(lamp)
		_light_nodes[peer] = lamp


# --- Logs ---------------------------------------------------------------------------------------

## Doc 06 section 14: `voice_sent` for this machine's mic and `voice_stats` per speaker heard.
func log_stats() -> void:
	Log.event(&"voice_sent", {"input": input_name, "encoded": frames_encoded, "sent": frames_sent,
			"bytes": bytes_sent, "talk_spurts": talk_spurts, "push_to_talk": push_to_talk,
			"relayed": _relayed})
	for e in _emitters.values():
		if is_instance_valid(e):
			Log.event(&"voice_stats", e.stats())


func _exit_tree() -> void:
	# Drop every handle to the mic stream and its playback, or they are still referenced at quit (P1-06).
	# The AudioServer releases a stopped playback only on its next mix step, and at quit none may come,
	# so wait (at most 200 ms) for the playback to go. Measured: without the wait both leak at exit.
	if _source:
		var playback: WeakRef = weakref(_source.get_stream_playback()) if _source.has_stream_playback() else null
		_source.stop()
		_source.stream = null
		_source.free()
		_source = null
		var waited := 0
		while playback and playback.get_ref() != null and waited < 200:
			OS.delay_msec(5)
			waited += 5
	if _capture:
		var bus := AudioServer.get_bus_index("Mic")
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, i) == _capture:
				AudioServer.remove_bus_effect(bus, i)
		_capture = null
	_encoder = null
