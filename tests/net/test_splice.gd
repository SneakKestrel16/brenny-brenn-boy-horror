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
	# A loud clip with a 4-frame quiet gap at frames 20..23: cut in its middle.
	var sizes := PackedInt32Array()
	for i in 40:
		sizes.append(6 if i >= 20 and i < 24 else 60)
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
	print("test_splice: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
