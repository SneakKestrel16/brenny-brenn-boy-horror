@tool
extends EditorScenePostImport
## Gray-box models keep flat colour in the glTF COLOR_0 layer. Godot does not enable
## vertex colour as albedo on import, so turn it on for every material. See P4-16 handoff.


## P5-59: set false (and reimport the models) to keep the plain imported material instead of the shared
## detail shader material. Creatures also get it from CreatureLook either way.
const USE_DETAIL_MATERIAL := true
const FLAT := "res://assets/materials/mat_flat_lit.tres"
## QA P5-59: runtime code duplicates these models' material as StandardMaterial3D (plot.gd wet soil,
## trap_art.gd D-055 glow), so they keep the plain imported material.
const KEEP_PLAIN := ["crop_plot", "trap_"]

var _swap := USE_DETAIL_MATERIAL


func _post_import(scene: Node) -> Object:
	_swap = USE_DETAIL_MATERIAL
	for k in KEEP_PLAIN:
		if get_source_file().get_file().begins_with(k):
			_swap = false
	_walk(scene)
	return scene


func _walk(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m := n.mesh.surface_get_material(i) as BaseMaterial3D
			if m:
				m.vertex_color_use_as_albedo = true
				m.vertex_color_is_srgb = false
				if _swap and m.resource_name == "mat_flat_lit":
					n.mesh.surface_set_material(i, load(FLAT))
	for c in n.get_children():
		_walk(c)
