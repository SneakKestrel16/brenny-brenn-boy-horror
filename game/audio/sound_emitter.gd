class_name SoundEmitter
extends AudioStreamPlayer3D
## Doc 08 section 3: the only node that places a non-voice sound in 3D, so the spatialiser can be
## swapped in one place (doc 06 section 8 contingency). Doppler off: it would pitch-bend a fast
## creature (doc 08 section 15). Inverse distance like the voice emitters.


func _init() -> void:
	attenuation_model = ATTENUATION_INVERSE_DISTANCE
	doppler_tracking = DOPPLER_TRACKING_DISABLED
	panning_strength = 1.0
