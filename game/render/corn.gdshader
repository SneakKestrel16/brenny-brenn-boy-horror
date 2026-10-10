shader_type spatial;
render_mode cull_disabled;
// Doc 07 section 10.1: wind sway in the vertex shader, no CPU cost. Mover parting (<= 8 positions)
// is not built yet. Sway is geometry, not light: it never touches energy.
// P5-49: colour comes from the stalk meshes' vertex colour (corn greens, dry tan tips, gold ear); the shader only
// varies it per plant, darkens the base (ground shade) and breaks up the far band with faint leaf stripes.

varying float h;
varying float seed;
varying vec3 wpos;

void vertex() {
	h = clamp(VERTEX.y / 2.4, 0.0, 1.0);
	vec3 wp = MODEL_MATRIX[3].xyz;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seed = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float sway = sin(TIME * 1.1 + wp.x * 0.25 + wp.z * 0.17) * 0.10 * h * h;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.5;
}

void fragment() {
	float shade = mix(0.5, 1.0, smoothstep(0.0, 0.35, h));
	float stripe = 0.92 + 0.08 * sin(wpos.x * 11.0 + wpos.z * 7.0 + wpos.y * 3.0);
	ALBEDO = COLOR.rgb * (0.82 + 0.36 * seed) * shade * stripe;
	ROUGHNESS = 0.9;
}
