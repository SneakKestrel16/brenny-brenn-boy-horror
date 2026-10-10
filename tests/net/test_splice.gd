extends SceneTree
## P5-03 unit checks for spliced lures (doc 03 s12.1 "Splice", doc 06 "A lure"): the segment spec on the wire
## and the word-break cut.
##   "$GODOT" --headless --path . -s res://tests/net/test_splice.gd

const Splice := preload("res://game/voice/splice.gd")

var _fails := 0


func _init() -> void:
	var segs := [["live_3", 0, 40], ["live_7", 55, 30]]
	var spec := Splice.segments_spec(segs)
	_check(spec == "live_3@0+40,live_7@55+30", "spec string: " + spec)
	_check(Splice.parse_spec(spec) == segs, "spec round-trips")
	_check(Splice.parse_spec("live_3") == [["live_3", 0, -1]], "a bare id (exact clip) is the whole clip")
	_check(Splice.spec_ids(spec) == ["live_3", "live_7"], "spec ids")
	for bad in ["", "a@0+1,b@0+1,c@0+1", "a@-1+4", "a@0+0", "a@x+4", "a b@0+1", "a@0", "a:1@0+1"]:
		_check(Splice.parse_spec(bad).is_empty(), "malformed spec refused: '%s'" % bad)
	# A loud clip, quiet 5-frame ends, a 4-frame quiet gap at frames 20..23: cut in its middle.
	var sizes := PackedInt32Array()
	for i in 40:
		sizes.append(6 if i < 5 or i >= 35 or (i >= 20 and i < 24) else 60)
	_check(Splice.word_break(sizes) == 22, "cut at the gap's middle (%d)" % Splice.word_break(sizes))
	# The longest gap wins; gaps at the very ends (the pre-roll, the VAD hang) do not count.
	sizes = PackedInt32Array()
	for i in 60:
		sizes.append(5 if i < 5 or i >= 55 or (i >= 10 and i < 12) or (i >= 30 and i < 36) else 70)
	_check(Splice.word_break(sizes) == 33, "longest interior gap (%d)" % Splice.word_break(sizes))
	# No gap: the middle of the clip. One quiet frame is not a word break.
	sizes = PackedInt32Array()
	for i in 31:
		sizes.append(3 if i == 9 else 50)
	_check(Splice.word_break(sizes) == 15, "no gap: mid-clip (%d)" % Splice.word_break(sizes))
	_check(Splice.word_break(PackedInt32Array([40, 40])) == 1, "two frames: cut after the first")
	# P5-19 (Q-291): sizes as measured on TwoVoIP output, silence 24-26 bytes, speech 40-70, median ~40-43.
	# Silent pre-roll and tail, a 4-frame gap at 40..43: cut at 42, not mid-clip (30) as the median rule alone gave.
	var speech := [40, 41, 42, 40, 43, 55, 70, 41, 44, 62]
	sizes = PackedInt32Array()
	for i in 60:
		var silent := i < 5 or i >= 56 or (i >= 40 and i < 44)
		sizes.append(24 + i % 3 if silent else speech[i % speech.size()])
	var sorted := sizes.duplicate()
	sorted.sort()
	_check(sorted[30] >= 40 and sorted[30] <= 43, "measured sizes: median %d as on TwoVoIP" % sorted[30])
	_check(Splice.word_break(sizes) == 42, "measured sizes: cut in the silent gap (%d)" % Splice.word_break(sizes))
	# Uniform clips have no silence to find: mid-clip, never a break on every frame.
	# The last two put the quietest frames off-centre (30..33), so a missing guard shows as a cut at 31 or 32.
	for label: String in ["all 24", "all 50", "all silent 24-26", "all speech 40-70"]:
		sizes = PackedInt32Array()
		for i in 41:
			var low := i >= 30 and i < 34
			match label:
				"all 24": sizes.append(24)
				"all 50": sizes.append(50)
				"all silent 24-26": sizes.append(24 if low else 26)
				_: sizes.append(40 + i % 3 if low else 50 + (i * 7) % 21)
		_check(Splice.word_break(sizes) == 20, "%s: mid-clip (%d)" % [label, Splice.word_break(sizes)])
	# P5-19 QA: VAD-shaped clips (voice.gd: PREROLL_FRAMES 5 before, VAD_HANG_FRAMES 15 + the TALK_END frame
	# after). 80 frames: pre-roll 0..4, speech 5..63, hangover tail 64..79. The tail is never the break.
	var gap := func(i: int) -> bool: return i >= 30 and i < 33
	sizes = _vad_clip(80, gap)
	_check(Splice.word_break(sizes) == 31, "VAD clip: cut in the 3-frame interior gap (%d)" % Splice.word_break(sizes))
	sizes = _vad_clip(80, func(_i: int) -> bool: return false)
	_check(Splice.word_break(sizes) == 34, "VAD clip, edge silence only: middle of speech 5..63 (%d)" % Splice.word_break(sizes))
	# Short VAD clips (CLIP_MIN_FRAMES 25 up): with no gap the cut stays out of the 16-frame hangover.
	for n in range(25, 33):
		var c := Splice.word_break(_vad_clip(n, func(_i: int) -> bool: return false))
		_check(c >= 5 and c < n - 16, "VAD clip n=%d: cut %d before the tail at %d" % [n, c, n - 16])
	# One 3-byte (DTX-like) packet must not drag the floor down and hide a real gap.
	sizes = _vad_clip(80, gap)
	sizes[20] = 3
	_check(Splice.word_break(sizes) == 31, "3-byte packet: cut still in the gap (%d)" % Splice.word_break(sizes))
	_check(Splice.word_break(PackedInt32Array([0, 0, 0, 0])) == 2, "empty packets: mid-clip, no out-of-range scan")
	print("test_splice: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## `n` packet sizes as TwoVoIP cuts them: silent 24-26 bytes for the 5-frame pre-roll, the 16-frame hangover
## tail and every frame `silent_at` names; speech 40-70 (median ~41) elsewhere.
static func _vad_clip(n: int, silent_at: Callable) -> PackedInt32Array:
	var speech := [40, 41, 42, 40, 43, 55, 70, 41, 44, 62]
	var out := PackedInt32Array()
	for i in n:
		var silent: bool = i < 5 or i >= n - 16 or silent_at.call(i)
		out.append(24 + i % 3 if silent else speech[i % speech.size()])
	return out


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
