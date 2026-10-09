shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// Doc 07 s7 `mat_ghost_rim`, s8: a cold rim on the creature, drawn only on a ghost's own screen
// (CreatureLook.ghost_view). Fresnel only: no TIME, no energy change, so it never pulses
// (s4.3). Not a Light3D. Strength is constant and low, so it shows a silhouette and no detail.

uniform vec4 rim_color : source_color = vec4(0.749, 0.847, 1.0, 1.0); // #BFD8FF
uniform float strength : hint_range(0.0, 2.0) = 0.8;
uniform float power : hint_range(0.5, 6.0) = 2.5;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), power);
	ALBEDO = rim_color.rgb * f * strength;
}
