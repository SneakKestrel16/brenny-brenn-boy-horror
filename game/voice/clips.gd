class_name VoiceClips
extends Node
## Doc 06 sections 11 and 12: live clips (D-146, P4-37) and their pre-share, `Voice.clips`.
##
## Voice cuts each clip (at most 3 s of this player's transmitted speech) on the sender's machine and
## hands it to `keep_live`. The owner keeps its clips in memory for the session only, never on disk;
## every other machine, the host included, holds them in memory only too (doc 01 "Voice settings >
## Storage"). Session end, switching to Off and the pause menu's Delete drop them.
##
## Pre-share (doc 06 s12): the owner sends its manifest, then each new clip in 16 KB chunks, on channel 3.
## The host checks ownership, the caps and the bytes, keeps a copy and forwards it to every other
## peer; a late joiner gets everything the host holds. A new manifest replaces the owner's set, so a
## deleted clip is removed the same way. Each client reports a digest of what it holds
## (`request_clips_ready`); `ready_to_start()` holds the match start until every client holds every
## clip or 30 s pass (`Game.match_ready()` calls it).
##
## `.vclip` (little-endian): "VCLP", version u8, Opus rate u32, frame samples u16, bitrate u32,
## frame count u32, clip id (u8 length + UTF-8), line id (u8 length + UTF-8), then each Opus packet
## as a u16 length and its bytes: the same packets the live encoder sends (doc 06 s8). Only the wire
## carries it now; the P2-03 lobby-line files under `user://voice/` are deleted at start.

## `owner_peer`'s clip `clip_id` is gone ("" means all of theirs): a lure or review playing it stops.
signal clip_freed(owner_peer: int, clip_id: String)
## This machine's own clips changed (the pause menu's list).
signal own_changed

const MAGIC := "VCLP"
const VERSION := 1
const CHUNK_BYTES := 16384  ## doc 06 s12 (placeholder)
const MAX_CLIPS := 64  ## per player, doc 06 s12 (placeholder)
const MAX_BYTES := 400 * 1024  ## per player, doc 06 s12 (placeholder)
const SHARE_TIMEOUT_S := 30.0  ## doc 06 s12 step 5 (placeholder)
const FRAME_S := 0.02
const LIVE_LINE := "live"  ## the line id of every live clip: it is speech, not a scripted line

## owner peer -> clip_id -> {line_id, frames, bytes, hash, parts: Array, got: int, data: PackedByteArray or null}
var _store := {}
var _digests := {}  ## host: client peer -> digest last reported
var _dirty := true  ## the client's holdings changed since its last ready report
var _wait_t := -1.0  ## host: seconds the match start has waited, or -1
var _playing: Array = []  ## [owner peer, clip_id, AudioStreamPlayer]
var _own := {}  ## this machine's live clips: clip_id -> .vclip bytes, oldest first
var _sent := {}  ## own clip ids whose chunks this session already sent
var _next := 0  ## the next live clip number


func _ready() -> void:
	Game.player_joined.connect(_on_player_joined)
	Game.player_left.connect(func(p: int) -> void:
		_free(p)
		_digests.erase(p))
	Game.voice_setting_changed.connect(func(p: int) -> void:
		if p != Game.local_peer() and Game.voice_setting_of(p) != "live_clips":
			_free(p))
	Game.session_started.connect(func() -> void:
		_drop_own("session_start")
		share())
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"voice_setting" and str(Settings.get_value(key)) == "off":
			delete_all_own())
	_purge_disk.call_deferred()  # deferred: Net.user_dir() names the profile once the args are read


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		if not _store.is_empty() or not _digests.is_empty() or not _own.is_empty():  # left the session: every clip goes
			for p in _store.keys():
				_free(p)
			_digests.clear()
			_drop_own("session_end")
		_wait_t = -1.0
		return
	if not Game.in_session:
		return
	if _dirty and not Game.is_host():
		_dirty = false
		Net.to_host(&"request_clips_ready", [digest_for(Game.local_peer())])
	if _wait_t >= 0.0:
		_wait_t += delta
		if not Game.in_lobby:
			_wait_t = -1.0
		elif all_ready() or _wait_t >= SHARE_TIMEOUT_S:
			Game.start_match()


# --- Own clips ----------------------------------------------------------------------------------

static func root() -> String:
	return Net.user_dir() + "voice/"


## D-146: the P2-03 lobby lines and barn chatter are not used any more; their files go.
func _purge_disk() -> void:
	var n := 0
	for sub: String in ["lines", "chatter"]:
		var dir := root() + sub
		if not DirAccess.dir_exists_absolute(dir):
			continue  # get_files_at logs an ERROR for a missing folder
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".vclip") and DirAccess.remove_absolute(dir.path_join(f)) == OK:
				n += 1
		DirAccess.remove_absolute(dir)
	if n > 0:
		Log.event(&"clips_deleted", {"reason": "legacy_lines", "clips": n})


## Doc 06 s11 (D-146): a live clip Voice cut from this player's transmitted speech. Kept for the
## session; the oldest go first once a cap (doc 06 s12) would be broken. Shared at once.
func keep_live(packets: Array) -> void:
	var id := "live_%d" % _next
	_next += 1
	_own[id] = encode(id, LIVE_LINE, packets)
	var total := 0
	for d: PackedByteArray in _own.values():
		total += d.size()
	while _own.size() > MAX_CLIPS or total > MAX_BYTES:
		var old: String = _own.keys()[0]
		total -= (_own[old] as PackedByteArray).size()
		stop(Game.local_peer(), old)
		_own.erase(old)
	Log.event(&"live_clip_cut", {"clip_id": id, "frames": packets.size(), "bytes": (_own[id] as PackedByteArray).size(), "kept": _own.size()})
	own_changed.emit()
	share()


## The pause menu's Delete: the clip goes here and, through a new manifest, everywhere.
func delete_own(clip_id: String) -> void:
	stop(Game.local_peer(), clip_id)
	if _own.erase(clip_id):
		Log.event(&"clips_deleted", {"reason": "player", "clips": 1})
		own_changed.emit()
		share()


## Doc 06 s11 "Off deletes them": every kept clip, then an empty manifest.
func delete_all_own() -> void:
	_drop_own("voice_off")
	share()


func _drop_own(reason: String) -> void:
	_sent.clear()
	if _own.is_empty():
		return
	stop(Game.local_peer())
	Log.event(&"clips_deleted", {"reason": reason, "clips": _own.size()})
	_own.clear()
	own_changed.emit()


func has_kept() -> bool:
	return not _own.is_empty()


## This machine's clips: [{clip_id, line_id, frames, bytes, hash, data}], oldest first.
func own_clips() -> Array:
	var out := []
	for id: String in _own:
		var data: PackedByteArray = _own[id]
		out.append({"clip_id": id, "line_id": LIVE_LINE, "frames": (decode(data).get("packets", []) as Array).size(),
				"bytes": data.size(), "hash": _md5(data), "data": data})
	return out


func has_own(clip_id: String) -> bool:
	return _own.has(clip_id)


static func encode(clip_id: String, line_id: String, packets: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_data(MAGIC.to_ascii_buffer())
	b.put_u8(VERSION)
	b.put_u32(Voice.OPUS_RATE)
	b.put_u16(Voice.FRAME_SAMPLES)
	b.put_u32(Voice.BITRATE)
	b.put_u32(packets.size())
	for s in [clip_id, line_id]:
		var u := (s as String).to_utf8_buffer()
		b.put_u8(u.size())
		b.put_data(u)
	for p: PackedByteArray in packets:
		b.put_u16(p.size())
		b.put_data(p)
	return b.data_array


## Parses a `.vclip`; {} if it is malformed (clips from the network are untrusted).
static func decode(data: PackedByteArray) -> Dictionary:
	var b := StreamPeerBuffer.new()
	b.data_array = data
	if data.size() < 19 or data.slice(0, 4).get_string_from_ascii() != MAGIC:
		return {}
	b.seek(4)
	if b.get_u8() != VERSION or b.get_u32() != Voice.OPUS_RATE or b.get_u16() != Voice.FRAME_SAMPLES:
		return {}
	b.get_u32()  # bitrate: informational
	var n := b.get_u32()
	var ids := []
	for i in 2:
		var size := b.get_u8()
		if b.get_available_bytes() < size:
			return {}
		ids.append((b.get_data(size)[1] as PackedByteArray).get_string_from_utf8())
	var packets: Array[PackedByteArray] = []
	for i in n:
		if b.get_available_bytes() < 2:
			return {}
		var size := b.get_u16()
		if size == 0 or b.get_available_bytes() < size:
			return {}
		packets.append(b.get_data(size)[1])
	if b.get_available_bytes() != 0 or not _valid_id(ids[0]):
		return {}
	return {"clip_id": ids[0], "line_id": ids[1], "packets": packets}


static func _valid_id(id: String) -> bool:
	return not id.is_empty() and id.length() <= 64 and id.is_valid_ascii_identifier()


static func _md5(data: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(data)
	return h.finish().hex_encode()


# --- Sharing (doc 06 s12) -----------------------------------------------------------------------

## Owner: sends this machine's whole set (empty unless the setting is Live clips), then the chunks of
## the clips not sent yet this session (the host already holds the rest).
func share() -> void:
	if not Game.in_session:
		return
	var clips := own_clips() if Game.wire_voice_setting() == "live_clips" else []
	var manifest := []
	for c in clips:
		manifest.append({"clip_id": c.clip_id, "line_id": c.line_id, "frames": c.frames, "bytes": c.bytes, "hash": c.hash})
	Net.to_host(&"request_clip_manifest", [manifest])
	var sent := {}
	for c in clips:
		sent[c.clip_id] = true
		if _sent.has(c.clip_id):
			continue
		var data: PackedByteArray = c.data
		var n := ceili(data.size() / float(CHUNK_BYTES))
		for i in n:
			Net.to_host(&"request_clip_chunk", [c.clip_id, i, n, data.slice(i * CHUNK_BYTES, (i + 1) * CHUNK_BYTES)])
	_sent = sent
	_dirty = true


## Host: the sender's manifest. Refused whole if it breaks a cap or names a bad clip.
func on_manifest_request(peer: int, manifest: Array) -> void:
	if not Game.is_host() or not Game.players.has(peer):
		return
	var total := 0
	var reason := ""
	for e in manifest:
		if typeof(e) != TYPE_DICTIONARY or not _valid_id(str(e.get("clip_id", ""))) or int(e.get("bytes", 0)) <= 0 \
				or typeof(e.get("hash")) != TYPE_STRING or typeof(e.get("line_id")) != TYPE_STRING:
			reason = "bad_entry"
		total += int(e.get("bytes", 0)) if typeof(e) == TYPE_DICTIONARY else 0
	if manifest.size() > MAX_CLIPS:
		reason = "too_many"
	elif total > MAX_BYTES:
		reason = "too_big"
	if not reason.is_empty():
		Log.event(&"clip_refused", {"owner": peer, "reason": reason, "clips": manifest.size(), "bytes": total})
		return
	apply_manifest(peer, manifest)
	Net.to_peers(&"apply_clip_manifest", [peer, manifest], _others(peer))


## Host: one chunk from its owner. Kept and forwarded only if it fits the owner's manifest.
func on_chunk_request(peer: int, clip_id: String, index: int, count: int, bytes: PackedByteArray) -> void:
	if not Game.is_host() or not Game.players.has(peer):
		return
	if _put_chunk(peer, clip_id, index, count, bytes):
		Net.to_peers(&"apply_clip_chunk", [peer, clip_id, index, count, bytes], _others(peer))


func apply_manifest(owner_peer: int, manifest: Array) -> void:
	var old: Dictionary = _store.get(owner_peer, {})
	var new := {}
	var total := 0
	for e: Dictionary in manifest:
		var id := str(e.clip_id)
		total += int(e.bytes)
		if old.has(id) and old[id].hash == e.hash:
			new[id] = old[id]
			continue
		var parts := []
		parts.resize(ceili(int(e.bytes) / float(CHUNK_BYTES)))
		new[id] = {"line_id": str(e.line_id), "frames": int(e.get("frames", 0)), "bytes": int(e.bytes),
				"hash": str(e.hash), "parts": parts, "got": 0, "data": null}
	for id in old:
		if not new.has(id) or new[id] != old[id]:
			stop(owner_peer, id)
			clip_freed.emit(owner_peer, id)
	if new.is_empty():
		_store.erase(owner_peer)
	else:
		_store[owner_peer] = new
	_dirty = true
	Log.event(&"clip_manifest", {"owner": owner_peer, "clips": manifest.size(), "bytes": total})


func apply_chunk(owner_peer: int, clip_id: String, index: int, count: int, bytes: PackedByteArray) -> void:
	_put_chunk(owner_peer, clip_id, index, count, bytes)


func _put_chunk(owner_peer: int, clip_id: String, index: int, count: int, bytes: PackedByteArray) -> bool:
	var c: Dictionary = _store.get(owner_peer, {}).get(clip_id, {})
	if c.is_empty() or c.data != null or count != c.parts.size() or index < 0 or index >= count \
			or c.parts[index] != null or bytes.size() > CHUNK_BYTES:
		Log.event(&"clip_refused", {"owner": owner_peer, "clip_id": clip_id, "reason": "bad_chunk"})
		return false
	c.parts[index] = bytes
	c.got += 1
	if c.got < count:
		return true
	var data := PackedByteArray()
	for p: PackedByteArray in c.parts:
		data.append_array(p)
	var parsed := decode(data)
	if data.size() != c.bytes or _md5(data) != c.hash or parsed.get("clip_id", "") != clip_id:
		Log.event(&"clip_refused", {"owner": owner_peer, "clip_id": clip_id, "reason": "bad_data"})
		c.parts.fill(null)
		c.got = 0
		return false
	c.data = data
	c.parts = []
	c.frames = parsed.packets.size()
	_dirty = true
	Log.event(&"clip_received", {"owner": owner_peer, "clip_id": clip_id, "line_id": c.line_id, "bytes": data.size(), "frames": c.frames})
	return true


## Host: a late joiner gets every manifest, every whole clip and every chunk already in (doc 06 s12 step 3).
func _on_player_joined(peer: int) -> void:
	_dirty = true
	if not Game.is_host() or peer == 1:
		return
	for o in _store:
		var manifest := []
		for id in _store[o]:
			var c: Dictionary = _store[o][id]
			manifest.append({"clip_id": id, "line_id": c.line_id, "frames": c.frames, "bytes": c.bytes, "hash": c.hash})
		Net.to_peers(&"apply_clip_manifest", [o, manifest], [peer])
		for id in _store[o]:
			var c: Dictionary = _store[o][id]
			var n := ceili(c.bytes / float(CHUNK_BYTES))
			for i in n:
				var part: Variant = c.data.slice(i * CHUNK_BYTES, (i + 1) * CHUNK_BYTES) if c.data != null else c.parts[i]
				if part != null:
					Net.to_peers(&"apply_clip_chunk", [o, id, i, n, part], [peer])


func _others(peer: int) -> Array:
	var out := []
	for p in multiplayer.get_peers():
		if p != peer:
			out.append(p)
	return out


func _free(owner_peer: int) -> void:
	if _store.erase(owner_peer):
		Log.event(&"clips_freed", {"owner": owner_peer})
	stop(owner_peer)
	clip_freed.emit(owner_peer, "")


## Peers' complete clips this machine holds, other than `receiver`'s own, as one md5.
func digest_for(receiver: int) -> String:
	var keys := []
	for o in _store:
		if o == receiver:
			continue
		for id in _store[o]:
			if _store[o][id].data != null:
				keys.append("%d/%s/%s" % [o, id, _store[o][id].hash])
	keys.sort()
	return "|".join(keys).md5_text()


func on_ready_request(peer: int, digest: String) -> void:
	if Game.is_host():
		_digests[peer] = digest


## Host: every clip has reached the host and every client holds every clip of the others.
func all_ready() -> bool:
	return _not_ready().is_empty()


func _not_ready() -> Array:
	var out := []
	for o in _store:
		for c in _store[o].values():
			if c.data == null and not o in out:
				out.append(o)
	for p in Game.players:
		if p != 1 and _digests.get(p, "-") != digest_for(p) and not p in out:
			out.append(p)
	return out


## Host, from `Game.match_ready()` (doc 06 s12 step 5). False starts the wait; `_process` calls
## `Game.start_match()` again once everyone is ready or the 30 s run out.
func ready_to_start() -> bool:
	var missing := _not_ready()
	if missing.is_empty() or _wait_t >= SHARE_TIMEOUT_S:
		Log.event(&"clip_share_done", {"waited_s": snappedf(maxf(_wait_t, 0.0), 0.1), "timed_out": not missing.is_empty(), "missing": missing})
		_wait_t = -1.0
		return true
	if _wait_t < 0.0:
		_wait_t = 0.0
		Log.event(&"clip_share_wait", {"missing": missing})
	return false


func waiting() -> bool:
	return _wait_t >= 0.0


# --- Playback -----------------------------------------------------------------------------------

## Host, the creature's splice (doc 03 s12.1): the head of `owner_peer`'s clip `a` up to its word break, then the
## tail of clip `b` from its word break. [] if either clip is missing or too short to cut.
func splice(owner_peer: int, a: String, b: String) -> Array:
	var pa := packets(owner_peer, a)
	var pb := packets(owner_peer, b)
	if a == b or pa.size() < 2 or pb.size() < 2:
		return []
	var ca := VoiceSplice.word_break(_sizes(pa))
	var cb := VoiceSplice.word_break(_sizes(pb))
	return [[a, 0, ca], [b, cb, pb.size() - cb]]


static func _sizes(pk: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p: PackedByteArray in pk:
		out.append(p.size())
	return out


## Clip ids `owner_peer` has shared, complete on this machine (own clips: this machine's memory).
func clip_ids(owner_peer: int) -> Array:
	if owner_peer == Game.local_peer():
		return _own.keys()
	var out := []
	for id in _store.get(owner_peer, {}):
		if _store[owner_peer][id].data != null:
			out.append(id)
	return out


## The Opus packets of a clip id or a splice spec (`VoiceSplice`), or [] if this machine doesn't hold every
## clip or a segment runs past its clip. Lures push these into a fresh `AudioStreamOpus`; check
## `Game.replays_voice(owner)` first (doc 06 s11 "Coverage"). A splice is the segments back to back.
func packets(owner_peer: int, spec: String) -> Array:
	var out := []
	for s: Array in VoiceSplice.parse_spec(spec):
		var data: Variant = _own.get(s[0]) if owner_peer == Game.local_peer() else _store.get(owner_peer, {}).get(s[0], {}).get("data")
		var pk: Array = decode(data).get("packets", []) if data != null else []
		var count: int = pk.size() - s[1] if s[2] < 0 else s[2]
		if pk.is_empty() or s[1] + count > pk.size():
			return []
		out.append_array(pk.slice(s[1], s[1] + count))
	return out


## Plays a clip flat (the pause menu's review). Returns the player, or null if the clip isn't here.
func play(owner_peer: int, clip_id: String, bus: StringName = &"VoiceBase") -> AudioStreamPlayer:
	var pk := packets(owner_peer, clip_id)
	if pk.is_empty():
		return null
	stop(owner_peer, clip_id)
	return play_packets(pk, bus, owner_peer, clip_id)


## Plays raw Opus packets (a clip from `play`, or the voice chain's replays).
func play_packets(pk: Array, bus: StringName = &"VoiceBase", owner_peer: int = 0, clip_id: String = "") -> AudioStreamPlayer:
	var s := AudioStreamOpus.new()
	s.opus_sample_rate = Voice.OPUS_RATE
	s.opus_channels = 1
	s.buffer_length = pk.size() * FRAME_S + 0.5  # the whole clip fits, so it is pushed at once
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	add_child(p)
	p.play()
	var pb := p.get_stream_playback() as AudioStreamPlaybackOpus
	for pkt: PackedByteArray in pk:
		pb.push_opus_packet(pkt, 0, 0)
	pb.mark_end_opus_stream(true)
	_playing.append([owner_peer, clip_id, p])
	get_tree().create_timer(pk.size() * FRAME_S + 0.3).timeout.connect(func() -> void:
		if is_instance_valid(p):
			_drop(p))
	return p


## Stops `owner_peer`'s playing clip `clip_id` ("" = all of theirs), and any splice that uses it.
func stop(owner_peer: int, clip_id: String = "") -> void:
	for e in _playing.duplicate():
		if e[0] == owner_peer and (clip_id.is_empty() or e[1] == clip_id or clip_id in VoiceSplice.spec_ids(e[1])):
			_drop(e[2])


func _drop(p: AudioStreamPlayer) -> void:
	_playing = _playing.filter(func(e: Array) -> bool: return e[2] != p)
	if is_instance_valid(p):
		p.stop()
		p.queue_free()
