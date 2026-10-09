@tool
extends EditorScenePostImport
## Gray-box models keep flat colour in the glTF COLOR_0 layer. Godot does not enable
## vertex colour as albedo on import, so turn it on for every material. See P4-16 handoff.


func _post_import(scene: Node) -> Object:
	_walk(scene)
	return scene


func _walk(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m := n.mesh.surface_get_material(i) as BaseMaterial3D
			if m:
				m.vertex_color_use_as_albedo = true
				m.vertex_color_is_srgb = false
	for c in n.get_children():
		_walk(c)
