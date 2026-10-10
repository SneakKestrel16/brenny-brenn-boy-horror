extends SceneTree
## P5-16 before/after renders of the crop stages and corn, day and night, three-quarter view, auto-framed.
## Variant of model_shots.gd: --before draws the gray-box primitive game code uses today (plot.gd box,
## corn_field.gd crossed blades) in place of the .glb. Light values follow game/render/world_look.gd NOON and
## NIGHT (doc 07 s3).
##   godot --path . --audio-driver Dummy --script tools/blender/p5_16_shots.gd -- --before --out=logs/renders/p5_16/before
##   godot --path . --audio-driver Dummy --script tools/blender/p5_16_shots.gd -- --out=logs/renders/p5_16/after

var _out := "logs/renders/p5_16/after"
var _only: PackedStringArray = []
var _before := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a == "--before":
			_before = true
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out))
	get_root().size = Vector2i(640, 480)
	_run()


func _names() -> Array:
	var names := []
	for f in DirAccess.get_files_at("res://assets/models"):
		if f.ends_with(".glb"):
			var n := f.trim_suffix(".glb")
			if (n.begins_with("corn_") or (n.begins_with("crop_") and n != "crop_plot")) and (_only.is_empty() or n in _only):
				names.append(n)
	names.sort()
	return names


## The primitives the game draws today: plot.gd _refresh() boxes and corn_field.gd _stalk_mesh().
func _primitive(name: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	root.add_child(mi)
	if name.begins_with("crop_"):  # growing 0.3, ripe 0.6, wilted 0.15, dead 0.2
		var kind: String = name.split("_")[1]
		var hue := fposmod(float(hash(kind)), 360.0) / 360.0
		var h := 0.3
		m.albedo_color = Color.from_hsv(hue, 0.7, 0.7)
		if name.ends_with("stage3"):
			h = 0.6
			m.albedo_color = Color.from_hsv(hue, 0.8, 0.95)
		elif name.ends_with("wilted"):
			h = 0.15
			m.albedo_color = Color(0.45, 0.4, 0.3)
		elif name.ends_with("rotten") or name.ends_with("taint"):
			h = 0.2
			m.albedo_color = Color(0.05, 0.03, 0.05)
		var b := BoxMesh.new()
		b.size = Vector3(0.6, h, 0.6)
		mi.mesh = b
		mi.position.y = h / 2.0
	elif name in ["corn_card_lod2", "corn_wall_band", "corn_stalk_cut"]:
		var b := BoxMesh.new()
		b.size = {"corn_card_lod2": Vector3(1, 2.4, 0.2), "corn_wall_band": Vector3(4, 2.4, 0.5), "corn_stalk_cut": Vector3(1, 0.05, 1)}[name]
		mi.mesh = b
		mi.position.y = b.size.y / 2.0
		m.albedo_color = Color(0.26, 0.38, 0.11)
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ang in [0.0, PI * 0.5]:
			var d := Vector3(cos(ang), 0.0, sin(ang))
			var top := Vector3.UP * 2.4
			for v in [-d * 0.3, d * 0.3, d * 0.08 + top, -d * 0.3, d * 0.08 + top, -d * 0.08 + top]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		mi.mesh = st.commit()
		m.albedo_color = Color(0.3, 0.4, 0.12)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return root


func _aabb(n: Node, acc: Array) -> void:
	if n is MeshInstance3D and n.mesh:
		var box: AABB = (n as MeshInstance3D).global_transform * n.mesh.get_aabb()
		acc[0] = box if acc[0] == null else (acc[0] as AABB).merge(box)
	for c in n.get_children():
		_aabb(c, acc)


func _run() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	var lamp := OmniLight3D.new()  # night only: a held-lantern stand-in, 1.2 m up and to the front
	lamp.light_color = Color("FFB060")
	lamp.omni_range = 6.0
	lamp.shadow_enabled = false
	world.add_child(lamp)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.29, 0.18)  # plot soil #6B4A2F, doc 07 s2
	gm.roughness = 1.0
	ground.material_override = gm
	world.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	await process_frame
	for name in _names():
		var inst: Node3D
		if _before:
			inst = _primitive(name)
		else:
			inst = (load("res://assets/models/%s.glb" % name) as PackedScene).instantiate()
		world.add_child(inst)
		var acc := [null]
		_aabb(inst, acc)
		var box: AABB = acc[0] if acc[0] != null else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
		var ctr := box.get_center()
		var r := box.size.length() * 0.5
		var dist := maxf(r / tan(deg_to_rad(cam.fov * 0.5)) * 1.05, 0.6)
		var dir := Vector3(0.65, 0.4, -1.0).normalized()
		cam.look_at_from_position(ctr + dir * dist, ctr)
		lamp.position = ctr + Vector3(0.5, 0.4, -1.0).normalized() * (r + 0.8)
		for look in ["day", "night"]:
			if look == "day":
				sun.rotation_degrees = Vector3(-55, -30, 0)
				sun.light_color = Color("FFE2B0")
				sun.light_energy = 1.2
				env.background_mode = Environment.BG_COLOR
				env.background_color = Color("8FB4DC")
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = Color("FFF1D8")
				env.ambient_light_energy = 0.8
				env.adjustment_enabled = true
				env.adjustment_saturation = 1.15
				lamp.visible = false
			else:
				sun.rotation_degrees = Vector3(-35, -30, 0)
				sun.light_color = Color("8FA8D8")
				sun.light_energy = 0.12
				env.background_mode = Environment.BG_COLOR
				env.background_color = Color("0A0F20")
				env.ambient_light_color = Color("7088D0")
				env.ambient_light_energy = 0.25
				env.adjustment_saturation = 0.7
				lamp.visible = true
				lamp.light_energy = 1.5
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			await process_frame
			await process_frame
			await process_frame
			var img := get_root().get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path("res://%s/%s_%s.png" % [_out, name, look]))
		inst.queue_free()
		await process_frame
	print("SHOTS_DONE ", _out)
	quit()
