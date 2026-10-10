extends SceneTree
## P5-12 before/after renders: every assets/models/*.glb in day and night light, three-quarter view
## from the front (-Z side), auto-framed, saved as <out>/<name>_<day|night>.png.
## Light values follow game/render/world_look.gd NOON and NIGHT (doc 07 s3).
##   godot --path . --audio-driver Dummy --script tools/blender/model_shots.gd -- --out=logs/renders/p5_12/before [--only=a,b]

var _out := "logs/renders/p5_12/after"
var _only: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
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
			if _only.is_empty() or n in _only:
				names.append(n)
	names.sort()
	return names


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
	gm.albedo_color = Color(0.30, 0.34, 0.22)
	gm.roughness = 1.0
	ground.material_override = gm
	world.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	await process_frame
	for name in _names():
		var scene: PackedScene = load("res://assets/models/%s.glb" % name)
		var inst: Node3D = scene.instantiate()
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
