extends SceneTree
## P3-09 checks: the ghost light pattern (doc 07 section 4.3) and the corn test for a rustle.
##   "$GODOT" --headless --path . --script res://game/ghost/check_ghost.gd
## Samples a lit LightRig through the pattern (dip, on, dip, on, back to its own level), checks a
## blown-out rig refuses it, and checks a rustle point inside and outside the corn. Exit code 1 on a FAIL.

const LightFlicker := preload("res://game/ghost/light_flicker.gd")

var _fails := 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var rig := LightRig.new()
	root.add_child(rig)
	await create_timer(0.5).timeout  # the rig slews up to full
	var base := rig.current_level()
	_check("lit before", base > 0.9)
	var t0 := Time.get_ticks_msec()
	_check("plays on a lit rig", LightFlicker.play(rig))
	for at in [[0.12, 0.3], [0.37, 1.0], [0.62, 0.3], [0.87, 1.0], [1.3, 1.0]]:
		while Time.get_ticks_msec() - t0 < int(at[0] * 1000.0):
			await process_frame
		_check("level at %.2f s is %.1f of base" % [at[0], at[1]], absf(rig.current_level() - base * at[1]) < 0.02)
	rig.blow_out()
	await process_frame
	_check("blown out refuses", not LightFlicker.play(rig))
	var farm := (load("res://game/world/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	var powers := Node.new()  # only its corn test is used here
	powers.set_script(load("res://game/ghost/ghost_powers.gd"))
	farm.add_child(powers)
	await physics_frame
	await physics_frame
	var corn: Vector3 = (farm.get_node("CornBlockers").get_child(0) as Node3D).global_position
	_check("rustle allowed in corn %s" % corn, powers._in_corn(corn))
	_check("rustle refused at the barn spawn", not powers._in_corn(Vector3(0, 0, 0)))
	# P5-66: a possessed crow flies, clamped in altitude, and a wall stops it.
	var perch := root.get_tree().get_first_node_in_group(&"crow_perches") as Node3D
	root.get_node("Game").players[1] = {"ghost": true, "pos": perch.global_position}
	_check("crow possessed", powers.act(1, &"crow") == "")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	wall.add_child(shape)
	farm.add_child(wall)
	wall.global_position = perch.global_position + Vector3(10, 4, 0)
	wall.scale = Vector3(1, 20, 20)
	await physics_frame
	await physics_frame
	var start: Vector3 = powers._crows[1].pos
	powers._on_request(&"crow_steer", 99, [Vector3(1, 0, 0)])  # QA P5-66: only the crow's own ghost steers it
	powers._on_request(&"crow_steer", 1, [Vector3(NAN, 0, 0)])
	_check("steer from another peer or NaN ignored", powers._steer.is_empty())
	powers._on_request(&"crow_steer", 1, [Vector3(50, 0, 0)])
	_check("steer clamped to length 1", is_equal_approx(powers._steer[1].dir.length(), 1.0))
	powers._on_request(&"crow_steer", 1, [Vector3(0, 1, 0)])
	for i in 90:
		powers._steer[1].at = Time.get_ticks_msec()
		await physics_frame
	_check("crow climbs to the ceiling %s" % powers._crows[1].pos, is_equal_approx(powers._crows[1].pos.y, powers.CROW_MAX_Y))
	powers._on_request(&"crow_steer", 1, [Vector3(-1, 0, 0)])
	for i in 30:
		powers._steer[1].at = Time.get_ticks_msec()
		await physics_frame
	_check("crow flew away from the perch", powers._crows[1].pos.x < start.x - 2.0)
	powers._on_request(&"crow_steer", 1, [Vector3(1, 0, 0)])
	for i in 120:
		powers._steer[1].at = Time.get_ticks_msec()
		await physics_frame
	_check("a wall stops the crow %s" % powers._crows[1].pos, powers._crows[1].pos.x < start.x + 10.0)
	print("check_ghost: %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)
