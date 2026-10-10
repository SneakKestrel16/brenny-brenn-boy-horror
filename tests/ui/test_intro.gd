extends SceneTree
## P5-67: the intro cutscene. Windowed run (boots the host game; do NOT pass --no-intro):
##   "$GODOT" --audio-driver Dummy --path . -s res://tests/ui/test_intro.gd -- --host --lobby-start=1 --port=33100 --free-mouse [--skip] [--shots=<dir>]
## Without --skip: screenshots at 3, 9, 14.5, 20 and 24.5 s, then waits for the natural end. With --skip: a key press at 2 s.
## Checks: pose/black are continuous and sane, game keys are blocked while it plays and back after, the player camera is
## current again. Prints "INTRO PASS" or "INTRO FAIL". wanted() is false headless (the smoke run logs no intro_shown).
## The script is loaded at run time: it names autoloads, which do not exist yet when a -s script compiles.
const SHOT_AT := [3.0, 9.0, 14.5, 20.0, 24.5]
var _f := 0
var _fails := 0
var _intro: Node
var _cls: GDScript
var _shots := ""
var _skip := false
var _next := 0
var _blocked := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		_skip = _skip or a == "--skip"
		if a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)


func _logic() -> void:
	var cuts: Array = _cls.CUTS
	for i in 260:
		var s := i * 0.1
		var jump: float = (_cls.pose(s)[0] as Vector3).distance_to(_cls.pose(s + 0.1)[0])
		_check(jump < 3.0 or cuts.any(func(c: float) -> bool: return absf(c - s) < 0.15), "pose jump %.1f at %.1f" % [jump, s])
		_check(_cls.black(s) >= 0.0 and _cls.black(s) <= 1.0, "black range")
	for c: float in cuts:
		_check(_cls.black(c) == 1.0, "black at cut %.1f" % c)
	_check(_cls.black(0.0) == 0.0 and _cls.black(24.0) == 1.0, "open at start, closed at the title")


func _process(_d: float) -> bool:
	_f += 1
	if _cls == null:
		_cls = load("res://game/ui/intro_card.gd")
		_logic()
	if _intro == null:
		var found := root.find_children("*", "CanvasLayer", true, false).filter(func(n: Node) -> bool: return n.get_script() == _cls)
		if not found.is_empty():
			_intro = found[0]
		elif _f > 900:
			_check(false, "no intro appeared")
			print("INTRO FAIL")
			quit(1)
		return false
	if is_instance_valid(_intro) and _intro._ending < 0.0:
		var t: float = _intro._t
		_blocked = _blocked or root.get_node("Game").console_open
		if _skip and t > 2.0:
			var ev := InputEventKey.new()
			ev.pressed = true
			ev.keycode = KEY_SPACE
			Input.parse_input_event(ev)
		elif not _skip and _next < SHOT_AT.size() and t >= SHOT_AT[_next]:
			if _shots != "":
				DirAccess.make_dir_recursive_absolute(_shots)
				root.get_viewport().get_texture().get_image().save_png("%s/intro_%02d.png" % [_shots, _next + 1])
			_next += 1
	else:
		_check(_blocked, "console_open was set while playing")
		_check(not root.get_node("Game").console_open, "keys back after the intro")
		var cam := root.get_viewport().get_camera_3d()
		_check(cam != null and cam.get_parent() is CharacterBody3D, "player camera current again")
		_check(_skip or _next == SHOT_AT.size(), "all shots taken")
		print("INTRO ", "PASS" if _fails == 0 else "FAIL")
		quit(0 if _fails == 0 else 1)
	return false
