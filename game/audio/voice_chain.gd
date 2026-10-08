class_name VoiceChain
extends RefCounted
## Doc 08 section 7 / doc 06 section 9: the shared voice chain buses and the crackle layer, for fakes.
## A fake (a clip lure, P2-04) picks its bus and crackle from the host's `tell` (`apply_lure.tell`); a real
## voice never calls this. All levels are placeholders (doc 08 section 7.2: echo 180 ms at -18 dB, pitch
## +/-6%, crackle faint) and live here, not in `game/voice/` (doc 06 section 9).
##
##   var p := VoiceChain.play_clip(owner_peer, clip_id, tell)   # flat; P2-04 may use bus_for + attach_crackle
##   VoiceChain.attach_crackle(my_positional_player, tell, VoiceChain.bus_for(tell))

const ECHO_DELAY_MS := 180.0
const ECHO_LEVEL_DB := -18.0
const PITCH_UP := 1.06
const PITCH_DOWN := 0.94
const CRACKLE_DB := -40.0  ## placeholder; doc 08 7.2 wants -34 dB under the voice envelope, a fixed level approximates it
const CRACKLE := "res://assets/audio/vox_crackle_loop.wav"
const TELL_BUS := {
	&"none": &"VoiceBase", &"no_crackle": &"VoiceBase", &"echo": &"VoiceEcho",
	&"pitch_up": &"VoicePitchUp", &"pitch_down": &"VoicePitchDown",
}


## The bus a fake with this tell plays on (created on first use; VoiceBase is shared with `Voice`).
static func bus_for(tell: StringName) -> StringName:
	ensure_buses()
	return TELL_BUS.get(tell, &"VoiceBase")


static func ensure_buses() -> void:
	if AudioServer.get_bus_index(&"VoiceEcho") >= 0:
		return
	var parent := "Voice" if AudioServer.get_bus_index(&"Voice") >= 0 else "Master"
	_bus(&"VoiceBase", parent)
	var echo := AudioEffectDelay.new()
	echo.dry = 1.0
	echo.tap1_active = true
	echo.tap1_delay_ms = ECHO_DELAY_MS
	echo.tap1_level_db = ECHO_LEVEL_DB
	echo.tap1_pan = 0.0
	echo.tap2_active = false
	echo.feedback_active = false
	AudioServer.add_bus_effect(_bus(&"VoiceEcho", parent), echo)
	for pair in [[&"VoicePitchUp", PITCH_UP], [&"VoicePitchDown", PITCH_DOWN]]:
		var shift := AudioEffectPitchShift.new()
		shift.pitch_scale = pair[1]
		AudioServer.add_bus_effect(_bus(pair[0], parent), shift)


static func _bus(bus_name: StringName, send: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx


## Adds the crackle loop as a child of `voice` on `bus` (3D if `voice` is an AudioStreamPlayer3D), unless
## the tell is `no_crackle`. It lives and dies with `voice`. Returns the layer or null.
static func attach_crackle(voice: Node, tell: StringName, bus: StringName) -> Node:
	if tell == &"no_crackle" or not ResourceLoader.exists(CRACKLE):
		return null
	var s := (load(CRACKLE) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	var layer: Node
	if voice is AudioStreamPlayer3D:
		layer = AudioStreamPlayer3D.new()
		layer.unit_size = voice.unit_size
		layer.max_distance = voice.max_distance
	else:
		layer = AudioStreamPlayer.new()
	layer.stream = s
	layer.bus = bus
	layer.volume_db = CRACKLE_DB
	voice.add_child(layer)
	layer.play()
	return layer


## A stored clip through the chain, flat (non-positional). Returns the clip player or null if the clip is not here.
static func play_clip(owner_peer: int, clip_id: String, tell: StringName = &"none") -> AudioStreamPlayer:
	var bus := bus_for(tell)
	var voice: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"Voice")  # autoload by path: this class compiles before autoloads exist
	var p: AudioStreamPlayer = voice.clips.play(owner_peer, clip_id, bus)
	if p:
		attach_crackle(p, tell, bus)
	return p
