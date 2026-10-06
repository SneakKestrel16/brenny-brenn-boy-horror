extends Node
## Voice pipeline for the spike, doc 06 section 8: capture -> Opus -> frames out; frames in ->
## jitter buffer -> one Opus decoder per speaker -> AudioStreamPlayer3D on that speaker's capsule.
##
## Capture: an AudioStreamPlayer plays the mic (AudioStreamMicrophone) or a looping WAV
## (--voice-wav) into a muted "SpikeMic" bus holding an AudioEffectCapture, so everything after the
## capture effect is identical for both inputs (doc 06 "Capture").
## Loss handling is Opus PLC only (DECISIONS D-012: TwoVoIP never turns on in-band FEC). A lost
## frame is concealed by pushing the next packet with decode_fec=1; with no LBRR data in it, libopus
## falls back to PLC for exactly one frame (TwoVoIP src/audio_stream_opus.cpp push_opus_packet).
## Spike code (DECISIONS D-004).

signal frame_ready(frame: PackedByteArray)

# Doc 06 section 8 "Encode" (all placeholder): 48 kHz mono, 20 ms, VOIP, 24 kbps, complexity 8.
const OPUS_RATE := 48000
const FRAME_SAMPLES := 960
const FRAME_S := 0.02
const BITRATE := 24000
const COMPLEXITY := 8
# Doc 06 "The volume byte": normal speaking level. No mic check in the spike, so a fixed
# -20 dBFS RMS stands in for the calibrated level (placeholder).
const NORMAL_DB := -20.0
# Doc 06 "Mic modes": VAD opens at normal - 15 dB, holds 300 ms, sends a 100 ms pre-roll.
const VAD_OPEN_DB := NORMAL_DB - 15.0
const VAD_HANG_FRAMES := 15
const PREROLL_FRAMES := 5
# Doc 06 "Playback": 60 ms jitter target (placeholder).
const JITTER_TARGET_FRAMES := 3
const JITTER_TARGET_S := 0.06
const SPEAKER_SILENT_S := 0.3
# Doc 06 "Playback": inverse distance, unit size 6 m, max 80 m (placeholders).
const UNIT_SIZE := 6.0
const MAX_DISTANCE := 80.0

const FLAG_RADIO := 1
const FLAG_TALK_START := 2
const FLAG_TALK_END := 4

enum MicMode { OPEN, PUSH_TO_TALK }

var mic_mode := MicMode.OPEN
var muted := false
var ptt_held := false
var transmitting := false
var input_name := "mic"
var last_level_db := -100.0

# Sender stats (since start).
var frames_encoded := 0
var frames_sent := 0
var bytes_sent := 0
var talk_spurts := 0
var max_packet_bytes := 0

var _capture: AudioEffectCapture
var _source: AudioStreamPlayer
var _encoder: TwovoipOpusEncoder
var _in_chunk := 0
var _seq := 0
var _hang := 0
var _preroll: Array[PackedByteArray] = []  # [volume byte + opus], newest last
var _was_transmitting := false

# Receive side: one Speaker per remote peer id.
var _speakers: Dictionary = {}  # peer_id -> Speaker
var _in_capture: AudioEffectCapture
var mix_clicks := 0
var mix_max_delta := 0.0
var mix_samples := 0
var _mix_last := 0.0
## Sample-to-sample jump that counts as a click in the received mix (tuned against the 2-instance
## baseline; see spikes/voice/README.md "Measuring crackle").
var click_delta := 0.25


class Speaker:
	var peer_id := 0
	var player: AudioStreamPlayer3D
	var playback: AudioStreamPlaybackOpus
	var frames: Dictionary = {}  # seq -> {"opus": PackedByteArray, "flags": int, "at": float}
	var next_seq := -1
	var state := 0  # 0 idle (paused), 1 buffering, 2 playing
	var buffer_start := 0.0
	var last_frame_at := 0.0
	var received := 0
	var lost := 0
	var late := 0
	var decoded := 0
	var spurts := 0
	var peak := 0.0
	var level := 0.0


func _ready() -> void:
	var mic_idx := _add_bus("SpikeMic", true)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(mic_idx, _capture)
	var in_idx := _add_bus("SpikeVoiceIn", false)
	_in_capture = AudioEffectCapture.new()
	_in_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(in_idx, _in_capture)


func _add_bus(bus_name: String, mute: bool) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_mute(idx, mute)
	return idx


## wav_path empty: microphone. Returns "" or an error message.
func start_capture(wav_path: String, denoise: int) -> String:
	_source = AudioStreamPlayer.new()
	_source.bus = "SpikeMic"
	if wav_path.is_empty():
		_source.stream = AudioStreamMicrophone.new()
		input_name = "mic"
	else:
		if not FileAccess.file_exists(wav_path):
			return "WAV not found: %s" % wav_path
		var wav := AudioStreamWAV.load_from_file(wav_path)
		if wav == null:
			return "Could not read WAV: %s" % wav_path
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_source.stream = wav
		input_name = "wav:" + wav_path.get_file()
	add_child(_source)
	_source.play()

	_encoder = TwovoipOpusEncoder.new()
	var mix_rate := int(AudioServer.get_mix_rate())
	var err := _encoder.initialize(mix_rate, OPUS_RATE, 1, denoise, TwovoipOpusEncoder.AGC_DISABLED,
			FRAME_SAMPLES)
	if err != OK:
		return "TwovoipOpusEncoder.initialize failed: %s" % error_string(err)
	if not _encoder.create_opus_encoder(BITRATE, COMPLEXITY, true):
		return "TwovoipOpusEncoder.create_opus_encoder failed"
	_in_chunk = _encoder.get_required_input_chunk_size()
	print("voice spike: capture %s, mix rate %d Hz, %d input frames per 20 ms chunk, denoise %d"
			% [input_name, mix_rate, _in_chunk, denoise])
	return ""


func _process(_delta: float) -> void:
	if _encoder:
		_pump_capture()
	var now := Time.get_ticks_msec() / 1000.0
	for s: Speaker in _speakers.values():
		_pump_speaker(s, now)
	_measure_mix()


func _wants_to_talk(level_db: float) -> bool:
	if muted:
		return false
	if mic_mode == MicMode.PUSH_TO_TALK:
		return ptt_held
	if level_db >= VAD_OPEN_DB:
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
		last_level_db = linear_to_db(rms) if rms > 0.0 else -100.0
		# The encoder runs on every frame, sending or not, so the pre-roll is real audio.
		var opus := _encoder.encode_chunk()
		frames_encoded += 1
		var vol := volume_byte(last_level_db)
		var talk := _wants_to_talk(last_level_db)
		if talk and not _was_transmitting:
			talk_spurts += 1
			# Pre-roll: the frames just before the VAD opened go first.
			var first := true
			for old in _preroll:
				_emit(old.slice(1), old[0], FLAG_TALK_START if first else 0)
				first = false
			_emit(opus, vol, FLAG_TALK_START if first else 0)
		elif talk:
			_emit(opus, vol, 0)
		elif _was_transmitting:
			_emit(opus, vol, FLAG_TALK_END)
		_was_transmitting = talk
		transmitting = talk
		var entry := PackedByteArray([vol])
		entry.append_array(opus)
		_preroll.append(entry)
		if _preroll.size() > PREROLL_FRAMES:
			_preroll.pop_front()


## Doc 06 "The volume byte": clamp(round((db_rel + 30) * 255 / 48), 1, 255). 0 = not sending.
static func volume_byte(level_db: float) -> int:
	return clampi(roundi((level_db - NORMAL_DB + 30.0) * 255.0 / 48.0), 1, 255)


## Client form, doc 06 "Frame format": type 0x01, flags, seq u16, volume, Opus packet.
func _emit(opus: PackedByteArray, vol: int, flags: int) -> void:
	var f := PackedByteArray([0x01, flags, (_seq >> 8) & 0xFF, _seq & 0xFF, vol])
	f.append_array(opus)
	_seq = (_seq + 1) & 0xFFFF
	frames_sent += 1
	bytes_sent += f.size()
	max_packet_bytes = maxi(max_packet_bytes, opus.size())
	frame_ready.emit(f)


# --- Receive side -------------------------------------------------------------------------------

func add_speaker(peer_id: int, parent: Node3D) -> void:
	if _speakers.has(peer_id):
		return
	var s := Speaker.new()
	s.peer_id = peer_id
	s.player = AudioStreamPlayer3D.new()
	s.player.name = "VoiceEmitter"
	s.player.bus = "SpikeVoiceIn"
	s.player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	s.player.unit_size = UNIT_SIZE
	s.player.max_distance = MAX_DISTANCE
	s.player.position = Vector3(0, 1.65, 0)  # CONTRACTS section 4: eye height
	var stream := AudioStreamOpus.new()
	stream.opus_sample_rate = OPUS_RATE
	stream.opus_channels = 1
	stream.buffer_length = 2.0
	s.player.stream = stream
	parent.add_child(s.player)
	s.player.play()
	s.playback = s.player.get_stream_playback() as AudioStreamPlaybackOpus
	_speakers[peer_id] = s


func remove_speaker(peer_id: int) -> void:
	var s: Speaker = _speakers.get(peer_id)
	if s:
		s.player.queue_free()
		_speakers.erase(peer_id)


func has_speaker(peer_id: int) -> bool:
	return _speakers.has(peer_id)


func speaker_ids() -> Array:
	return _speakers.keys()


## A relayed frame from `peer_id`: flags, seq and the Opus packet (doc 06 relay form, parsed).
func receive(peer_id: int, flags: int, seq: int, opus: PackedByteArray) -> void:
	var s: Speaker = _speakers.get(peer_id)
	if s == null or s.playback == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	s.received += 1
	s.last_frame_at = now
	if s.next_seq < 0:
		s.next_seq = seq
	var diff := ((seq - s.next_seq + 32768) & 0xFFFF) - 32768
	if diff < 0:
		s.late += 1  # arrived after its slot was concealed
		return
	s.frames[seq] = {"opus": opus, "flags": flags, "at": now}


func _pump_speaker(s: Speaker, now: float) -> void:
	if s.playback == null:
		return
	s.level = s.playback.get_chunk_max()
	s.peak = maxf(s.peak, s.level)
	if s.state == 0:
		if s.frames.is_empty():
			return
		s.state = 1
		s.buffer_start = now
		s.spurts += 1
	if s.state == 1:
		if s.frames.size() < JITTER_TARGET_FRAMES and now - s.buffer_start < JITTER_TARGET_S \
				and not _has_talk_end(s):
			return
		_drain(s, now)
		if s.state == 1:  # still mid-spurt (a short spurt may have ended inside the drain)
			s.playback.mark_end_opus_stream(true)  # unpause
			s.state = 2
		return
	if s.state == 2:
		_drain(s, now)
		# Talk-end frame lost: stop waiting after a short silence instead of underflowing forever.
		if s.frames.is_empty() and now - s.last_frame_at > SPEAKER_SILENT_S:
			s.playback.mark_end_opus_stream(false)
			s.state = 0


func _has_talk_end(s: Speaker) -> bool:
	for f: Dictionary in s.frames.values():
		if f["flags"] & FLAG_TALK_END:
			return true
	return false


func _drain(s: Speaker, now: float) -> void:
	while true:
		if s.frames.has(s.next_seq):
			var f: Dictionary = s.frames[s.next_seq]
			s.frames.erase(s.next_seq)
			s.playback.push_opus_packet(f["opus"], 0, 0)
			s.decoded += 1
			s.next_seq = (s.next_seq + 1) & 0xFFFF
			if f["flags"] & FLAG_TALK_END:
				s.playback.mark_end_opus_stream(false)  # pause once the queued audio has played
				s.state = 0
				return
			continue
		if s.frames.is_empty():
			return
		# Gap at next_seq. Declare it lost once a later frame has waited the jitter target.
		var oldest := INF
		var later_seq := -1
		var later_diff := 65536
		for k: int in s.frames:
			oldest = minf(oldest, float(s.frames[k]["at"]))
			var d := (k - s.next_seq) & 0xFFFF
			if d < later_diff:
				later_diff = d
				later_seq = k
		if now - oldest < JITTER_TARGET_S and s.frames.size() < JITTER_TARGET_FRAMES:
			return
		# PLC for the missing frame (no in-band FEC in the packet, so libopus conceals).
		s.playback.push_opus_packet(s.frames[later_seq]["opus"], 0, 1)
		s.lost += 1
		s.next_seq = (s.next_seq + 1) & 0xFFFF


## Received-voice mix: count sample-to-sample jumps above click_delta (crackle proxy).
func _measure_mix() -> void:
	var n := _in_capture.get_frames_available()
	if n <= 0:
		return
	var buf := _in_capture.get_buffer(n)
	for v in buf:
		var x := v.x
		var d := absf(x - _mix_last)
		if d > mix_max_delta:
			mix_max_delta = d
		if d > click_delta:
			mix_clicks += 1
		_mix_last = x
	mix_samples += n


## Per-speaker stats for the voice_stats log event. Resets the decoded-peak meter.
func speaker_stats(peer_id: int) -> Dictionary:
	var s: Speaker = _speakers.get(peer_id)
	if s == null:
		return {}
	var rate := float(OPUS_RATE)
	var out := {
		"speaker": peer_id,
		"received": s.received,
		"lost": s.lost,
		"late": s.late,
		"decoded": s.decoded,
		"talk_spurts": s.spurts,
		"underflow_ms": snappedf(s.playback.get_skips(false) / rate * 1000.0, 0.1),
		"overflow_ms": snappedf(s.playback.get_skips(true) / rate * 1000.0, 0.1),
		"decoded_peak": snappedf(s.peak, 0.001),
	}
	s.peak = 0.0
	return out


func speaker_level(peer_id: int) -> float:
	var s: Speaker = _speakers.get(peer_id)
	return s.level if s else 0.0


## Stop every player before quitting, or the audio server still holds their playbacks at exit
## (ObjectDB leak warning).
func shutdown() -> void:
	if _source:
		_source.stop()
		_source.queue_free()
		_source = null
	for s: Speaker in _speakers.values():
		s.player.stop()
		s.playback = null
	_encoder = null
