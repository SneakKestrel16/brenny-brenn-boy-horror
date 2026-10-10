class_name CornField
extends Node3D
## Doc 07 section 10.1: corn visuals only. Sight blocking is the layer 5 CornBlockers (Level Designer,
## Q-026); this node hides their gray-box meshes and draws, per 16 m cell, a MultiMesh of stalks near
## the camera and one box impostor far away. Culling by cell, LOD by visibility range, sway in
## corn.gdshader. All numbers are placeholder/unmeasured (doc 07 s10.2).

const CELL_M := 16.0  ## doc 07 s10.1
const PER_M2 := 6.0  ## stalks per m2 (placeholder, doc 07 s10.1)
const NEAR_M := 30.0  ## stalks inside this range, impostor box beyond (placeholder; doc says 35)
const LOD0_M := 12.0  ## corn_stalk_lod0 inside this range, corn_stalk_lod1 out to NEAR_M (doc 07 s10.1, s11.6; P5-22)
const HEIGHT_M := 2.4  ## doc 01 "Corn", doc 07 s10
const LOD_OVERLAP_M := 3.0  ## lod1 starts this far inside LOD0_M so no band is empty while the LOD swaps
const CARD_PER_M2 := 2.0  ## corn_card_lod2 under the stalks: the thin lod stalks alone let sight through (QA P5-22)
const BAND_M := 4.0  ## corn_wall_band tile length

var stalk_count := 0
var cell_count := 0


func build(blockers: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007  # same stalks on every peer
	var stalk0 := _glb_mesh("corn_stalk_lod0")
	var stalk1 := _glb_mesh("corn_stalk_lod1")
	var card := _glb_mesh("corn_card_lod2", "Card")
	var band := _glb_mesh("corn_wall_band", "Band")
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/render/corn.gdshader")
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
				_cell(Rect2(x, z, x2 - x, z2 - z), [stalk0, stalk1, card, band], mat, rng)
				z = z2
			x = x2


func _cell(r: Rect2, meshes: Array, mat: Material, rng: RandomNumberGenerator) -> void:
	var n := int(r.get_area() * PER_M2)
	var xf: Array[Transform3D] = []
	for i in n:
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.1))
		var o := Vector3(r.position.x + rng.randf() * r.size.x, 0.0, r.position.y + rng.randf() * r.size.y)
		xf.append(Transform3D(b, o))
	# lod0 up close, lod1 out to NEAR_M (overlapping), cards under both for opacity
	_multi(meshes[0], xf, mat, 0.0, LOD0_M)
	_multi(meshes[1], xf, mat, LOD0_M - LOD_OVERLAP_M, NEAR_M)
	var cards: Array[Transform3D] = []
	for i in int(r.get_area() * CARD_PER_M2):
		cards.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(r.position.x + rng.randf() * r.size.x, 0.0, r.position.y + rng.randf() * r.size.y)))
	_multi(meshes[2], cards, mat, 0.0, NEAR_M)
	# far: corn_wall_band tiles round the cell edge (doc 07 s10.1, s11.6)
	var tiles: Array[Transform3D] = []
	for side in 4:
		var along_x := side < 2
		var len := r.size.x if along_x else r.size.y
		var cnt := maxi(1, ceili(len / BAND_M))
		var fixed := (r.position.y + (0.25 if side == 0 else r.size.y - 0.25)) if along_x else (r.position.x + (0.25 if side == 2 else r.size.x - 0.25))
		for k in cnt:
			var t := r.position.x if along_x else r.position.y
			t += (k + 0.5) * len / cnt
			var b := Basis.IDENTITY.scaled(Vector3(len / cnt / BAND_M, 1, 1))
			if not along_x:
				b = Basis(Vector3.UP, PI * 0.5) * b
			tiles.append(Transform3D(b, Vector3(t, 0.0, fixed) if along_x else Vector3(fixed, 0.0, t)))
	_multi(meshes[3], tiles, mat, NEAR_M, 0.0)
	stalk_count += n
	cell_count += 1


## One MultiMesh of `xf`, drawn between `from` and `to` metres (0 = no limit); ranges overlap, no fade.
func _multi(mesh: Mesh, xf: Array[Transform3D], mat: Material, from: float, to: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # corn shadows are the first cut
	mi.visibility_range_begin = from
	mi.visibility_range_end = to
	add_child(mi)


## A P5-16 corn model's mesh (doc 07 s11.6); origin at the ground, one surface. corn.gdshader replaces its material.
func _glb_mesh(model: String, node := "Stalk") -> Mesh:
	var inst := (load("res://assets/models/%s.glb" % model) as PackedScene).instantiate()
	var mesh := (inst.find_child(node, true, false) as MeshInstance3D).mesh
	inst.free()
	return mesh
