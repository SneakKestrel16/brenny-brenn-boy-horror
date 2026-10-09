shader_type canvas_item;
// Doc 07 section 6 steps 3 and 4: vignette and static film grain (both darken only). Grain is a fixed
// pattern (no TIME) and every strength follows the clock phase slowly, so nothing here can pulse.
// `tired` (0..1, from stamina, slewed by WorldLook) widens the dark edge a little. Colour grade (step 2)
// is the Environment adjustment, so the HUD is never graded.

uniform float vignette : hint_range(0.0, 1.0) = 0.15;
uniform float grain : hint_range(0.0, 0.2) = 0.02;
uniform float tired : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float v = smoothstep(0.35 - 0.1 * tired, 0.85 - 0.15 * tired, length((UV - 0.5) * vec2(1.0, 0.8)));
	float n = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v * vignette + n * grain, 0.0, 1.0));
}
