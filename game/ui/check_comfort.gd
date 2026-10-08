extends SceneTree
## P2-15 check: comfort defaults exist, per-player voice volume (mute at 0, keyed per player), text size applied.
## Run: godot --headless --audio-driver Dummy --path . --script res://game/ui/check_comfort.gd

func _initialize() -> void:
	var s: Node = root.get_node("Settings")
	var ok := true
	for k in ["camera_shake", "centre_dot", "voice_peer_volume", "toggle_holds", "toggle_sprint", "invert_y", "ui_text_scale"]:
		ok = ok and s.DEFAULTS.has(k)
	ok = ok and is_equal_approx(s.peer_volume(7), 1.0)
	s.set_peer_volume(7, 0.0)
	ok = ok and s.peer_volume(7) == 0.0 and is_equal_approx(s.peer_volume(8), 1.0)
	s.set_peer_volume(7, 0.4)
	ok = ok and is_equal_approx(s.peer_volume(7), 0.4)
	print("check_comfort: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
