extends SceneTree
## P5-58: a PNG of the forced creature body at night, 4 m in front of a test camera with a test lamp. Windowed run:
##   "$GODOT" --audio-driver Dummy --path . -s res://tests/creature/shot_p5_58.gd -- --host --lobby-start=1 --no-intro --port=56670 --free-mouse --creature-body=boar --out=<png>
var _f := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_f += 1
	var cr := current_scene.find_child("Creature", true, false) if current_scene else null
	if _f == 240 and cr != null:
		cr.set_physics_process(false)  # hold still
		var at: Vector3 = cr.global_position
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.global_position = at + Vector3(0, 1.6, 4.5)
		cam.look_at(at + Vector3(0, 1.1, 0))
		cam.current = true
		var lamp := OmniLight3D.new()  # test lamp: the night is nearly black
		lamp.omni_range = 12.0
		lamp.light_energy = 3.0
		root.add_child(lamp)
		lamp.global_position = at + Vector3(2.0, 3.0, 4.0)
	if _f == 300:
		var out := "user://creature.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--out="):
				out = a.get_slice("=", 1)
		root.get_viewport().get_texture().get_image().save_png(out)
		print("shot: body %s" % (cr.body if cr else "none"))
		quit()
	return false
