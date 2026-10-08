shader_type spatial;
render_mode cull_back, shadows_disabled;
// Doc 07 sections 2 and 8: a Taint stain on the ground (creature leavings, strange seeds), seen by every
// peer. A ragged oil puddle with drips around it, or a scatter of dark seeds when `speckle` is 1. Alpha
// scissor (no sorting cost), glossy oil, never emissive.

uniform float seed = 0.0;
uniform float speckle = 0.0;
uniform vec3 oil_col : source_color = vec3(0.039, 0.027, 0.063);
uniform vec3 sheen_col : source_color = vec3(0.227, 0.122, 0.290);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float a = atan(p.y, p.x);
	float rr = 0.62 + 0.12 * sin(a * 3.0 + seed * 6.28) + 0.07 * sin(a * 7.0 + seed * 17.0);
	float puddle = step(length(p), rr) * (1.0 - speckle);
	vec2 cell = floor(UV * 9.0);
	vec2 c = fract(UV * 9.0) - 0.5;
	float h = hash(cell + seed);
	float dot_r = mix(0.22, 0.3, speckle) * step(mix(0.82, 0.45, speckle), h) * step(length(p), 0.95);
	float drops = step(length(c), dot_r);
	ALPHA = max(puddle, drops);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// Seen at a grazing angle a mirror-like puddle reflects the day sky and reads pale pink-white, not black,
	// so the gloss is kept modest and the sheen faint.
	ALBEDO = oil_col + sheen_col * fres * 0.5;
	ROUGHNESS = 0.35;
	SPECULAR = 0.2;
}
