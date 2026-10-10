extends SceneTree
## P5-64: PNG of the barn how-to-play board from a player's eye height, 3 m away. Windowed run:
##   "$GODOT" --audio-driver Dummy --path . -s res://tests/qa/shot_barn_sign.gd -- --host --lobby-start=1 --no-intro --port=28640 --free-mouse --out=<png>
var _f := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_f += 1
	if _f == 240:
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.global_position = Vector3(-4.7, 1.6, -10.0)
		cam.look_at(Vector3(-7.7, 2.2, -10.0))
		cam.current = true
		var lamp := OmniLight3D.new()  # test lamp: dark barn
		lamp.omni_range = 12.0
		lamp.light_energy = 3.0
		root.add_child(lamp)
		lamp.global_position = Vector3(-5.5, 3.0, -10.0)
	if _f == 300:
		var out := "user://sign.png"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--out="):
				out = a.get_slice("=", 1)
		root.get_viewport().get_texture().get_image().save_png(out)
		quit()
	return false
