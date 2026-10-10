extends SceneTree
## P5-06 renders: every cosmetic on the farmer, day and night (light values as model_shots.gd, doc 07 s3).
## Hats go on a BoneAttachment3D on the `hat` bone; overalls overlays are re-parented into the farmer's Skeleton3D
## (same bone names), and the tint is set on mat_farmer_overalls. Output <out>/<id>_<view>_<day|night>.png.
##   godot --path . --audio-driver Dummy --script tools/blender/cosmetic_shots.gd -- --out=logs/renders/p5_06 [--only=flat_cap,...]

var _out := "logs/renders/p5_06"
var _only: PackedStringArray = []
const PLAYER := Color("C04040")  # player colour red (D-159), used when the overalls keep the player tint
const HATS := ["flat_cap", "bucket_hat", "tin_pot", "party_cone", "turnip_crown", "top_hat"]
const OVERALLS := ["denim", "patched", "striped", "plaid", "gold"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out))
	get_root().size = Vector2i(800, 800)
	_run()


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


func _extras(n: Node) -> Dictionary:  # glTF extras land as "extras" metadata on whichever node carries them
	var e = n.get_meta("extras") if n.has_meta("extras") else null
	if e is Dictionary and e.has("tint"):
		return e
	for c in n.get_children():
		var r := _extras(c)
		if not r.is_empty():
			return r
	return {}


func _tint(farmer: Node, col: Color) -> void:
	for m in farmer.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat and mat.resource_name == "mat_farmer_overalls":
				var c := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				c.albedo_color = col
				mi.set_surface_override_material(i, c)


func _dress(kind: String, id: String) -> Node3D:
	var farmer: Node3D = (load("res://assets/models/char_farmer.glb") as PackedScene).instantiate()
	var sk := _find(farmer, "Skeleton3D") as Skeleton3D
	_tint(farmer, PLAYER)
	if kind == "hat":
		var ba := BoneAttachment3D.new()
		ba.bone_name = "hat"
		sk.add_child(ba)
		ba.add_child((load("res://assets/models/char_hat_%s.glb" % id) as PackedScene).instantiate())
	else:
		var ov: Node = (load("res://assets/models/char_overalls_%s.glb" % id) as PackedScene).instantiate()
		var arm := _find(ov, "Skeleton3D") as Skeleton3D
		var extras = _extras(ov)
		print("OVERALLS ", id, " extras=", extras, " children=", arm.get_child_count())
		for c in arm.get_children():
			c.owner = null
			arm.remove_child(c)
			sk.add_child(c)
			(c as MeshInstance3D).skeleton = NodePath("..")
		var tint = extras.get("tint", "player") if extras is Dictionary else "player"
		_tint(farmer, PLAYER if str(tint) == "player" else Color(str(tint)))
		ov.free()
	return farmer


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
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("FFB060")
	lamp.omni_range = 6.0
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
	cam.fov = 32.0
	world.add_child(cam)
	cam.current = true
	await process_frame
	var jobs := []
	for h in HATS:
		jobs.append(["hat", h, [["head", Vector3(0.8, 1.8, -1.5), Vector3(0, 1.72, 0)], ["body", Vector3(1.4, 1.2, -3.6), Vector3(0, 0.95, 0)]]])
	for o in OVERALLS:
		jobs.append(["overalls", o, [["front", Vector3(1.0, 1.15, -3.4), Vector3(0, 0.88, 0)], ["back", Vector3(-1.0, 1.15, 3.4), Vector3(0, 0.88, 0)],
			["legs", Vector3(1.2, 0.7, -2.2), Vector3(0, 0.55, 0)]]])
	for job in jobs:
		var id: String = job[1]
		if not _only.is_empty() and not id in _only:
			continue
		var farmer := _dress(job[0], id)
		world.add_child(farmer)
		var ap := _find(farmer, "AnimationPlayer") as AnimationPlayer
		if job[0] == "overalls" and ap:  # mid-stride, proves the overlay follows the bones
			ap.play("walk")
			ap.pause()
			ap.seek(0.2, true)
		await process_frame
		for v in job[2]:
			cam.look_at_from_position(v[1], v[2])
			lamp.position = v[2] + (v[1] - v[2]).normalized() * 1.2 + Vector3(0.4, 0.4, 0)
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
					env.background_color = Color("0A0F20")
					env.ambient_light_color = Color("7088D0")
					env.ambient_light_energy = 0.25
					env.adjustment_saturation = 0.7
					lamp.visible = true
					lamp.light_energy = 1.5
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				for i in 3:
					await process_frame
				get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://%s/%s_%s_%s.png" % [_out, id, v[0], look]))
		farmer.queue_free()
		await process_frame
	print("SHOTS_DONE ", _out)
	quit()
