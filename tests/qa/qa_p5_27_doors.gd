extends Node
## QA P5-27: a closed door blocks a player body (layer 2, mask 1) and not the Creature (layer 4, mask 1, exempted by Doors).
## Run: "$GODOT" --headless --audio-driver Dummy --path . res://tests/qa/qa_p5_27_doors.tscn
## Prints one line per case and "QA_DOORS PASS" or "QA_DOORS FAIL".

var _fail := 0


func _ready() -> void:
	_run.call_deferred()


func _body(layer: int, group: StringName) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	b.collision_layer = layer
	b.collision_mask = 1
	var c := CollisionShape3D.new()
	c.shape = CapsuleShape3D.new()  # same default capsule as player.gd
	b.add_child(c)
	if group != &"":
		b.add_to_group(group)
	return b


func _run() -> void:
	var world := (load("res://game/world/farm.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(world)
	var farm := Node.new()  # stub: Doors only needs the group and `targets`
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar targets := {}\n"
	stub.reload()
	farm.set_script(stub)
	farm.add_to_group(&"farm")
	get_tree().root.add_child(farm)
	var creature := _body(4, &"creature")
	get_tree().root.add_child(creature)
	var player := _body(2, &"")
	get_tree().root.add_child(player)
	var doors: Node = (load("res://game/interaction/doors.gd") as GDScript).new()
	get_tree().root.add_child(doors)
	await get_tree().process_frame
	await get_tree().physics_frame
	for id: String in ["door_barn", "door_farmhouse", "door_toolshed"]:
		var m: Node3D = null
		for d: Node3D in get_tree().get_nodes_in_group(&"doors"):
			if "door_" + String(d.get_meta(&"building", "")) == id:
				m = d
		var out := m.global_transform * Vector3(0, 1.0, 2.0)  # outside, in front of the threshold (+Z local)
		var motion := m.global_transform.basis * Vector3(0, 0, -4.0)  # walk straight in
		for closed in [false, true]:
			doors._on_apply(&"door", [id, not closed, 0])
			await get_tree().physics_frame
			await get_tree().physics_frame
			for who in [["player", player, closed], ["creature", creature, false]]:
				var b: CharacterBody3D = who[1]
				var hit := b.test_move(Transform3D(Basis(), out), motion)
				var ok: bool = hit == who[2]
				if not ok:
					_fail += 1
				print("%s %s %s: blocked=%s expected=%s %s" % [id, "closed" if closed else "open", who[0], hit, who[2], "ok" if ok else "FAIL"])
	print("QA_DOORS %s" % ("PASS" if _fail == 0 else "FAIL"))
	get_tree().quit(1 if _fail else 0)
