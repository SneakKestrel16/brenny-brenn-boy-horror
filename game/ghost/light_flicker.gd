extends RefCounted
## Doc 07 section 4.3: the ghost flicker look, the only flicker in the game. Four square steps
## dim/on/dim/on, 0.25 s each (1.0 s), dipping to 30% of the light's level, tinted #BFD8FF throughout;
## the tint goes back over 0.1 s. Runs through LightRig.energy_override (the guarded ghost path), so the
## rig's own slew and state are untouched and come back when the override clears.
## Not built: the photosensitive_safe variant (doc 07 s4.3); no such setting exists yet.

const STEP_S := 0.25
const DIP := 0.3
const TINT := Color("BFD8FF")
const BACK_S := 0.1
const LIT := 0.05  ## below this level the light is off or blown out: it never flickers (doc 03 s20)


## Plays the pattern on `rig` (every peer). Returns false when the light is not lit.
static func play(rig: LightRig) -> bool:
	if rig.has_meta(&"ghost_tween") and (rig.get_meta(&"ghost_tween") as Tween).is_valid():
		return true  # one at a time; the host cooldown keeps them apart anyway
	var base := rig.current_level()
	if base <= LIT:
		return false
	var tw := rig.create_tween()
	for v in [base * DIP, base, base * DIP, base]:
		tw.tween_callback(rig.energy_override.bind(v, LightRig.OVERRIDE_TOKEN, TINT))
		tw.tween_interval(STEP_S)
	tw.tween_method(func(t: float) -> void:
		rig.energy_override(base, LightRig.OVERRIDE_TOKEN, TINT.lerp(rig.color, t)), 0.0, 1.0, BACK_S)
	tw.tween_callback(rig.energy_override.bind(-1.0, LightRig.OVERRIDE_TOKEN))
	rig.set_meta(&"ghost_tween", tw)
	return true
