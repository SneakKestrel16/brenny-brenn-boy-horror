shader_type spatial;
// P5-59: the one detail shader for gray-box surfaces. No textures: layered value noise on top of the base
// colour (vertex colour for models, `albedo_color` for plain boxes and the ground), a small per-instance tint
// from the object origin so copies of one prop differ, and roughness variation. Static, never animated, never
// emissive: it changes no light (doc 07 s4.4). Detail fades out with distance to avoid shimmer.
// Revert: see production/handoffs/P5-59.md.

uniform bool use_vertex_color = true;
uniform bool world_space = false;  // true: noise anchored in the world (ground, paths); false: moves with the object
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float detail_scale = 5.0;  // noise cells per metre
uniform float detail_strength = 0.14;  // +- fraction of brightness
uniform float patch_strength = 0.10;  // large soft patches (weathering, dirt on grass)
uniform float tint_variation = 0.05;  // per-instance brightness and warmth
uniform float base_mul = 0.96;  // slightly darker base

varying vec3 lp;
varying float inst;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lp = world_space ? (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz : VERTEX;
	inst = hash(MODEL_MATRIX[3].xyz * 0.37);
}

void fragment() {
	vec3 base = use_vertex_color ? COLOR.rgb : albedo_color.rgb;
	float fine = vnoise(lp * detail_scale) * 0.65 + vnoise(lp * detail_scale * 3.3) * 0.35;
	float broad = vnoise(lp * detail_scale * 0.12);
	float fade = 1.0 - smoothstep(20.0, 55.0, length(VERTEX));
	float k = ((fine - 0.5) * detail_strength * 2.0 + (broad - 0.5) * patch_strength * 2.0) * fade;
	vec3 tint = vec3(1.0 + (inst - 0.5) * tint_variation * 2.4, 1.0 + (inst - 0.5) * tint_variation * 2.0, 1.0 - (inst - 0.5) * tint_variation * 1.2);
	ALBEDO = base * base_mul * (1.0 + k) * tint;
	ROUGHNESS = clamp(0.88 + (fine - 0.5) * 0.25, 0.0, 1.0);
	SPECULAR = 0.0;
}
