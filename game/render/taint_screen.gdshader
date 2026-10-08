shader_type canvas_item;
// Doc 05 section 10 and doc 07 section 8: the Tainted player's own screen gets oily smudges at the edges
// (thickest at the bottom, where the hands are) and a faint dark fog over everything. Darken only, a fixed
// pattern (no TIME), and `strength` fades slowly: it is not light and never pulses (doc 07 section 4.3).

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float fog = 0.10;  // placeholder: faint, playtest settles it
uniform vec3 oil_col : source_color = vec3(0.039, 0.027, 0.063);

// Dave Hoskins' hash12: the usual fract(sin(x) * 43758) amplifies FMA rounding differences, so the same
// lattice corner hashed from two neighbouring cells disagreed and drew hard blocks on screen.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

void fragment() {
	vec2 q = (UV - vec2(0.5, 0.42)) * vec2(1.0, 0.85);  // centre raised: more smudge at the bottom
	float n = noise(UV * vec2(7.0, 4.5)) * 0.6 + noise(UV * vec2(19.0, 13.0)) * 0.4;
	float smudge = smoothstep(0.36, 0.62, length(q) + (n - 0.5) * 0.3);
	COLOR = vec4(oil_col, strength * clamp(fog + smudge * 0.6, 0.0, 0.8));
}
