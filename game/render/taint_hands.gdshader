shader_type spatial;
// Doc 07 section 8: the Taint stain on hands and sleeves. Oil black #0A0710 with a purple sheen #3A1F4A
// (doc 07 section 2) climbs from the fingers toward the elbow by `taint_level`, with a hard ragged edge.
// Glossy oil against matte cloth is the colour-blind-safe cue (it reads in greyscale). Not emissive: the
// sheen is specular and fresnel only, so it never glows at night (doc 07 section 2 rule).

uniform float taint_level : hint_range(0.0, 1.0) = 1.0;
uniform float arm_len = 0.42;  // local Y spans -arm_len/2 (elbow) to +arm_len/2 (fingertips)
uniform bool model_axis = false;  // P5-22 tool_hands: elbow at the origin, fingertips along local -Z (0 .. arm_len)
uniform vec3 cloth_col : source_color = vec3(0.24, 0.29, 0.40);  // placeholder sleeve denim
uniform vec3 oil_col : source_color = vec3(0.039, 0.027, 0.063);
uniform vec3 sheen_col : source_color = vec3(0.227, 0.122, 0.290);
varying vec3 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float along = model_axis ? -lp.z - arm_len * 0.5 : lp.y;
	float t = along / arm_len + 0.5;  // 0 at the elbow, 1 at the fingertips
	float jag = hash(floor(vec2(atan(lp.x, model_axis ? lp.y : lp.z) * 2.5, along * 28.0))) - 0.5;
	float oil = step(1.0 - taint_level * 0.75 + jag * 0.14, t);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(cloth_col, oil_col + sheen_col * fres, oil);
	// Low specular: a strong mirror reflects the day sky and reads as blue plastic instead of oil.
	ROUGHNESS = mix(0.95, 0.22, oil);
	SPECULAR = mix(0.25, 0.4, oil);
}
