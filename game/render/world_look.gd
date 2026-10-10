class_name WorldLook
extends Node
## Doc 07 sections 3, 5, 6, 10: day, dusk, night lighting driven by Clock, fog, fixed exposure, post
## pass, corn visuals, and the LightRig scenes at the `lightrig_spots` markers (Q-026). Everything is a
## pure function of (Clock.phase, progress), so every peer looks the same. It never calls a LightRig
## setter (only game/core/lights.gd may) and never changes a light on its own.
## Debug user args: --look-phase=<phase>[:progress]  --look-shot=<png>  --look-cam=x,y,z,yaw,pitch

# Keys per phase, placeholders from doc 07 section 3. sun_e is the directional light energy. sat and con are
# the colour grade (doc 07 s6 step 2: day warm and saturated, night desaturated), an Environment adjustment.
## P5-50: `pool` is how visible the painted light pools are (0 by day, 1 at night); `moon` 0..1 is the disc's
## visibility and colour mix, `moon_s` its size scale and `moon_c` its colour. All numbers are placeholders
## (doc 07 s3), tuned against screenshots in production/handoffs/P5-50.md.
const NOON := {"sun_col": Color("FFE8C0"), "sun_e": 1.5, "elev": 52.0, "amb_col": Color("D4E4F8"), "amb_e": 0.6,
		"fog_col": Color("C4DAEC"), "fog_d": 0.0012, "sky_top": Color("3F7FD0"), "sky_hor": Color("C4DAEC"),
		"vig": 0.15, "grain": 0.02, "sat": 1.2, "con": 1.1, "moon": 0.0, "moon_s": 0.3, "moon_c": Color("D8E4FF"), "pool": 0.0}
const DAY_END := {"sun_col": Color("FFB468"), "sun_e": 1.4, "elev": 16.0, "amb_col": Color("F0D4C0"), "amb_e": 0.55,
		"fog_col": Color("ECCFA8"), "fog_d": 0.0016, "sky_top": Color("4A7CC0"), "sky_hor": Color("F0C48C"),
		"vig": 0.18, "grain": 0.02, "sat": 1.15, "con": 1.1, "moon": 0.0, "moon_s": 0.3, "moon_c": Color("D8E4FF"), "pool": 0.0}
const SUNSET := {"sun_col": Color("FF6428"), "sun_e": 0.45, "elev": 4.0, "amb_col": Color("9A78B4"), "amb_e": 0.42,
		"fog_col": Color("8A5468"), "fog_d": 0.004, "sky_top": Color("2C3270"), "sky_hor": Color("F07A44"),
		"vig": 0.25, "grain": 0.04, "sat": 1.1, "con": 1.05, "moon": 0.0, "moon_s": 0.3, "moon_c": Color("D8E4FF"), "pool": 0.7}
const NIGHT := {"sun_col": Color("A4BCF0"), "sun_e": 0.2, "elev": 32.0, "amb_col": Color("6078C4"), "amb_e": 0.25,
		"fog_col": Color("141C34"), "fog_d": 0.013, "sky_top": Color("0A1230"), "sky_hor": Color("34456E"),
		"vig": 0.4, "grain": 0.06, "sat": 0.75, "con": 1.05, "moon": 0.9, "moon_s": 0.3, "moon_c": Color("D8E4FF"), "pool": 1.0}
const HARVEST := {"sun_col": Color("FFD8B0"), "sun_e": 0.28, "elev": 12.0, "amb_col": Color("4A4C80"), "amb_e": 0.3,
		"fog_col": Color("1E1C30"), "fog_d": 0.010, "sky_top": Color("0E1226"), "sky_hor": Color("4A3454"),
		"vig": 0.4, "grain": 0.06, "sat": 0.85, "con": 1.05, "moon": 1.0, "moon_s": 1.0, "moon_c": Color("FFE2C0"), "pool": 1.0}
const DAWN_MID := {"sun_col": Color("FFA458"), "sun_e": 0.6, "elev": 8.0, "amb_col": Color("B8A0B0"), "amb_e": 0.5,
		"fog_col": Color("A07C7C"), "fog_d": 0.004, "sky_top": Color("4A5E94"), "sky_hor": Color("F0A064"),
		"vig": 0.25, "grain": 0.04, "sat": 1.0, "con": 1.05, "moon": 0.0, "moon_s": 0.3, "moon_c": Color("D8E4FF"), "pool": 0.3}
const INTERIOR_FILL_M := {"Barn": 14.0, "Farmhouse": 11.0, "ToolShed": 6.0}  ## P5-50: placeholder room fill ranges, about each building's depth (doc 04 s4 footprints)
const DETAIL := true  ## P5-59: false restores the flat ground, paths and box props (one-line revert)
const SUN_AZIMUTH := -30.0
const HARVEST_EASE_S := 15.0  ## placeholder: night to Harvest Moon look, on the shared clock
const MOON_M := 300.0  ## QA P4-20: moon disc distance from the camera, beyond the farm, inside the far plane
const MOON_R := 16.0  ## placeholder: disc radius at MOON_M (about 6 degrees across, "low and large", doc 07 s3)

var corn: CornField
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _post: ShaderMaterial
var _override_phase: StringName = &""
var _override_p := 0.0
var _shot := ""
var _frames := 0
var _fixed_cam: Camera3D
var _lp: Node  ## local Player, found lazily
var _tired := 0.0
var _moon: MeshInstance3D  ## Harvest Moon disc; `moon` key 0..1 eases it in with the look


func _ready() -> void:
	_parse_args()
	_build_environment()
	var world := get_parent().get_node_or_null("World")
	if world:
		_place_rigs(world)
		var blockers := world.get_node_or_null("CornBlockers")
		if blockers:
			corn = CornField.new()
			corn.name = "Corn"
			add_child(corn)
			corn.build(blockers)
		var floor_mesh := world.get_node_or_null("Ground/Floor/Mesh") as MeshInstance3D
		if floor_mesh:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.30, 0.34, 0.22)
			m.roughness = 1.0
			floor_mesh.material_override = m
		_paint_props(world)
		if DETAIL:
			_detail_pass(world)
	_apply(_state())
	if _shot != "" or _cam_arg():
		_shot_camera()


## Flat colours so the props read at a glance: generator dark green + light panel, well blue water top,
## fuel drum red + yellow band, sell box brown. Plain materials only: no lights, no energy changes.
func _paint_props(world: Node) -> void:
	for spec in [[&"generator", Color(0.12, 0.30, 0.16), Vector3(1.6, 0.6, 0.06), Vector3(0, 0.05, 0.53), Color(0.75, 0.82, 0.7)],
			[&"fuel_drum", Color(0.8, 0.1, 0.08), Vector3(1.02, 0.12, 1.02), Vector3(0, 0.1, 0), Color(0.95, 0.8, 0.1)],
			[&"well", Color(0.4, 0.38, 0.36), Vector3(1.5, 0.05, 1.5), Vector3(0, 0.51, 0), Color(0.2, 0.5, 0.95)],
			[&"sell_box", Color(0.45, 0.28, 0.12), Vector3(1.3, 0.05, 1.3), Vector3(0, 0.51, 0), Color(0.7, 0.5, 0.25)]]:
		var body := get_tree().get_first_node_in_group(spec[0]) as Node3D
		if body == null or not world.is_ancestor_of(body):
			continue
		var mi := body.get_node_or_null("Mesh") as MeshInstance3D
		if mi == null or not mi.visible:  # P5-22: the well is a model now, its box is hidden
			continue
		mi.material_override = _flat(spec[1])
		var accent := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[2]
		accent.mesh = b
		accent.position = spec[3]
		accent.material_override = _flat(spec[4])
		body.add_child(accent)


## P5-59: swaps every plain opaque lit box and ground material under the world for the shared detail shader
## (same colour, noise on top), one ShaderMaterial per colour so batching is unchanged. World-space noise on
## big flat surfaces (ground, paths), object-space on props. Skips emissive, transparent, unshaded and textured
## materials, so no light or glow changes. Static: nothing here animates.
func _detail_pass(world: Node) -> void:
	var cache := {}
	var shader := load("res://game/render/surface_detail.gdshader") as Shader
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m == null or m.emission_enabled or m.albedo_texture or m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
				or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.vertex_color_use_as_albedo:
			continue
		var big := ((mi as MeshInstance3D).get_aabb().size.x > 6.0 or (mi as MeshInstance3D).get_aabb().size.z > 6.0)
		var key := [m.albedo_color, big]
		if not cache.has(key):
			var sm := ShaderMaterial.new()
			sm.shader = shader
			sm.set_shader_parameter("use_vertex_color", false)
			sm.set_shader_parameter("albedo_color", m.albedo_color)
			sm.set_shader_parameter("world_space", true)
			sm.set_shader_parameter("detail_scale", 2.5 if big else 5.0)
			sm.set_shader_parameter("patch_strength", 0.16 if big else 0.08)
			cache[key] = sm
		(mi as MeshInstance3D).material_override = cache[key]


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look-phase="):
			var parts := a.trim_prefix("--look-phase=").split(":")
			_override_phase = StringName(parts[0])
			_override_p = float(parts[1]) if parts.size() > 1 else 0.5
		elif a.begins_with("--look-shot="):
			_shot = a.trim_prefix("--look-shot=")


func _build_environment() -> void:
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR  # explicit floor, doc 07 s5
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_height = 3.0
	_env.fog_sky_affect = 0.35  # P5-50: let the sky gradient show; fog hazes the land, not the whole sky
	_env.fog_aerial_perspective = 0.4  # P5-50: distance fades toward the sky colour (doc 07 s6)
	_env.glow_enabled = true  # subtle and constant, doc 07 s6; never changed at runtime
	_env.glow_hdr_threshold = 1.2
	_env.glow_intensity = 0.25
	# No auto exposure (doc 07 s5) and no volumetric fog (cost, s6): both are defaults.
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)
	# The Harvest Moon disc (doc 07 s3): unshaded, under the bloom threshold, never animated, not a light.
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.disable_fog = true
	_moon = MeshInstance3D.new()
	_moon.mesh = SphereMesh.new()
	_moon.material_override = moon_mat
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.scale = Vector3.ONE * MOON_R * 2.0  # SphereMesh is 1 m across; _apply scales it per phase
	add_child(_moon)
	var layer := CanvasLayer.new()
	layer.layer = -2  # QA P4-20: every UI CanvasLayer is at the default 1 (hud.gd, menus); negative layers still draw over the 3D world, so grain and vignette sit under all UI and under Taint (-1): doc 07 s6 order, HUD ungraded
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = load("res://game/render/post.gdshader")
	rect.material = _post
	layer.add_child(rect)
	add_child(layer)


func _place_rigs(world: Node) -> void:
	for spot in get_tree().get_nodes_in_group(&"lightrig_spots"):
		if not world.is_ancestor_of(spot):
			continue
		var rig := LightRig.new()
		rig.range_m = float(spot.get_meta(&"radius_m", 6.0))
		if spot.name == &"LightRigDoor":  # the BarnLantern marker also sits under Barn; one fill per room
			rig.fill_range_m = float(INTERIOR_FILL_M.get(String(spot.get_parent().name), 0.0))
		spot.add_child(rig)  # the marker is 3 m up (P1-03); the rig inherits its transform


func _process(_delta: float) -> void:
	_apply(_state())
	_tired_step(_delta)
	if _fixed_cam and _shot == "" and not _fixed_cam.current:
		_fixed_cam.make_current()  # --look-cam in a live session: hold the view over the Player camera
	if _shot != "":
		_frames += 1
		if _frames == 40:
			get_viewport().get_texture().get_image().save_png(_shot)
			print("look_stats frames=%d draws=%d prims=%d stalks=%d cells=%d fps=%d adapter=%s" % [_frames,
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
					corn.stalk_count if corn else 0, corn.cell_count if corn else 0,
					Engine.get_frames_per_second(), RenderingServer.get_video_adapter_name()])
			get_tree().quit()


## Stamina vignette (doc 07 s6 step 3): 0 with a full tank, up to 1 when dry, slewed over about 1.5 s.
func _tired_step(delta: float) -> void:
	if _lp == null or not is_instance_valid(_lp):
		_lp = null
		for n in get_tree().root.find_children("*", "CharacterBody3D", true, false):
			if n.get("is_local") == true:
				_lp = n
		if _lp == null:
			return
	var mx: float = _lp.sprint_max()
	_tired = move_toward(_tired, 1.0 - clampf(_lp.stamina / mx, 0.0, 1.0) if mx > 0.0 else 0.0, delta / 1.5)
	_post.set_shader_parameter(&"tired", _tired)


func _state() -> Dictionary:
	var phase: StringName = _override_phase if _override_phase != &"" else Clock.phase
	var p := _override_p
	if _override_phase == &"":
		var len_s: float = Clock.length_of(phase)
		p = clampf(Clock.t_phase / len_s, 0.0, 1.0) if len_s > 0.0 else 0.0
	match phase:
		&"day":
			var s := NOON.duplicate()
			s.elev = lerpf(DAY_END.elev, NOON.elev, sin(PI * p))  # rises, peaks, sets back to 20
			s.sun_col = NOON.sun_col.lerp(DAY_END.sun_col, p * p)
			return s
		&"dusk":
			return _sample([DAY_END, SUNSET, NIGHT], [0.0, 0.6, 1.0], p)
		&"dawn":
			return _sample([NIGHT, DAWN_MID, DAY_END], [0.0, 0.5, 1.0], p)
		&"harvest_moon":  # no timer (doc 02 s3): ease in from night over HARVEST_EASE_S so there is no pop
			var ease_p := clampf(Clock.t_phase / HARVEST_EASE_S, 0.0, 1.0) if _override_phase == &"" else 1.0
			return _sample([NIGHT, HARVEST], [0.0, 1.0], ease_p)
	return NIGHT


func _sample(keys: Array, at: Array, p: float) -> Dictionary:
	var i := 0
	while i < at.size() - 2 and p > at[i + 1]:
		i += 1
	var t := smoothstep(at[i], at[i + 1], p)
	var out := {}
	for k in keys[i]:
		out[k] = lerp(keys[i][k], keys[i + 1][k], t)
	return out


## Doc 07 s6 quality switch: the "low" preset drops grain and the fog layer. Local-light shadows are
## already off for every LightRig; whoever adds the held lantern's shadow must gate it on this too.
static func low_quality() -> bool:
	return Settings.is_set(&"quality_preset") and str(Settings.get_value(&"quality_preset")) == "low"


func _apply(s: Dictionary) -> void:
	var low := low_quality()
	_sun.rotation_degrees = Vector3(-s.elev, SUN_AZIMUTH, 0.0)
	_sun.light_color = s.sun_col
	_sun.light_energy = s.sun_e
	_env.ambient_light_color = s.amb_col
	_env.ambient_light_energy = s.amb_e * HorrorScares.ambient_mult  # P5-53: the Horror role's own darker world (1.0 for anyone else)
	_env.fog_light_color = s.fog_col
	_env.fog_density = s.fog_d * HorrorScares.fog_mult
	_env.fog_height_density = 0.0 if low else s.fog_d * HorrorScares.fog_mult * 4.0  # ground fog layer (doc 07 s3 night row); off on low (s6)
	_sky.sky_top_color = s.sky_top
	_sky.sky_horizon_color = s.sky_hor
	_sky.ground_horizon_color = s.sky_hor
	_sky.ground_bottom_color = s.fog_col
	LightRig.pool_vis = s.pool
	_post.set_shader_parameter(&"vignette", s.vig)
	_post.set_shader_parameter(&"grain", 0.0 if low else s.grain)
	_env.adjustment_enabled = true
	_env.adjustment_saturation = s.sat
	_env.adjustment_contrast = s.con
	var cam := get_viewport().get_camera_3d()
	_moon.visible = s.moon > 0.01 and cam != null
	if _moon.visible:  # opposite the light direction, so the disc sits where the moonlight comes from
		_moon.global_position = cam.global_position + _sun.global_basis.z * MOON_M
		_moon.scale = Vector3.ONE * MOON_R * 2.0 * s.moon_s
		(_moon.material_override as StandardMaterial3D).albedo_color = s.sky_hor.lerp(s.moon_c, s.moon)


func _cam_arg() -> bool:
	return Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--look-cam="))


## The --look-shot camera. --look-cam alone (no --look-shot) keeps it in a live session, so a screenshot
## (--ui-shot-s) can show this player from another player's side (P3-08 Taint checks).
func _shot_camera() -> void:
	var cam := Camera3D.new()
	var v := Vector3(0, 1.7, 8)
	var yaw := 0.0
	var pitch := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look-cam="):
			var f := a.trim_prefix("--look-cam=").split(",")
			v = Vector3(float(f[0]), float(f[1]), float(f[2]))
			yaw = float(f[3]) if f.size() > 3 else 0.0
			pitch = float(f[4]) if f.size() > 4 else 0.0
	add_child(cam)
	_fixed_cam = cam
	cam.global_position = v
	cam.rotation_degrees = Vector3(pitch, yaw, 0.0)
	get_tree().create_timer(0.3).timeout.connect(cam.make_current)  # the local Player camera is added later
