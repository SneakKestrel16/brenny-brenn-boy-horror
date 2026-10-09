class_name VoiceEmitter
extends AudioStreamPlayer3D
## Doc 06 section 8 "Playback": the only node that places a voice in 3D. One per remote speaker, a
## child of that speaker's Player node, playing its own TwoVoIP `AudioStreamOpus` (decoders keep
## state and must not be shared). Frames go through a jitter buffer reordered by sequence number;
## loss is concealed by Opus PLC only (D-012). Moved from spikes/voice/spike_voice.gd (PP-02).
##
## Every push happens on the main thread: TwoVoIP v6.5's playback ring has a single producer only
## (doc 06 "Risk: TwoVoIP v6.5 playback thread safety").

const OPUS_RATE := 48000
const JITTER_TARGET_FRAMES := 3  ## doc 06 "Playback": 60 ms target (placeholder)
const JITTER_TARGET_S := 0.06
const SPEAKER_SILENT_S := 0.3  ## talk-end frame lost: stop waiting after this much silence
const UNIT_SIZE := 10.0  ## doc 06 "Playback": inverse distance, unit size 10 m, max 120 m (placeholders; was 6 / 80, playtest 1 said quiet and short)
const MAX_DISTANCE := 120.0
const EYE_HEIGHT := 1.65  ## CONTRACTS section 4

const FLAG_TALK_END := 4

enum { IDLE, BUFFERING, PLAYING }

var speaker := 0  ## peer id of the voice (logs name players by peer id, D-012)
var received := 0
var lost := 0  ## concealed by PLC
var late := 0
var decoded := 0
var talk_spurts := 0
## Start each spurt at its first frame's seq (P4-14 walkie: radio frames are a subset of the speaker's sequence).
var resync := false

var _playback: AudioStreamPlaybackOpus
var _frames: Dictionary = {}  ## seq -> {"opus", "flags", "at"}
var _next_seq := -1
var _state := IDLE
var _buffer_start := 0.0
var _last_frame_at := 0.0


func _init(p_speaker: int, p_bus: StringName) -> void:
	speaker = p_speaker
	name = "VoiceEmitter"
	bus = p_bus
	attenuation_model = ATTENUATION_INVERSE_DISTANCE
	unit_size = UNIT_SIZE
	max_distance = MAX_DISTANCE
	volume_db = float(Settings.get_value(&"voice_gain_db"))  # plain gain, no AGC (doc 06)
	position = Vector3(0, EYE_HEIGHT, 0)
	var s := AudioStreamOpus.new()
	s.opus_sample_rate = OPUS_RATE
	s.opus_channels = 1
	s.buffer_length = 2.0
	stream = s


func _ready() -> void:
	play()
	_playback = get_stream_playback() as AudioStreamPlaybackOpus


## One frame from the relay: flags, seq (u16) and the Opus packet.
func receive(flags: int, seq: int, opus: PackedByteArray) -> void:
	if _playback == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	received += 1
	_last_frame_at = now
	if _next_seq < 0 or (resync and _state == IDLE and _frames.is_empty()):
		_next_seq = seq
	if _seq_diff(seq, _next_seq) < 0:
		late += 1  # arrived after its slot was concealed
		return
	_frames[seq] = {"opus": opus, "flags": flags, "at": now}


## Signed distance from b to a on the u16 sequence ring.
static func _seq_diff(a: int, b: int) -> int:
	return ((a - b + 32768) & 0xFFFF) - 32768


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _state == IDLE:
		if _frames.is_empty():
			return
		_state = BUFFERING
		_buffer_start = now
		talk_spurts += 1
	if _state == BUFFERING:
		if _frames.size() < JITTER_TARGET_FRAMES and now - _buffer_start < JITTER_TARGET_S and not _has_talk_end():
			return
		_drain(now)
		if _state == BUFFERING:  # a short spurt may have ended inside the drain
			_playback.mark_end_opus_stream(true)  # unpause
			_state = PLAYING
		return
	_drain(now)
	if _frames.is_empty() and now - _last_frame_at > SPEAKER_SILENT_S:
		_playback.mark_end_opus_stream(false)  # resets the decoder: talk ends only (doc 06)
		_state = IDLE


func _has_talk_end() -> bool:
	for f: Dictionary in _frames.values():
		if f["flags"] & FLAG_TALK_END:
			return true
	return false


func _drain(now: float) -> void:
	while true:
		if _frames.has(_next_seq):
			var f: Dictionary = _frames[_next_seq]
			_frames.erase(_next_seq)
			_playback.push_opus_packet(f["opus"], 0, 0)
			decoded += 1
			_next_seq = (_next_seq + 1) & 0xFFFF
			if f["flags"] & FLAG_TALK_END:
				_playback.mark_end_opus_stream(false)  # pause once the queued audio has played
				_state = IDLE
				return
			continue
		if _frames.is_empty():
			return
		# Gap at _next_seq: declare it lost once a later frame has waited the jitter target.
		var oldest := INF
		var later_seq := -1
		var later_diff := 65536
		for k: int in _frames:
			oldest = minf(oldest, float(_frames[k]["at"]))
			var d := (k - _next_seq) & 0xFFFF
			if d < later_diff:
				later_diff = d
				later_seq = k
		if now - oldest < JITTER_TARGET_S and _frames.size() < JITTER_TARGET_FRAMES:
			return
		# No in-band FEC in the packet, so decode_fec = 1 makes libopus conceal one frame (PLC).
		_playback.push_opus_packet(_frames[later_seq]["opus"], 0, 1)
		lost += 1
		_next_seq = (_next_seq + 1) & 0xFFFF


## A talk spurt is buffering or playing (the chain's crackle and static layers run only then).
func talking() -> bool:
	return _state != IDLE


## Doc 06 section 14 `voice_stats` data. `bus` is the chain this listener hears the speaker through now.
func stats() -> Dictionary:
	var total := decoded + lost
	return {
		"speaker": speaker, "bus": String(bus), "static": has_node(^"GhostStatic"),
		"received": received, "lost": lost, "late": late, "decoded": decoded,
		"loss": snappedf(lost / float(total), 0.0001) if total > 0 else 0.0,
		"talk_spurts": talk_spurts,
		"underflow_ms": snappedf(_playback.get_skips(false) / float(OPUS_RATE) * 1000.0, 0.1) if _playback else 0.0,
		"overflow_ms": snappedf(_playback.get_skips(true) / float(OPUS_RATE) * 1000.0, 0.1) if _playback else 0.0,
	}


func _exit_tree() -> void:
	stop()  # drop the playback before the audio server outlives it (PP-02 leak)
	_playback = null
