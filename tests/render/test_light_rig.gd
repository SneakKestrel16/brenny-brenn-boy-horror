extends SceneTree
## LightRig checks (doc 07 section 4, P1-11):
##   "$GODOT" --headless --path . -s res://tests/render/test_light_rig.gd
## Exits 0 on pass, 1 on any failure.

var _fails := 0


func _init() -> void:
	await process_frame  # root is not ready inside _init
	var rig := LightRig.new()
	root.add_child(rig)
	var light := rig.get_child(0) as OmniLight3D
	_check(is_equal_approx(light.light_energy, rig.energy), "starts on")
	rig.set_on(false)
	rig._process(0.1)
	_check(light.light_energy > 0.0 and light.light_energy < rig.energy * 0.6, "set_on(false) slews, no instant cut")
	rig._process(0.2)
	_check(light.light_energy == 0.0, "off after 0.2 s")
	rig.set_on(true)
	rig._process(0.1)
	_check(light.light_energy < rig.energy * 0.6, "set_on(true) also slews")
	rig._process(0.3)
	rig.set_dim(0.0)
	for i in 100:
		rig._process(0.05)
	_check(is_equal_approx(light.light_energy, rig.energy * 0.35), "empty tank dims to 35%%, not dark (%f)" % light.light_energy)
	rig.set_dim(1.0)
	for i in 100:
		rig._process(0.05)
	rig.energy_override(0.0, &"wrong")
	_check(light.light_energy > 0.0, "override without the token is ignored")
	rig.energy_override(0.0, LightRig.OVERRIDE_TOKEN)
	_check(light.light_energy == 0.0, "override with the token is instant")
	rig.energy_override(-1.0, LightRig.OVERRIDE_TOKEN)
	_check(light.light_energy > 0.0, "negative value clears the override")
	rig.blow_out()
	rig._process(1.0)
	_check(light.light_energy == 0.0, "blow_out stays off")
	print("test_light_rig: %s" % ("FAIL" if _fails else "PASS"))
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", what)
