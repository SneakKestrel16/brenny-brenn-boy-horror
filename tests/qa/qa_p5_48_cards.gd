extends Node3D
## QA probe for P5-48: every lore card's gap to the surface behind it (centre and four corners), what its box overlaps,
## and the road sign's heights. Headless:
##   "$GODOT" --headless --path . res://tests/qa/qa_p5_48_cards.tscn

var _n := 0


func _ready() -> void:
	var world := (load("res://game/world/farm.tscn") as PackedScene).instantiate()
	world.name = "World"
	add_child(world)
	add_child(LoreProps.new())


func _physics_process(_d: float) -> void:
	_n += 1
	if _n < 4:
		return
	var space := get_world_3d().direct_space_state
	var world := get_node("World")
	for c in world.get_children():
		if not (c is MeshInstance3D and (c.name.begins_with("LoreNote_") or c.name.begins_with("LoreRoad"))):
			continue
		var mi := c as MeshInstance3D
		var size: Vector3 = (mi.mesh as BoxMesh).size
		var b := mi.global_transform.basis
		var n := b.z.normalized()
		var o := mi.global_position
		var gaps := []
		for off: Vector2 in [Vector2.ZERO, Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			var p := o + b.x.normalized() * off.x * size.x * 0.95 + Vector3.UP * off.y * size.y * 0.95
			var q := PhysicsRayQueryParameters3D.create(p + n * 0.2, p - n * 1.0)
			var hit := space.intersect_ray(q)
			gaps.append(snappedf(hit.position.distance_to(p), 0.01) if hit else -1.0)
		# What the card box overlaps (bodies and areas).
		var sh := BoxShape3D.new()
		sh.size = size
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = sh
		sq.transform = mi.global_transform
		sq.collide_with_areas = true
		var over := []
		for r in space.intersect_shape(sq, 16):
			over.append(str((r.collider as Node).get_path()).trim_prefix("/root/QA/World/"))
		# Front side: anything within 1.2 m in front of the card face (would hide it).
		var fq := PhysicsRayQueryParameters3D.create(o + n * 0.03, o + n * 1.2)
		fq.collide_with_areas = false
		var front := space.intersect_ray(fq)
		print("CARD %s pos=%s size=%s face_n=%s bottom=%.2f top=%.2f gaps(c,bl,br,tl,tr)=%s overlaps=%s front=%s" % [
				c.name, o.snappedf(0.01), size.snappedf(0.01), n.snappedf(0.01), o.y - size.y * 0.5, o.y + size.y * 0.5,
				gaps, over, (str((front.collider as Node).name) + "@" + str(snappedf(front.position.distance_to(o), 0.01))) if front else "-"])
	get_tree().quit()
