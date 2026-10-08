class_name CornField
extends Node3D
## Doc 07 section 10.1: corn visuals only. Sight blocking is the layer 5 CornBlockers (Level Designer,
## Q-026); this node hides their gray-box meshes and draws, per 16 m cell, a MultiMesh of stalks near
## the camera and one box impostor far away. Culling by cell, LOD by visibility range, sway in
## corn.gdshader. All numbers are placeholder/unmeasured (doc 07 s10.2).

const CELL_M := 16.0  ## doc 07 s10.1
const PER_M2 := 6.0  ## stalks per m2 (placeholder, doc 07 s10.1)
const NEAR_M := 30.0  ## stalks inside this range, impostor box beyond (placeholder; doc says 35)
const HEIGHT_M := 2.4  ## doc 01 "Corn", doc 07 s10

var stalk_count := 0
var cell_count := 0


func build(blockers: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007  # same stalks on every peer
	var stalk := _stalk_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/render/corn.gdshader")
	var far_mat := StandardMaterial3D.new()
	far_mat.albedo_color = Color(0.26, 0.38, 0.11)
	far_mat.roughness = 0.95
	for body in blockers.get_children():
		var mi := body.get_node_or_null("Mesh") as MeshInstance3D
		if mi == null or not mi.mesh is BoxMesh:
			continue
		var box := mi.mesh as BoxMesh
		mi.visible = false
		var c := mi.global_position
		var lo := Vector2(c.x - box.size.x * 0.5, c.z - box.size.z * 0.5)
		var hi := Vector2(c.x + box.size.x * 0.5, c.z + box.size.z * 0.5)
		var x := lo.x
		while x < hi.x - 0.01:
			var x2 := minf(x + CELL_M, hi.x)
			var z := lo.y
			while z < hi.y - 0.01:
				var z2 := minf(z + CELL_M, hi.y)
				_cell(Rect2(x, z, x2 - x, z2 - z), stalk, mat, far_mat, rng)
				z = z2
			x = x2


func _cell(r: Rect2, stalk: Mesh, mat: Material, far_mat: Material, rng: RandomNumberGenerator) -> void:
	var n := int(r.get_area() * PER_M2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = stalk
	mm.instance_count = n
	for i in n:
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.1))
		var o := Vector3(r.position.x + rng.randf() * r.size.x, 0.0, r.position.y + rng.randf() * r.size.y)
		mm.set_instance_transform(i, Transform3D(b, o))
	var near := MultiMeshInstance3D.new()
	near.multimesh = mm
	near.material_override = mat
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # corn shadows are the first cut
	near.visibility_range_end = NEAR_M
	near.visibility_range_end_margin = 4.0
	add_child(near)
	var far := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(r.size.x, HEIGHT_M, r.size.y)
	far.mesh = box
	far.material_override = far_mat
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.position = Vector3(r.get_center().x, HEIGHT_M * 0.5, r.get_center().y)
	far.visibility_range_begin = NEAR_M
	far.visibility_range_begin_margin = 4.0
	add_child(far)
	stalk_count += n
	cell_count += 1


## Two crossed tapered blades, 4 triangles, double-sided in the shader. Origin at the ground.
func _stalk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ang in [0.0, PI * 0.5]:
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var bl := -d * 0.3
		var br := d * 0.3
		var tl := -d * 0.08 + Vector3.UP * HEIGHT_M
		var tr := d * 0.08 + Vector3.UP * HEIGHT_M
		for v in [bl, br, tr, bl, tr, tl]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()
