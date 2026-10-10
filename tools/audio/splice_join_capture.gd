extends SceneTree
## P5-07 splice join check, capture half. Encodes two 3 s windows of synthetic voice WAVs the way voice.gd does
## (TwoVoIP Opus, 24 kbps, RNNoise on), cuts them with VoiceSplice.word_break like creature.gd, plays the splice
## through one AudioStreamOpus (decoder not reset across the join, doc 06 "A lure") and the first clip whole as a
## reference, and records the decoded PCM from a capture bus. Analysis: tools/audio/splice_join_check.py.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tools/audio/splice_join_capture.gd -- <a.wav> <b.wav> <outdir>
## The WAVs must be synthetic (spikes/voice/make_test_wav.py), kept outside the repo. Writes <outdir>/splice.f32,
## <outdir>/ref.f32 (mono float32, 48 kHz) and <outdir>/info.json.

const RATE := 48000
const FRAME := 960

var _dir := ""
var _clips: Array = []  ## [{packets, sizes}]
var _job := 0
var _cap: AudioEffectCapture
var _player: AudioStreamPlayer
var _pcm := PackedFloat32Array()
var _info := {}
var _end_t := 0.0
var _total := 0.0
var _jobs: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("usage: -- <a.wav> <b.wav> <outdir>")
		quit(1)
		return
	_dir = a[2]
	DirAccess.make_dir_recursive_absolute(_dir)
	var starts := [1.0, 5.0]  # window starts in s; the synthetic voice has pauses between phrases
	for i in 2:
		_clips.append(_encode(a[i], starts[i]))
	var ca: Dictionary = _clips[0]
	var cb: Dictionary = _clips[1]
	var ka := VoiceSplice.word_break(ca.sizes)
	var kb := VoiceSplice.word_break(cb.sizes)
	if a.size() >= 5:  # forced cut frames, e.g. mid-voiced for a worst case: -- a b outdir <cut_a> <cut_b>
		ka = int(a[3])
		kb = int(a[4])
	_info = {"a_frames": ca.packets.size(), "b_frames": cb.packets.size(), "break_a": ka, "break_b": kb,
			"a_sizes": Array(ca.sizes), "b_sizes": Array(cb.sizes)}
	var sp: Array = ca.packets.slice(0, ka) + cb.packets.slice(kb)
	_info["join_sample"] = ka * FRAME
	_jobs = [["splice", sp], ["ref", ca.packets]]
	var idx := AudioServer.bus_count
	AudioServer.add_bus()
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 4.0
	AudioServer.add_bus_effect(idx, _cap)
	AudioServer.set_bus_name(idx, "Cap")
	_start_job.call_deferred()


func _encode(path: String, start_s: float) -> Dictionary:
	var wav := AudioStreamWAV.load_from_file(path)
	var raw := wav.data  # 16-bit mono
	var from := int(start_s * wav.mix_rate) * 2
	var enc := TwovoipOpusEncoder.new()
	enc.initialize(RATE, RATE, 1, TwovoipOpusEncoder.DENOISER_RNNOISE, TwovoipOpusEncoder.AGC_DISABLED, FRAME)
	enc.create_opus_encoder(24000, 8, true)
	var need := enc.get_required_input_chunk_size()
	var packets: Array = []
	var sizes := PackedInt32Array()
	var pos := from
	for f in 150:
		var chunk := PackedVector2Array()
		chunk.resize(need)
		for i in need:
			var v := raw.decode_s16(pos) / 32768.0
			pos += 2
			chunk[i] = Vector2(v, v)
		enc.process_chunk(chunk)
		var p := enc.encode_chunk()
		packets.append(p)
		sizes.append(p.size())
	return {"packets": packets, "sizes": sizes}


func _start_job() -> void:
	if _job >= _jobs.size():
		DirAccess.make_dir_recursive_absolute(_dir)
		var f := FileAccess.open(_dir + "/info.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(_info))
		f.close()
		print("capture done: ", _info.keys())
		quit(0)
		return
	var pk: Array = _jobs[_job][1]
	var s := AudioStreamOpus.new()
	s.opus_sample_rate = RATE
	s.opus_channels = 1
	s.buffer_length = pk.size() * 0.02 + 0.5
	_player = AudioStreamPlayer.new()
	_player.stream = s
	_player.bus = "Cap"
	root.add_child(_player)
	_player.play()
	var pb := _player.get_stream_playback() as AudioStreamPlaybackOpus
	for p: PackedByteArray in pk:
		pb.push_opus_packet(p, 0, 0)
	pb.mark_end_opus_stream(true)
	_pcm = PackedFloat32Array()
	_end_t = pk.size() * 0.02 + 0.6
	_cap.clear_buffer()


func _process(delta: float) -> bool:
	_total += delta
	if _total > 30.0:
		push_error("splice_join_capture: timed out")
		quit(1)
		return true
	if _player == null:
		return false
	var n := _cap.get_frames_available()
	if n > 0:
		for v in _cap.get_buffer(n):
			_pcm.append(v.x)
	_end_t -= delta
	if _end_t <= 0.0:
		var f := FileAccess.open("%s/%s.f32" % [_dir, _jobs[_job][0]], FileAccess.WRITE)
		f.store_buffer(_pcm.to_byte_array())
		f.close()
		_info[_jobs[_job][0] + "_samples"] = _pcm.size()
		_player.queue_free()
		_player = null
		_job += 1
		_start_job()
	return false
