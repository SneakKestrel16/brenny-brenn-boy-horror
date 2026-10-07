shader_type spatial;
render_mode cull_disabled;
// Doc 07 section 10.1: wind sway in the vertex shader, no CPU cost. Mover parting (<= 8 positions)
// is not built yet. Sway is geometry, not light: it never touches energy.

uniform vec3 base_col : source_color = vec3(0.16, 0.30, 0.07);
uniform vec3 tip_col : source_color = vec3(0.45, 0.50, 0.16);
varying float h;
varying float seed;

void vertex() {
	h = clamp(VERTEX.y / 2.4, 0.0, 1.0);
	vec3 wp = MODEL_MATRIX[3].xyz;
	seed = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float sway = sin(TIME * 1.1 + wp.x * 0.25 + wp.z * 0.17) * 0.10 * h * h;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.5;
}

void fragment() {
	ALBEDO = mix(base_col, tip_col, h) * (0.85 + 0.3 * seed);
	ROUGHNESS = 0.9;
}
