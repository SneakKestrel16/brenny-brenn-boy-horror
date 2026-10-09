class_name TrapArt
## Placeholder trap meshes until the Technical Artist's models (doc 07 `trap_glint.glb` and friends).
## D-055 (CEO 2026-10-08): set traps get a plainly visible basic mesh; the doc 03 section 9 "4 m clue
## only" rule is paused until art. Built from primitives; a faint emission keeps them readable at night.

const STEEL := Color(0.42, 0.42, 0.45)
const DIRT := Color(0.42, 0.27, 0.14)


## A bear trap, open: a steel ring, a row of teeth up its rim, the pan in the middle. Origin on the ground.
## `sprung` (P4-29): the teeth fold in over the pan, jaws shut, so a sprung trap reads as spent.
static func bear(sprung := false) -> Node3D:
	var root := Node3D.new()
	var mat := _mat(STEEL, 0.35, 0.8)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.33
	ring.outer_radius = 0.40
	root.add_child(_part(ring, mat, Vector3(0, 0.035, 0)))
	var pan := CylinderMesh.new()
	pan.top_radius = 0.12
	pan.bottom_radius = 0.12
	pan.height = 0.03
	root.add_child(_part(pan, mat, Vector3(0, 0.02, 0)))
	for i in 14:  # teeth stand up on the ring like open jaws
		var a := TAU * i / 14.0
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.05, 0.14, 0.03)
		var t := _part(tooth, mat, Vector3(cos(a) * 0.365, 0.1, sin(a) * 0.365))
		t.rotation.y = -a
		if sprung:
			t.rotation.z = 1.1  # leans the tooth toward the middle (local x points out from the ring)
		root.add_child(t)
	for s in [-1, 1]:  # the springs either side
		var spring := BoxMesh.new()
		spring.size = Vector3(0.22, 0.05, 0.07)
		root.add_child(_part(spring, mat, Vector3(s * 0.5, 0.025, 0)))
	return root


## A pit: a black hole with a raised dirt rim. Origin on the ground.
static func pit() -> Node3D:
	var root := Node3D.new()
	var hole := CylinderMesh.new()
	hole.top_radius = 0.75
	hole.bottom_radius = 0.75
	hole.height = 0.02
	root.add_child(_part(hole, _mat(Color(0.02, 0.015, 0.01), 0.0, 0.0), Vector3(0, 0.012, 0)))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.72
	rim.outer_radius = 1.0
	var r := _part(rim, _mat(DIRT, 0.25, 0.0), Vector3(0, 0.03, 0))
	r.scale = Vector3(1, 0.6, 1)
	root.add_child(r)
	return root


static func of(kind: StringName, sprung := false) -> Node3D:
	return bear(sprung) if kind == &"bear" else pit()


static func _part(m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	return mi


static func _mat(c: Color, glow: float, metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.metallic = metal
	mat.roughness = 0.45 if metal > 0.0 else 0.95
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = glow
	return mat
