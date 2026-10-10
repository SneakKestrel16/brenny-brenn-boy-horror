class_name TrapArt
## Trap models (P5-22; doc 07 `trap_*.glb`, P5-15). D-055 (CEO 2026-10-08): set traps are plainly visible; the
## doc 03 section 9 "4 m clue only" rule stays paused. Origin on the ground for every model.
## `trap_tripwire.glb` stays unwired: the tripwire is disabled in data/traps.json.

const PATH := "res://assets/models/%s.glb"
static var _glow := {}  ## source material -> its faint-emission copy, shared by every trap (freed instances never own one)


static func _model(name: String) -> Node3D:
	var root := (load(PATH % name) as PackedScene).instantiate() as Node3D
	for mi in root.find_children("*", "MeshInstance3D"):  # D-055: a faint steady emission keeps traps readable at night
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat:
				if not _glow.has(mat):
					var g := mat.duplicate() as StandardMaterial3D
					g.emission_enabled = true
					g.emission = Color(0.3, 0.28, 0.25)
					g.emission_energy_multiplier = 0.5
					_glow[mat] = g
				m.set_surface_override_material(i, _glow[mat])
	return root


## A bear trap, open. `sprung` (P4-29): jaws shut, so a sprung or carried trap reads as spent.
## A set (open) trap carries the `trap_glint` card, shown by view angle and distance only (never a blink).
static func bear(sprung := false) -> Node3D:
	var root := _model("trap_bear_closed" if sprung else "trap_bear_open")
	if not sprung:
		root.add_child(TrapGlint.new())
	return root


## A pit: the covered pit (set), or the open hole (sprung). Origin on the ground.
static func pit(sprung := false) -> Node3D:
	return _model("trap_pit_open" if sprung else "trap_pit_cover")


static func of(kind: StringName, sprung := false) -> Node3D:
	return bear(sprung) if kind == &"bear" else pit(sprung)
