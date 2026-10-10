extends SceneTree
## P5-13: DevToys._creature_parts() still finds the creature's body (the glb "Art" node) and no collider.
##   godot --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_creature_parts.gd

func _initialize() -> void:
	var main := Node3D.new()
	root.add_child(main)
	var cover := Node3D.new()  # the day cover marker the creature starts at
	cover.name = "cover_15"
	cover.add_to_group(&"creature_cover")
	main.add_child(cover)
	var stub := GDScript.new()  # a minimal AI Director: the host logic asks it for the day cover
	stub.source_code = "extends Node
var wander_region = \"\"
func third() -> int:
	return 1
func day_cover(d: Vector3) -> Vector3:
	return d
"
	stub.reload()
	var dir := Node.new()
	dir.set_script(stub)
	dir.add_to_group(&"ai_director")
	main.add_child(dir)
	var cr: CharacterBody3D = load("res://game/creature/creature.gd").new()
	cr.name = "Creature"
	main.add_child(cr)
	var toys: Node = load("res://game/debug/dev_toys.gd").new()
	main.add_child(toys)
	await process_frame
	print(cr.get_children().map(func(n: Node) -> String: return "%s:%s" % [n.name, n.get_class()]))
	var names: Array = toys._creature_parts().map(func(n: Node) -> String: return n.name)
	var ok := "Art" in names and not "CollisionShape3D" in names
	print("test_creature_parts: %s (parts %s)" % ["PASS" if ok else "FAIL", names])
	main.free()
	quit(0 if ok else 1)
