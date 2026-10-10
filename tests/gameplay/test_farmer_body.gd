extends SceneTree
## P5-13: the rigged farmer (D-159): six distinct tint colours, each body gets its own overalls material, the
## four locomotion animations loop, the one-shots do not, the emote animations exist.
##   godot --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_farmer_body.gd

const FarmerBody := preload("res://game/player/farmer_body.gd")
var _fails := 0


func _init() -> void:
	var want := ["C04040", "4070C0", "D0B040", "50A050", "8050B0", "D07830"]
	var seen := {}
	var bodies: Array = []
	for i in 6:
		var b := FarmerBody.new(i)
		root.add_child(b)
		bodies.append(b)
		_check(FarmerBody.colour(i).to_html(false).to_upper() == want[i], "slot %d colour" % i)
		var found := 0
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for s in m.mesh.get_surface_count():
				var o := m.get_surface_override_material(s) as StandardMaterial3D
				if o:
					found += 1
					_check(o.albedo_color.is_equal_approx(FarmerBody.colour(i)), "slot %d overalls tinted" % i)
					seen[o.get_instance_id()] = true
		_check(found > 0, "slot %d has an overalls surface" % i)
	_check(seen.size() >= 6, "each body owns its material")
	var ap: AnimationPlayer = bodies[0].find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["idle", "walk", "run", "crouch"]:
		_check(ap.get_animation(n).loop_mode == Animation.LOOP_LINEAR, n + " loops")
	for n in ["wave", "point", "shrug", "scream", "interact"]:
		_check(bodies[0].has_anim(StringName(n)) and ap.get_animation(n).loop_mode == Animation.LOOP_NONE, n + " one-shot")
	_check(bodies[0].shot(&"wave") > 1.0, "wave has a length")
	for b in bodies:
		for mi in b.find_children("*", "MeshInstance3D", true, false):  # the Dummy renderer errors on freeing overrides
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				(mi as MeshInstance3D).set_surface_override_material(s, null)
		root.remove_child(b)
		b.free()
	await process_frame
	await process_frame
	print("test_farmer_body: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + what)
