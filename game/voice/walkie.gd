class_name Walkie
extends Node
## P4-14 (doc 06 s10, doc 02 s10, doc 08 s7.2): walkie-talkies. Child `Walkie` of the `Voice` autoload, on every peer.
##
## Host: a player holds a walkie when the store says they own `walkie_talkie` and they are alive (D-013). Each held
## walkie has a battery, in seconds of transmitting; when it runs dry the host loads a spare from the team's bought
## `walkie_battery` count (`Store.team`), so the battery a new walkie includes goes into the buyer's walkie at once.
## `Voice._take` honours a frame's radio flag only through `transmit()`, which drains 20 ms per frame. Changes go out
## as `apply_walkie(peer, has_walkie, battery_s)`: peer ids, not slots (D-076, Q-065).
##
## Client: plays radio frames only on its own powered walkie (D-011), flat (not attenuated by distance), on the
## `VoiceRadio` bus (band-pass) with the `vox_radio_static_loop` layer, one decoder per speaker. The static rises as
## the creature nears this listener. Squelch on and off at each received spurt, a low-battery beep, a dead click.
## Unfakeable by construction: only `Voice._play` calls `hear()`, with relay frames from a live player's slot; no
## lure or clip path reaches `VoiceRadio` (doc 06 s10).
##
## QA user args (after `--`): `--radio-hold` holds the radio key; `--walkie-qa` (host) buys every player a walkie,
## clients first at 3 s, the host at 12 s, so a log shows the host not hearing the radio until it holds one.

const FRAME_S := 0.02  ## one voice frame (doc 06 s8: 20 ms)
const LOW_S := 30.0  ## battery seconds that count as low (placeholder: doc 08 s7.2 gives the beep, not the threshold)
const LOW_BEEP_S := 20.0  ## doc 08 s7.2: the low-battery beep every 20 s
const STATIC_FAR_M := 30.0  ## doc 06 s10: creature static starts at 30 m (placeholder)
const STATIC_NEAR_M := 5.0  ## doc 08 s7.2: and reaches -6 dB at 5 m
const STATIC_BASE_DB := -20.0  ## doc 08 s7.2: the walkie's crackle (`vox_radio_static_loop`) on every radio voice
const STATIC_NEAR_DB := -6.0
const BAND_LOW_HZ := 500.0  ## doc 08 s7.2: band-pass 500 Hz to 2.8 kHz
const BAND_HIGH_HZ := 2800.0
const SYNC_EVERY_S := 0.25  ## host: how often battery changes go out (placeholder)
const STATIC := "res://assets/audio/vox_radio_static_loop.wav"
const QA_CLIENT_BUY_S := 3.0
const QA_HOST_BUY_S := 12.0

var battery := {}  ## host: peer -> seconds left in the battery in their walkie
var state := {}  ## every peer: peer -> [has_walkie, battery whole seconds], as the host last said
var _sent := {}  ## host: peer -> the state last sent
var _sync_t := 0.0
var _tx_at := {}  ## host: peer -> msec of their last radio frame (a gap starts a new `walkie_transmit` line)
var _tx_frames := 0  ## host: radio frames relayed since start
var _radios := {}  ## speaker -> the VoiceEmitter this machine's walkie plays them on
var _talking := {}  ## speaker -> their radio spurt was playing last frame
var _beep_t := 0.0
var _key_was := false
var _qa_t := -1.0


func _ready() -> void:
	name = "Walkie"
	Game.player_joined.connect(func(_peer: int) -> void: _sent.clear())  # a late joiner gets every walkie
	Game.player_left.connect(_on_player_left)
	if OS.get_cmdline_user_args().has("--walkie-qa"):
		Game.session_started.connect(func() -> void: _qa_t = 0.0)


## Doc 08 s7.2: the static on a radio voice, from this listener's distance to the creature. The doc's creature
## static rises from -inf at 30 m to -6 dB at 5 m over the same loop that already plays at -20 dB, so one layer
## at the louder of the two: -20 dB beyond 30 m, then linear in dB to -6 dB at 5 m (inference: one loop, not two).
static func static_db(distance_m: float) -> float:
	var t := clampf((STATIC_FAR_M - distance_m) / (STATIC_FAR_M - STATIC_NEAR_M), 0.0, 1.0)
	return lerpf(STATIC_BASE_DB, STATIC_NEAR_DB, t)


## Every peer: the host says `peer` holds a walkie with battery left.
func powered(peer: int) -> bool:
	var s: Array = state.get(peer, [false, 0])
	return s[0] and s[1] > 0


## This machine holds the radio key with a walkie in hand (Voice opens the mic and sets the radio flag).
func keyed() -> bool:
	if not Game.in_session or Game.console_open or not state.get(Game.local_peer(), [false, 0])[0]:
		return false
	return OS.get_cmdline_user_args().has("--radio-hold") or Input.is_action_pressed(&"voice_radio")


# --- Host ---------------------------------------------------------------------------------------

func _store() -> Node:
	return get_tree().get_first_node_in_group(&"store")


## Host: `peer` holds a walkie. Ghosts hold no items, so only the living transmit (D-013).
func holds(peer: int) -> bool:
	var st := _store()
	return st != null and Game.players.has(peer) and not Game.is_ghost(peer) and st.owns(peer, &"walkie_talkie")


## Seconds of transmitting in one battery (`store.json` `walkie_battery` `transmit_s`); the Radio Operator's
## `battery_transmit_mult` (roles.json, doc 01 Roles) from the P4-09 role.
func full_s(peer: int) -> float:
	var s := float(Data.record(&"store", &"walkie_battery").effect.transmit_s)
	return s * float(Roles.perks(Roles.of(peer)).get("battery_transmit_mult", 1.0))


## Host: true if `peer`'s walkie has charge, loading a spare from the team's batteries if it ran dry.
func _charged(peer: int) -> bool:
	if float(battery.get(peer, 0.0)) > 0.0:
		return true
	var st := _store()
	if st == null or int(st.team.get(&"walkie_battery", 0)) < 1:
		return false
	st.team[&"walkie_battery"] = int(st.team[&"walkie_battery"]) - 1
	battery[peer] = full_s(peer)
	Log.event(&"walkie_battery_in", {"player": peer, "seconds": battery[peer], "spares": st.team[&"walkie_battery"]})
	st._send()
	return true


## Host, from `Voice._take` for a frame carrying the radio flag: may it go out on the radio? Drains `seconds`.
func transmit(peer: int, seconds: float = FRAME_S) -> bool:
	var now := Time.get_ticks_msec()
	var new_spurt := now - int(_tx_at.get(peer, -100000)) > 300
	_tx_at[peer] = now
	if not holds(peer) or not _charged(peer):
		if new_spurt:
			Log.event(&"walkie_refused", {"player": peer, "reason": "ghost" if Game.is_ghost(peer) else ("no_walkie" if not holds(peer) else "dead_battery")})
		return false
	if new_spurt:
		Log.event(&"walkie_transmit", {"player": peer, "battery_s": snappedf(battery[peer], 0.1)})
	battery[peer] = maxf(float(battery[peer]) - seconds, 0.0)
	_tx_frames += 1
	if battery[peer] <= 0.0 and not _charged(peer):
		Log.event(&"walkie_dead", {"player": peer})
	return true


## Host: send each player's walkie state when it changes (whole seconds), loading a new walkie's battery at once.
func _sync() -> void:
	for peer in Game.players:
		var has := holds(peer)
		if has:
			_charged(peer)
		var s := [has, ceili(float(battery.get(peer, 0.0))) if has else 0]
		if _sent.get(peer) != s:
			_sent[peer] = s
			Net.to_peers(&"apply_walkie", [peer, s[0], s[1]])
			apply(peer, s[0], s[1])


func _qa(delta: float) -> void:
	var st := _store()
	if st == null:
		_qa_t = 0.0  # in the barn (`--lobby`): count from the farm
		return
	var was := _qa_t
	_qa_t += delta
	for peer in Game.players:
		var at := QA_HOST_BUY_S if peer == 1 else QA_CLIENT_BUY_S
		if was < at and _qa_t >= at:
			st.farm.coins = maxi(st.farm.coins, 100)
			st.buy(peer, &"walkie_talkie", false)
	if _qa_t > QA_HOST_BUY_S:
		_qa_t = -1.0


# --- Every peer ---------------------------------------------------------------------------------

func apply(peer: int, has: bool, battery_s: int) -> void:
	var was := powered(peer)
	var had: bool = state.get(peer, [false, 0])[0]
	state[peer] = [has, battery_s]
	if peer != Game.local_peer():
		return
	if had != has or was != powered(peer):
		Log.event(&"walkie_state", {"player": peer, "has": has, "battery_s": battery_s})
	if was and has and not powered(peer):
		Soundscape.play_2d(&"vox_radio_dead")


func _on_player_left(peer: int) -> void:
	# `battery` keeps the leaver's charge: the dawn save keeps it by uid and a rejoiner gets it back (P4-10, Q-121)
	state.erase(peer)
	_sent.erase(peer)
	_tx_at.erase(peer)
	_talking.erase(peer)
	var e: Variant = _radios.get(peer)
	if is_instance_valid(e):
		e.queue_free()
	_radios.erase(peer)


func _process(delta: float) -> void:
	if not Game.in_session:
		return
	if Game.is_host():
		if _qa_t >= 0.0:
			_qa(delta)
		_sync_t += delta
		if _sync_t >= SYNC_EVERY_S:
			_sync_t = 0.0
			_sync()
	var me := Game.local_peer()
	var key := keyed()
	if key and not _key_was and not powered(me):
		Soundscape.play_2d(&"vox_radio_dead")  # keyed a walkie with a flat battery
	_key_was = key
	_beep_t -= delta
	if powered(me) and state[me][1] <= LOW_S and _beep_t <= 0.0:
		_beep_t = LOW_BEEP_S
		Soundscape.play_2d(&"vox_radio_low_battery")
	_play_radios()


## Doc 06 s10: a radio frame for this machine. Played only on this player's own powered walkie.
func hear(speaker: int, flags: int, seq: int, opus: PackedByteArray) -> void:
	var me := Game.local_peer()
	if speaker == me or not powered(me):
		return
	if Voice.capturing and Game.voice_setting_of(speaker) != "lobby_lines":
		return  # D-011: no Off player's voice while this machine captures, walkie included
	_radio(speaker).receive(flags, seq, opus)


func _radio(speaker: int) -> VoiceEmitter:
	var e: Variant = _radios.get(speaker)
	if is_instance_valid(e):
		return e
	_ensure_bus()
	var r := VoiceEmitter.new(speaker, &"VoiceRadio")
	r.name = "Radio%d" % speaker
	r.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED  # the walkie is in this player's hand
	r.panning_strength = 0.0
	r.max_distance = 0.0
	r.resync = true  # radio frames are a subset of the speaker's sequence
	add_child(r)
	if ResourceLoader.exists(STATIC):
		var s := (load(STATIC) as AudioStreamWAV).duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		var layer := AudioStreamPlayer.new()
		layer.name = "RadioStatic"
		layer.stream = s
		layer.bus = &"VoiceRadio"
		layer.volume_db = STATIC_BASE_DB
		r.add_child(layer)
		layer.play()
		layer.stream_paused = true
	_radios[speaker] = r
	return r


## Per-player volume (D-047), the static level and the squelch for each speaker on this machine's walkie.
func _play_radios() -> void:
	var cam := get_viewport().get_camera_3d()
	var cr := get_tree().get_first_node_in_group(&"creature") as Node3D
	var db := static_db(cam.global_position.distance_to(cr.global_position) if cam and cr else INF)
	for speaker in _radios:
		var r: Variant = _radios[speaker]
		if not is_instance_valid(r):
			continue
		var v := Settings.peer_volume(speaker)
		r.volume_db = linear_to_db(v) if v > 0.0 else -80.0
		var talking: bool = r.talking()
		var layer := r.get_node_or_null(^"RadioStatic") as AudioStreamPlayer
		if layer:
			layer.volume_db = db + r.volume_db
			layer.stream_paused = v <= 0.0 or not talking
		if talking != bool(_talking.get(speaker, false)):
			_talking[speaker] = talking
			Soundscape.play_2d(&"vox_radio_squelch_on" if talking else &"vox_radio_squelch_off")
			if talking:
				Log.event(&"walkie_heard", {"speaker": speaker, "static_db": snappedf(db, 0.1)})


## Doc 06 s9 / CONTRACTS s9: `VoiceRadio`, a band-pass (high-pass plus low-pass, as `VoiceGhost`) under `Voice`.
static func _ensure_bus() -> void:
	if AudioServer.get_bus_index(&"VoiceRadio") >= 0:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, &"VoiceRadio")
	AudioServer.set_bus_send(idx, "Voice" if AudioServer.get_bus_index(&"Voice") >= 0 else "Master")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = BAND_LOW_HZ
	AudioServer.add_bus_effect(idx, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = BAND_HIGH_HZ
	AudioServer.add_bus_effect(idx, lp)


## Doc 06 s14 style: every 10 s with `voice_sent`. Host: each holder's battery and the radio frames relayed.
func log_stats() -> void:
	if Game.is_host():
		var b := {}
		for p in battery:
			b[str(p)] = snappedf(battery[p], 0.1)
		Log.event(&"walkie_stats", {"battery_s": b, "radio_frames": _tx_frames})
	for speaker in _radios:
		if is_instance_valid(_radios[speaker]):
			var s: Dictionary = _radios[speaker].stats()
			s["radio"] = true
			Log.event(&"voice_stats", s)
