extends SceneTree
## P5-14 before/after renders: the gray-box farm (res://game/world/farm.tscn) with the P5-14 models swapped in, day and night.
## before = gray-box primitives as they are; after = those primitives hidden, models placed at the same transforms.
## Light values follow game/render/world_look.gd NOON and NIGHT (doc 07 s3).
##   godot --path . --audio-driver Dummy --script tools/blender/p5_14_shots.gd -- --mode=before|after [--out=logs/renders/p5_14]
## Placement rules the game code will need are the ones used here (also in production/handoffs/P5-14.md).

var _out := "logs/renders/p5_14"
var _after := false
var _open := false  # --mode=after --open: door leaves swung 90 degrees toward +Z (Q-307: yaw from host door state)
var _farm: Node3D
var _added: Array[Node3D] = []

# name, camera position, look-at target
const SHOTS := [
	["barn", Vector3(24, 10, 26), Vector3(0, 3, -9)],
	["barn_door", Vector3(5, 2.4, 9), Vector3(0, 1.8, 0)],
	["farmhouse", Vector3(-27, 6.5, 16), Vector3(-45, 2.5, -5)],
	["farmhouse_door", Vector3(-41, 2.2, 7), Vector3(-45, 1.5, 0)],
	["shed", Vector3(-6, 4.5, 14), Vector3(-15, 1.5, 28.5)],
	["shed_door", Vector3(-11, 2.0, 21), Vector3(-15, 1.3, 26)],
	["well", Vector3(-21, 2.8, 5), Vector3(-25, 1.0, 10)],
	["pen", Vector3(-12, 8, -14), Vector3(-24, 0.6, -33)],
	["farm_gate", Vector3(96, 3.2, 3), Vector3(105, 1.1, -5)],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a == "--mode=after":
			_after = true
		elif a == "--open":
			_open = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://%s/%s" % [_out, _dir()]))
	get_root().size = Vector2i(960, 640)
	_run()


func _dir() -> String:
	return ("after_open" if _open else "after") if _after else "before"


func _hide_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).visible = false
	for c in n.get_children():
		_hide_meshes(c)


func _put(model: String, pos: Vector3, yaw_deg := 0.0, scale_x := 1.0) -> void:
	var inst: Node3D = (load("res://assets/models/%s.glb" % model) as PackedScene).instantiate()
	_farm.add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	inst.scale.x = scale_x
	_added.append(inst)


func _swap_in() -> void:
	# Buildings: origin is the door threshold, same as the gray-box node, so the transform is copied as is.
	for pair in [["Barn", "bldg_barn", "prop_door_barn"], ["Farmhouse", "bldg_farmhouse", "prop_door_farmhouse"], ["ToolShed", "bldg_shed", "prop_door_shed"]]:
		var b: Node3D = _farm.get_node("Buildings/" + pair[0])
		_hide_meshes(b)
		_put(pair[1], b.global_position)
		_put(pair[2], b.global_position)
		if _open:
			(_added[-1].find_child("LeafL") as Node3D).rotation_degrees.y = -90.0
			(_added[-1].find_child("LeafR") as Node3D).rotation_degrees.y = 90.0
	# Well: gray-box box is centred at y 0.5 (1 m tall); the model origin is the base.
	var well: Node3D = _farm.get_node("Props/Well")
	_hide_meshes(well)
	_put("prop_well", Vector3(well.global_position.x, 0, well.global_position.z))
	# Pen: n = round(L / 3) segments per section, X scaled L / (3 n); W and E sections yaw 90 degrees.
	for nm in ["NorthW", "NorthE", "WestN", "WestS", "EastN", "EastS", "SouthL", "SouthR"]:
		var s: Node3D = _farm.get_node("Pen/" + nm)
		var size: Vector3 = ((s.get_node("Mesh") as MeshInstance3D).mesh as BoxMesh).size
		var along_z := size.z > size.x
		var length := maxf(size.x, size.z)
		var n := int(round(length / 3.0))
		var step := length / n
		_hide_meshes(s)
		for k in n:
			var off := -length / 2.0 + step * (k + 0.5)
			var p := s.global_position + (Vector3(0, 0, off) if along_z else Vector3(off, 0, 0))
			_put("prop_fence_segment", Vector3(p.x, 0, p.z), 90.0 if along_z else 0.0, step / 3.0)
	var pg: Node3D = _farm.get_node("Pen/PenGate")
	_put("prop_fence_gate", Vector3(pg.global_position.x, 0, pg.global_position.z))
	# Farm gate: posts at z -8 and -2 (span along Z), model spans X, so yaw 90.
	for nm in ["GatePostN", "GatePostS"]:
		_hide_meshes(_farm.get_node("Props/" + nm))
	var fg: Node3D = _farm.get_node("Props/FarmGate")
	_put("prop_farm_gate", Vector3(fg.global_position.x, 0, fg.global_position.z), 90.0)


func _run() -> void:
	_farm = (load("res://game/world/farm.tscn") as PackedScene).instantiate()
	get_root().add_child(_farm)
	var env := Environment.new()
	var we := WorldEnvironment.new()
	we.environment = env
	_farm.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	_farm.add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("FFB060")
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	_farm.add_child(lamp)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 300.0
	_farm.add_child(cam)
	cam.current = true
	await process_frame
	if _after:
		_swap_in()
	for s in SHOTS:
		cam.look_at_from_position(s[1], s[2])
		lamp.position = s[1] + (s[2] - s[1]).normalized() * 2.0 + Vector3(0, 1, 0)
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
			get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://%s/%s/%s_%s.png" % [_out, _dir(), s[0], look]))
	print("SHOTS_DONE ", _out)
	quit()
