extends SceneTree
## P5-53: Horror role data and the pure rules (intervals, turning, edge shadows, darker world, sixth sense).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_horror.gd -- --free-mouse
var _fails := 0
var _frames := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 20:
		return false
	var H: Script = load("res://game/player/horror_scares.gd")
	var Roles: Script = load("res://game/player/roles.gd")
	var Logic: Script = load("res://game/ai_director/director_logic.gd")
	var hz: Dictionary = Roles.perks(&"horror")
	_check(not hz.is_empty() and hz.flicker == false, "Horror role in roles.json, no flicker (only ghosts flicker lights)")
	_check(hz.dark_ambient_mult < 1.0 and hz.dark_fog_mult > 1.0 and hz.dark_lamp_mult < 1.0 and hz.dark_lamp_mult >= 0.35, "darker world; lamps stay above the 35% floor")
	_check(H.dark_for(hz) == [hz.dark_ambient_mult, hz.dark_fog_mult, hz.dark_lamp_mult] and H.dark_for({}) == [1.0, 1.0, 1.0], "darker only for the role")
	_check(hz.hallucination_weight_mult == 2.0, "about twice the hallucinations")
	_check(H.interval([50, 110], 0.0, false) == 50.0 and H.interval([50, 110], 1.0, true) == 220.0, "reduce_scares doubles intervals")
	_check(H.turned(0.0, deg_to_rad(40), 35) and not H.turned(0.0, deg_to_rad(20), 35) and H.turned(deg_to_rad(350), deg_to_rad(20), 35) == false, "steps stop on a turn over 35 degrees (wraps)")
	_check(H.off_axis_deg(Vector3.FORWARD, Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(60))) > 55.0, "edge shadow sits at the edge")
	_check(H.off_axis_deg(Vector3.FORWARD, Vector3(0.1, 0, -1)) < 20.0, "a shadow looked at is gone")
	_check(not H.allowed(&"grab", 9, hz, true) and not H.allowed(&"shadow", 9, hz, true) and H.allowed(&"steps", 1, hz, true), "reduce_scares drops grab and shadow")
	_check(not H.allowed(&"silhouette", 4, hz, false) and H.allowed(&"silhouette", 5, hz, false), "silhouettes from day 5 (doc 01)")
	_check(Logic.chill_due(20.0, 30.0, 30.0, 25.0) and not Logic.chill_due(40.0, 30.0, 99.0, 25.0) and not Logic.chill_due(20.0, 30.0, 5.0, 25.0), "sixth sense: in range and off cooldown")
	print("test_horror: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
