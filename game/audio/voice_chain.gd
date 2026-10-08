class_name VoiceChain
extends RefCounted
## Doc 08 section 7 / doc 06 section 9: the shared voice chain buses, the crackle layer and the ghost static.
## A fake (a clip lure, P2-04) picks its bus and crackle from the host's `tell` (`apply_lure.tell`); a real
## voice uses tell `none`. A voice whose owner is dead, heard by a living listener (`Voice.hears_static`), plays
## on the `VoiceGhost*` bus of the same tell and gets the static layer, real or fake alike (doc 01 "The
## dead-voice twist", P3-10). All levels are placeholders (doc 08 section 7.2: echo 180 ms at -18 dB, pitch
## +/-6%, crackle faint; doc 06 section 9: static band 400 Hz to 3 kHz) and live here, not in `game/voice/`.
##
##   var p := VoiceChain.play_clip(owner_peer, clip_id, tell)   # flat; P2-04 may use bus_for + attach_crackle
##   VoiceChain.attach_crackle(my_positional_player, tell, VoiceChain.bus_for(tell, Voice.hears_static(owner)))

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
# Ghost static (doc 06 section 9), all placeholders until the CEO listen (P3-10): a radio band, an overdrive,
# and a procedural noise layer while the voice plays, loud enough to disguise the speaker a little.
const GHOST_LOW_HZ := 400.0
const GHOST_HIGH_HZ := 3000.0
const GHOST_DRIVE := 0.45
const GHOST_STATIC_DB := -12.0
const STATIC_RATE := 22050
const STATIC_SEED := 1209  ## fixed, so every machine plays the same static

static var _static_wav: AudioStreamWAV


## The bus a voice with this tell plays on (created on first use; VoiceBase is shared with `Voice`).
## `ghost`: the `VoiceGhost*` twin, which sends into `VoiceGhost`'s static effects.
static func bus_for(tell: StringName, ghost: bool = false) -> StringName:
	ensure_buses()
	var b: StringName = TELL_BUS.get(tell, &"VoiceBase")
	if not ghost:
		return b
	return &"VoiceGhost" if b == &"VoiceBase" else StringName(String(b).replace("Voice", "VoiceGhost"))


static func is_ghost_bus(bus: StringName) -> bool:
	return String(bus).begins_with("VoiceGhost")


static func ensure_buses() -> void:
	if AudioServer.get_bus_index(&"VoiceGhost") >= 0:
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
	# A bus may only send to one before it, so VoiceGhost comes first and the tell twins send into it.
	var ghost := _bus(&"VoiceGhost", parent)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = GHOST_LOW_HZ
	AudioServer.add_bus_effect(ghost, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = GHOST_HIGH_HZ
	AudioServer.add_bus_effect(ghost, lp)
	var drive := AudioEffectDistortion.new()
	drive.mode = AudioEffectDistortion.MODE_OVERDRIVE
	drive.drive = GHOST_DRIVE
	AudioServer.add_bus_effect(ghost, drive)
	AudioServer.add_bus_effect(_bus(&"VoiceGhostEcho", "VoiceGhost"), echo.duplicate())
	for pair in [[&"VoiceGhostPitchUp", PITCH_UP], [&"VoiceGhostPitchDown", PITCH_DOWN]]:
		var shift := AudioEffectPitchShift.new()
		shift.pitch_scale = pair[1]
		AudioServer.add_bus_effect(_bus(pair[0], "VoiceGhost"), shift)


static func _bus(bus_name: StringName, send: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx


## Adds the crackle loop as a child of `voice` on `bus` (3D if `voice` is an AudioStreamPlayer3D), unless
## the tell is `no_crackle`; on a ghost bus it also adds the static layer, whatever the tell. Both live and die
## with `voice`. Returns the crackle layer or null.
static func attach_crackle(voice: Node, tell: StringName, bus: StringName) -> Node:
	if is_ghost_bus(bus):
		attach_static(voice, bus)
	if tell == &"no_crackle" or not ResourceLoader.exists(CRACKLE):
		return null
	var s := (load(CRACKLE) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	var layer := _layer(voice, s, bus, CRACKLE_DB)
	layer.name = "Crackle"
	return layer


## The ghost static noise layer (doc 06 section 9) as child `GhostStatic` of `voice`, on `bus`.
static func attach_static(voice: Node, bus: StringName) -> Node:
	var layer := _layer(voice, static_stream(), bus, GHOST_STATIC_DB)
	layer.name = "GhostStatic"
	return layer


static func _layer(voice: Node, s: AudioStream, bus: StringName, db: float) -> Node:
	var layer: Node
	if voice is AudioStreamPlayer3D:
		layer = AudioStreamPlayer3D.new()
		layer.unit_size = voice.unit_size
		layer.max_distance = voice.max_distance
	else:
		layer = AudioStreamPlayer.new()
	layer.stream = s
	layer.bus = bus
	layer.volume_db = db
	voice.add_child(layer)
	layer.play()
	return layer


## One second of generated radio static, looping: white hiss under random crackle pops (procedural, no
## recording; placeholder for the Audio Designer's static, P3-10). Built once per run.
static func static_stream() -> AudioStreamWAV:
	if _static_wav:
		return _static_wav
	var rng := RandomNumberGenerator.new()
	rng.seed = STATIC_SEED
	var data := PackedByteArray()
	data.resize(STATIC_RATE * 2)
	var pop := 0.0
	for i in STATIC_RATE:
		if rng.randf() < 0.002:
			pop = rng.randf_range(-1.0, 1.0)
		pop *= 0.92
		var v := clampf(rng.randf_range(-0.35, 0.35) + pop, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	_static_wav = AudioStreamWAV.new()
	_static_wav.format = AudioStreamWAV.FORMAT_16_BITS
	_static_wav.mix_rate = STATIC_RATE
	_static_wav.data = data
	_static_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_static_wav.loop_end = STATIC_RATE
	return _static_wav


## A stored clip through the chain, flat (non-positional). Returns the clip player or null if the clip is not here.
static func play_clip(owner_peer: int, clip_id: String, tell: StringName = &"none") -> AudioStreamPlayer:
	var bus := bus_for(tell)
	var voice: Node = (Engine.get_main_loop() as SceneTree).root.get_node(^"Voice")  # autoload by path: this class compiles before autoloads exist
	var p: AudioStreamPlayer = voice.clips.play(owner_peer, clip_id, bus)
	if p:
		attach_crackle(p, tell, bus)
	return p
