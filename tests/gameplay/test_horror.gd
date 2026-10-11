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
	# P5-71: doc 01's hallucination rules hold. The role has no local scare of its own except steps; no jolt, shadow or grab keys.
	_check(H.KINDS == [&"steps"], "the only local timed kind is steps (not a hallucination)")
	for gone in ["hallucination_from_day", "silhouette_every_s", "whisper_every_s", "name_whisper_every_s", "shadow_every_s", "grab_every_s", "grab_jolt_s"]:
		_check(not hz.has(gone), "no local scare key " + gone)
	_check(hz.shadow_edge_deg[0] >= 30 and hz.shadow_edge_deg[1] <= 53, "edge hallucination near the view edge")
	var sc: String = FileAccess.get_file_as_string("res://game/ai_director/scares.gd")
	_check(not ("Roles.of(p) == &\"horror\" or Clock.day" in sc), "Horror hallucinations open on day 5, doc 01 Ramp-up (no day-1 exception)")
	_check("return Roles.of(p) == &\"horror\") + peers.filter" in sc, "Horror peer picked first, still behind allow()")
	var hs: String = FileAccess.get_file_as_string("res://game/player/horror_scares.gd")
	_check(not ("cre_jumpscare_hit" in hs or "v_offset" in hs or "rotation:z" in hs), "no stinger or camera jolt from the local layer")
	_check(Logic.chill_due(20.0, 30.0, 30.0, 25.0) and not Logic.chill_due(40.0, 30.0, 99.0, 25.0) and not Logic.chill_due(20.0, 30.0, 5.0, 25.0), "sixth sense: in range and off cooldown")
	print("test_horror: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
