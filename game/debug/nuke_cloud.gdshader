// P5-41: the nuke dev toy's cloud. Flat-shaded low poly, self-lit (no Light node, no light energy).
// Vertices billow with a slow sine noise; colour runs ember -> orange -> dark smoke by height and age.
// Never white: the brightest colour is a warm orange. The fade is a screen-door dissolve (opaque, no sorting).
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;  // a fireball burns through the haze

uniform float base_y = 0.0;      // world y of the ground under the blast
uniform float top_h = 70.0;      // height that counts as "top of the cloud"
uniform float heat = 1.0;        // 1 fresh and glowing, 0 cooled to smoke
uniform float billow = 1.2;      // metres of vertex wobble
uniform float fade = 1.0;        // 1 solid, 0 gone
uniform float rim_heat = 0.0;    // dust rings stay dark
varying vec3 wp;
varying float n;
varying float lr;  // radius in the mesh's own space (the dust ring thins out toward its outer edge)

void vertex() {
	lr = length(VERTEX.xz);
	vec3 p0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;  // noise in world metres, whatever the part's scale
	float t = TIME * 0.55;
	n = sin(p0.x * 0.21 + t) * sin(p0.y * 0.19 - t * 0.8) * sin(p0.z * 0.23 + t * 0.6);
	float n2 = sin(p0.x * 0.47 - t * 1.3 + p0.z * 0.3) * sin(p0.y * 0.41 + t);
	vec3 nw0 = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 dw = nw0 * billow * (n * 1.4 + n2 * 0.5);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(dw, 0.0)).xyz;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	float edge = rim_heat > 0.0 ? 1.0 - smoothstep(0.55, 1.0, lr) : 1.0;
	if (fade * edge < d) { discard; }
	vec3 nv = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(nv, VIEW) < 0.0) { nv = -nv; }
	vec3 nw = (INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz;
	float h = clamp((wp.y - base_y) / top_h, 0.0, 1.0);
	float hot = clamp(heat * (1.2 - h * 1.6) + n * 0.3, 0.0, 1.0);
	hot += heat * clamp(-nw.y, 0.0, 1.0) * 0.45 * (1.0 - h * 0.3);  // undersides glow: the cap is lit from below
	hot = clamp(hot, 0.0, 1.0) * (1.0 - rim_heat);
	vec3 smoke = vec3(0.045, 0.03, 0.025);  // unshaded albedo is linear, so these read much lighter than they look
	vec3 ember = vec3(0.45, 0.14, 0.04);
	vec3 orange = vec3(1.0, 0.52, 0.14);
	vec3 col = mix(smoke, ember, smoothstep(0.1, 0.5, hot));
	col = mix(col, orange, smoothstep(0.5, 0.95, hot));
	float shade = 0.62 + 0.38 * dot(nw, normalize(vec3(0.4, 0.8, 0.3)));  // flat facets, lit from above
	ALBEDO = col * mix(shade, 1.0, hot * 0.5);
}
