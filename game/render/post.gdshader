shader_type canvas_item;
// Doc 07 section 6 steps 3 and 4: vignette and static film grain (both darken only). Grain is a fixed
// pattern (no TIME) and both strengths follow the clock phase slowly, so nothing here can pulse.

uniform float vignette : hint_range(0.0, 1.0) = 0.15;
uniform float grain : hint_range(0.0, 0.2) = 0.02;

void fragment() {
	float v = smoothstep(0.35, 0.85, length((UV - 0.5) * vec2(1.0, 0.8)));
	float n = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.0, 0.0, 0.0, clamp(v * vignette + n * grain, 0.0, 1.0));
}
