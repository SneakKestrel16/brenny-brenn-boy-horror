class_name VoiceSplice
extends RefCounted
## P5-03 (doc 03 s12.1 "Splice", doc 06 "A lure"): spliced lures from live clips. Pure statics, no autoloads,
## so the Dawn Report builder and unit tests load it under `-s` (Q-057).
##
## A lure's segments are [[clip_id, first_frame, frame_count], ...]. On the wire they ride in the
## `clip:<owner>:<spec>` source of `apply_lure`: an exact clip's spec is its bare id (unchanged from P2-04);
## a splice's is "a@0+40,b@55+30". Clip ids are ASCII identifiers, so "@", "+" and "," are free.

const BREAK_EDGE_FRAMES := 5  ## doc 03 s12.1 word break: 100 ms kept clear at each end of a clip (placeholder)
const BREAK_MIN_FRAMES := 2  ## a silence gap is 40 ms or more (placeholder)
const BREAK_QUIET_SHARE := 0.5  ## a frame is silent at half the clip's median packet size or less (placeholder)


## Segments to the spec string.
static func segments_spec(segments: Array) -> String:
	var out := PackedStringArray()
	for s: Array in segments:
		out.append("%s@%d+%d" % [s[0], int(s[1]), int(s[2])])
	return ",".join(out)


## The segments a spec names; a bare id is the whole clip (count -1). [] if malformed (a spec from the host
## is still checked: at most 2 segments, doc 03 s12.1).
static func parse_spec(spec: String) -> Array:
	if _valid_id(spec):
		return [[spec, 0, -1]]
	var out := []
	var parts := spec.split(",")
	if parts.size() > 2:
		return []
	for part in parts:
		var at := part.split("@")
		var nums := at[1].split("+") if at.size() == 2 else PackedStringArray()
		if nums.size() != 2 or not _valid_id(at[0]) or not nums[0].is_valid_int() or not nums[1].is_valid_int() \
				or int(nums[0]) < 0 or int(nums[1]) < 1:
			return []
		out.append([at[0], int(nums[0]), int(nums[1])])
	return out


## The clip ids a spec uses (a freed clip stops every lure or replay that uses it).
static func spec_ids(spec: String) -> Array:
	return parse_spec(spec).map(func(s: Array) -> String: return s[0])


## Doc 03 s12.1: the frame to cut a clip at, the word break: the middle of its longest interior silence gap,
## else the middle of the clip. `sizes` are its Opus packet sizes. Inference: VBR Opus spends few bytes on
## silence, so packet size stands in for loudness (there is no PCM decoder here, doc 06 "A lure"); a
## playtest listen settles it. The thresholds are placeholders. Always 1 to size - 1.
static func word_break(sizes: PackedInt32Array) -> int:
	var n := sizes.size()
	if n < 2:
		return 1
	var sorted := sizes.duplicate()
	sorted.sort()
	var quiet: float = sorted[n >> 1] * BREAK_QUIET_SHARE
	var best_len := 0
	var best_start := 0
	var run := 0
	for i in range(BREAK_EDGE_FRAMES, n - BREAK_EDGE_FRAMES):
		run = run + 1 if sizes[i] <= quiet else 0
		if run > best_len:
			best_len = run
			best_start = i - run + 1
	if best_len >= BREAK_MIN_FRAMES:
		return best_start + (best_len >> 1)
	return n >> 1


## The same rule as VoiceClips' clip ids.
static func _valid_id(id: String) -> bool:
	return not id.is_empty() and id.length() <= 64 and id.is_valid_ascii_identifier()
