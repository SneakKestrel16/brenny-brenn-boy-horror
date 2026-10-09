extends SceneTree
## P4-19 checks on the imported creature models: P4-16 part names and pivots (so creature code needs no
## change), under 5,000 triangles (doc 07 s2), origin at the base, ember glow only on eyes and the husk
## heart, no Light3D (doc 07 s2, s8).
##   "$GODOT" --headless --path . -s res://tests/qa/test_creature_art.gd

const PARTS := {
	"creature_gaunt": {"Torso": Vector3(0, 1.0, 0.1), "Head": Vector3(0, 1.6, -0.35),
		"ArmL": Vector3(-0.3, 1.85, -0.1), "ArmR": Vector3(0.3, 1.85, -0.1),
		"LegL": Vector3(-0.17, 1.0, 0.15), "LegR": Vector3(0.17, 1.0, 0.15)},
	"creature_scarecrow": {"Torso": Vector3(0, 0.7, 0), "Head": Vector3(0, 1.68, 0),
		"ArmL": Vector3(-0.2, 1.5, 0), "ArmR": Vector3(0.2, 1.5, 0),
		"LegL": Vector3(-0.1, 0.75, 0), "LegR": Vector3(0.1, 0.75, 0)},
	"creature_boar": {"Body": Vector3(0, 0.8, 0), "Head": Vector3(0, 0.8, -0.6),
		"Collar": Vector3(0, 0.85, -0.6), "Chain": Vector3(0, 0.85, -0.6)},
	"creature_corn_husk": {"Stalks": Vector3.ZERO, "Head": Vector3(0, 1.85, 0),
		"ArmL": Vector3(-0.3, 1.6, 0), "ArmR": Vector3(0.3, 1.6, 0), "Heart": Vector3(0, 1.2, 0)},
	"creature_scarecrow_head": {"Head": Vector3.ZERO},
	"creature_boar_chain": {"Chain": Vector3.ZERO},
	"creature_corn_husk_heart": {"Heart": Vector3.ZERO},
	"creature_smear_gaunt": {"Smear": Vector3.ZERO},
	"creature_smear_scarecrow": {"Smear": Vector3.ZERO},
	"creature_smear_boar": {"Smear": Vector3.ZERO},
	"creature_smear_corn_husk": {"Smear": Vector3.ZERO},
}
const BODIES := ["creature_gaunt", "creature_scarecrow", "creature_boar", "creature_corn_husk"]
## Parts allowed to carry mat_emissive_ember: the ember eyes and the husk heart.
const EMBER_PARTS := ["Head", "Heart"]

var _fails := 0


func _init() -> void:
	for file: String in PARTS:
		var root: Node3D = (load("res://assets/models/%s.glb" % file) as PackedScene).instantiate()
		var tris := 0
		var low := INF
		for part: String in PARTS[file]:
			var mi := root.find_child(part, true, false) as MeshInstance3D
			_check(mi != null, "%s has part %s" % [file, part])
			if mi == null:
				continue
			_check(mi.position.distance_to(PARTS[file][part]) < 0.005,
				"%s/%s pivot %s == %s" % [file, part, mi.position, PARTS[file][part]])
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
					low = minf(low, (mi.transform * v).y)
				var mat := mi.get_active_material(s)
				var mname := mat.resource_name if mat else ""
				if "emissive" in mname:
					_check(mname == "mat_emissive_ember" and part in EMBER_PARTS and not file.begins_with("creature_smear"),
						"%s/%s emissive only on eyes or heart (got %s)" % [file, part, mname])
		_check(tris > 0 and tris < 5000, "%s tris %d < 5000" % [file, tris])
		if file in BODIES or file.begins_with("creature_smear"):
			_check(absf(low) <= 0.03, "%s origin at base (min y %.3f)" % [file, low])
		_check(root.find_children("*", "Light3D", true, false).is_empty(), "%s has no Light3D" % file)
		root.free()
	print("test_creature_art: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + what)
