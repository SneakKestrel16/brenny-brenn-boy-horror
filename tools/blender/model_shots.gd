extends SceneTree
## P5-12 before/after renders: every assets/models/*.glb in day and night light, three-quarter view
## from the front (-Z side), auto-framed, saved as <out>/<name>_<day|night>.png.
## Light values follow game/render/world_look.gd NOON and NIGHT (doc 07 s3).
##   godot --path . --audio-driver Dummy --script tools/blender/model_shots.gd -- --out=logs/renders/p5_12/before [--only=a,b]

var _out := "logs/renders/p5_12/after"
var _only: PackedStringArray = []
var _before := false  # P5-17: draw primitive stand-ins instead of the glb


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


## P5-17 "before": the primitives the game draws today for models that did not exist yet (crow and dead crow boxes
## in game code, TaintLook forearm capsules, the player capsule for ghost and ragdoll, bare post and box for road items).
func _mesh(m: Mesh, pos: Vector3, rot_deg := Vector3.ZERO, col := Color.WHITE, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col, alpha)
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _standin(name: String) -> Node3D:
	var n := Node3D.new()
	match name:
		"animal_crow":
			n.add_child(_mesh(_box(Vector3(0.15, 0.2, 0.3)), Vector3(0, 0.1, 0), Vector3.ZERO, Color(0.08, 0.08, 0.1)))
		"prop_dead_crow":
			n.add_child(_mesh(_box(Vector3(0.3, 0.1, 0.15)), Vector3(0, 0.05, 0), Vector3.ZERO, Color(0.08, 0.08, 0.1)))
		"tool_hands":
			for s in [-1.0, 1.0]:
				n.add_child(_mesh(_capsule(0.045, 0.42), Vector3(0.24 * s, -0.4, -0.36), Vector3(-62, 22 * s, 0), Color(0.6, 0.45, 0.35)))
		"prop_road_sign":
			n.add_child(_mesh(_box(Vector3(0.08, 2.0, 0.08)), Vector3(0, 1.0, 0), Vector3.ZERO, Color(0.35, 0.3, 0.25)))
			n.add_child(_mesh(_box(Vector3(0.4, 0.25, 0.03)), Vector3(0, 1.75, 0), Vector3.ZERO, Color(0.7, 0.7, 0.7)))
		"prop_road_lamp":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.06
			cyl.bottom_radius = 0.08
			cyl.height = 3.2
			n.add_child(_mesh(cyl, Vector3(0, 1.6, 0), Vector3.ZERO, Color(0.2, 0.2, 0.22)))
			n.add_child(_mesh(_box(Vector3(0.25, 0.25, 0.25)), Vector3(0, 3.35, 0), Vector3.ZERO, Color(1.0, 0.8, 0.5)))
		"char_farmer_ragdoll":
			n.add_child(_mesh(_capsule(0.35, 1.8), Vector3(0, 0.35, 0), Vector3(90, 0, 0), Color(0.6, 0.6, 0.6)))
		"char_ghost":
			n.add_child(_mesh(_capsule(0.35, 1.8), Vector3(0, 0.9, 0), Vector3.ZERO, Color(0.75, 0.85, 1.0), 0.45))
	return n


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
		var inst: Node3D
		if _before:
			inst = _standin(name)
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
