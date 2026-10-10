class_name Squeaky
extends RefCounted
## P5-10 (doc 01 "Dev toys", Shrink): squeaky voices. One pitch-shift effect on the `Voice` bus, which every
## voice bus sends into (VoiceChain), so live voices, the dead's static voices and the creature's replays all
## squeak. The effect sits on the bus, not on the Opus emitters: raising an emitter's `pitch_scale` would drain
## its push buffer faster and underflow. Each peer turns it on and off for itself.

const PITCH := 1.7  ## placeholder, listen test (a quarter-size body, inference: about two octaves is a cartoon, one is plain squeaky)

static var _fx: AudioEffectPitchShift


static func set_on(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Voice")
	if bus < 0:
		return
	if on and _fx == null:
		_fx = AudioEffectPitchShift.new()
		_fx.pitch_scale = PITCH
		AudioServer.add_bus_effect(bus, _fx)
	elif not on and _fx != null:
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == _fx:
				AudioServer.remove_bus_effect(bus, i)
				break
		_fx = null


static func is_on() -> bool:
	return _fx != null
