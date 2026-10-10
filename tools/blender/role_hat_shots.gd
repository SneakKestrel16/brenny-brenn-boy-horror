extends SceneTree
## P5-40: each of the ten role hats (hat_<role>.glb) on the shipped farmer, four sides in one sheet per role.
##   godot --path . --audio-driver Dummy --script tools/blender/role_hat_shots.gd -- --out=logs/renders/p5_40_role_hats --free-mouse

const ROLES := ["farmer", "rancher", "mechanic", "tracker", "carpenter", "medic", "night_owl", "radio_operator", "warden", "medium"]
var _out := "logs/renders/p5_40_role_hats"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out))
	get_root().size = Vector2i(480, 480)
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
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 28.0
	world.add_child(cam)
	cam.current = true
	await process_frame
	for role in ROLES:
		var farmer: Node3D = (load("res://assets/models/char_farmer.glb") as PackedScene).instantiate()
		var sk := _find(farmer, "Skeleton3D") as Skeleton3D
		var ba := BoneAttachment3D.new()
		ba.bone_name = "hat"
		sk.add_child(ba)
		ba.add_child((load("res://assets/models/hat_%s.glb" % role) as PackedScene).instantiate())
		world.add_child(farmer)
		await process_frame
		var sheet := Image.create(1920, 480, false, Image.FORMAT_RGBA8)
		var i := 0
		for ang in [0.0, 90.0, 180.0, 270.0]:
			var d := Vector3(0, 0.25, -1.4).rotated(Vector3.UP, deg_to_rad(ang))
			cam.look_at_from_position(Vector3(0, 1.72, 0) + d, Vector3(0, 1.72, 0))
			for k in 3:
				await process_frame
			var im := get_root().get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			var s := mini(im.get_width(), im.get_height())  # the window ignores the size set above: crop the centre square
			im = im.get_region(Rect2i((im.get_width() - s) / 2, (im.get_height() - s) / 2, s, s))
			im.resize(480, 480)
			sheet.blit_rect(im, Rect2i(0, 0, 480, 480), Vector2i(i * 480, 0))
			i += 1
		sheet.save_png(ProjectSettings.globalize_path("res://%s/%s.png" % [_out, role]))
		farmer.queue_free()
		await process_frame
	print("SHOTS_DONE ", _out)
	quit()
