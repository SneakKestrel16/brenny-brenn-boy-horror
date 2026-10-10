extends SceneTree
## P5-12 farmer check: lists the rig and animations, then renders key frames of each animation to a contact sheet.
##   godot --path . --audio-driver Dummy --script tools/blender/farmer_poses.gd -- --out=logs/renders/p5_12/after [--only=walk,run]
## Prints: skeleton bones, animation names/lengths/loop flags, AABB at rest. Writes <out>/farmer_<anim>.png (frames side by side, front and side view).

var _out := "logs/renders/p5_12/after"
var _only: PackedStringArray = []
const FRAMES := 6


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out))
	get_root().size = Vector2i(1280, 720)
	_run()


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


func _run() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8FB4DC")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("FFF1D8")
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.30, 0.34, 0.22)
	ground.material_override = gm
	world.add_child(ground)
	var cap := MeshInstance3D.new()  # 1.8 m capsule for scale, beside the farmer
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.8
	cap.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1, 1, 1, 0.25)
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cap.material_override = cmat
	cap.position = Vector3(1.0, 0.9, 0)
	world.add_child(cap)
	var cam := Camera3D.new()
	cam.fov = 32.0
	world.add_child(cam)
	cam.current = true
	var scene: PackedScene = load("res://assets/models/char_farmer.glb")
	var inst: Node3D = scene.instantiate()
	world.add_child(inst)
	await process_frame
	var sk := _find(inst, "Skeleton3D") as Skeleton3D
	var ap := _find(inst, "AnimationPlayer") as AnimationPlayer
	print("SKELETON ", sk != null, " bones=", sk.get_bone_count() if sk else 0)
	if sk:
		for i in sk.get_bone_count():
			print("  bone ", i, " ", sk.get_bone_name(i), " parent=", sk.get_bone_parent(i))
	var names := PackedStringArray()
	if ap:
		for n in ap.get_animation_list():
			var an := ap.get_animation(n)
			print("ANIM ", n, " len=", an.length, " loop=", an.loop_mode, " tracks=", an.get_track_count())
			names.append(n)
	else:
		print("NO AnimationPlayer")
		quit()
		return
	var box := AABB()
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var m := c as MeshInstance3D
		box = box.merge(m.global_transform * m.get_aabb()) if box.size != Vector3.ZERO else m.global_transform * m.get_aabb()
	print("REST_AABB ", box)
	for n in names:
		if n == "RESET" or (not _only.is_empty() and not n in _only):
			continue
		var an := ap.get_animation(n)
		ap.play(n)
		ap.pause()
		for view in ["front", "side"]:
			var tiles: Array[Image] = []
			for k in FRAMES:
				var t := an.length * float(k) / float(FRAMES)
				ap.seek(t, true)
				for i in 3:
					await process_frame
				if view == "front":
					cam.look_at_from_position(Vector3(0.0, 1.0, -5.0), Vector3(0, 0.9, 0))
				else:
					cam.look_at_from_position(Vector3(5.0, 1.0, 0.0), Vector3(0, 0.9, 0))
				cap.visible = false
				for i in 2:
					await process_frame
				var img := get_root().get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				var r := Rect2i(440, 60, 400, 600)
				tiles.append(img.get_region(r))
			var sheet := Image.create(400 * FRAMES, 600, false, Image.FORMAT_RGBA8)
			for k in FRAMES:
				sheet.blit_rect(tiles[k], Rect2i(0, 0, 400, 600), Vector2i(400 * k, 0))
			sheet.resize(200 * FRAMES, 300)
			sheet.save_png(ProjectSettings.globalize_path("res://%s/farmer_%s_%s.png" % [_out, n, view]))
	print("POSES_DONE")
	quit()
