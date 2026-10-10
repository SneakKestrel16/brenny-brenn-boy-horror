extends SceneTree
## P5-51: top-down (orthographic) PNG of the whole farm. Windowed run:
##   "$GODOT" --audio-driver Dummy --path . -s res://tests/creature/shot_p5_51.gd -- --host --lobby-start=1 --no-intro --port=56320 --free-mouse --out=<png>
var _f := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_f += 1
	if _f == 200:
		# Corn from above is only thin wall bands, so draw each blocker as a flat slab: Weave orange, the rest green.
		for b: Node3D in root.get_node("Main/World/CornBlockers").get_children():
			var sz: Vector3 = (b.get_node("Mesh") as MeshInstance3D).mesh.size
			var m := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(sz.x, 0.5, sz.z)
			m.mesh = bm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.45, 0.1) if String(b.name).begins_with("Weave") else Color(0.1, 0.6, 0.1)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.material_override = mat
			b.add_child(m)
			m.global_position = Vector3(b.global_position.x, 4.0, b.global_position.z)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 190.0
		cam.far = 400.0
		root.add_child(cam)
		cam.global_position = Vector3(20, 150, 0)
		cam.rotation_degrees = Vector3(-90, 0, 0)
		cam.current = true
	if _f == 260:
		var out := "user://topdown.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--out="):
				out = a.get_slice("=", 1)
		root.get_viewport().get_texture().get_image().save_png(out)
		quit()
	return false
