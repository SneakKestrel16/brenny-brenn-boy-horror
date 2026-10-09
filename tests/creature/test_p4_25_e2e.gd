extends SceneTree
## P4-25 on a live host: the CEO's barn pin (OPEN_ISSUES "CEO's 2-instance session" item 7) and the dawn reset.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p4_25_e2e.gd -- --host --bots=1 --port=24731 --free-mouse
## 1. Lurk from (-14, 8) to cover_01 (13, -6): the CEO's log line runs through the barn door and pinned it on the
##    inside of the east wall at (7.4, -4.5). It must reach cover_01 without entering the barn.
## 2. Inside the barn with a goal outside: it leaves through the door. Outside with a goal inside: it enters by it.
## 3. Dawn with the creature in the barn: the host puts it back in the corn and logs `creature_dawn_reset`.
## Exits 0 on pass, 1 on any failure.

var _fails := 0
var _frames := 0
var _ev: Array = []  # [name, data] from Log.logged
var Game: Node
var main: Node
var cr: Node
var dev: Node


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 60:
		_run()
	return false


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _last(name: String) -> Variant:
	for i in range(_ev.size() - 1, -1, -1):
		if _ev[i][0] == name:
			return _ev[i][1]
	return null


func _wait(s: float) -> void:
	await create_timer(s).timeout


## Windowed only, `-- --p425-shot=<dir>`: a top-down view of the barn (x -8..8, z -20..0) and the creature.
func _shoot(name: String) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--p425-shot="):
			dir = a.trim_prefix("--p425-shot=")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = Vector3(cr.global_position.x * 0.5, 34.0, (cr.global_position.z - 10.0) * 0.5)
	cam.look_at(cam.global_position + Vector3.DOWN, Vector3.FORWARD)
	cam.make_current()
	await _wait(0.5)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("    shot %s/%s.png, creature at %s" % [dir, name, cr.global_position])
	cam.queue_free()


func _in_barn(p: Vector3) -> bool:
	return p.x > -8.0 and p.x < 8.0 and p.z > -20.0 and p.z < 0.0  # doc 04 s4: barn x -8..8, z -20..0


## Lurk toward `goal` from `from`, outside the script; returns whether it got within 1.5 m in `s` seconds, and
## whether it was ever inside the barn on the way.
func _walk(from: Vector3, goal: Vector3, s: float) -> Array:
	cr.global_position = from
	cr._scripted = false
	cr._memory.clear()
	cr.force_state(&"lurk", &"test", 0)
	cr._search_until = -1.0
	cr._goal = goal
	var entered := false
	var t := 0.0
	while t < s:
		await _wait(0.25)
		t += 0.25
		entered = entered or _in_barn(cr.global_position)
		if Vector2(cr.global_position.x - goal.x, cr.global_position.z - goal.z).length() <= 1.5:
			return [true, entered]
		cr._goal = goal  # a lurk arrival or a wander pick must not swap the goal mid-test
	print("    stuck at %s" % cr.global_position)
	return [false, entered]


## The CEO's night 2: a chase (scripted or not) on a player in the lit barn. No catch; it ends `lit_building`
## and it never steps inside, wherever in the barn the player stands.
func _lit_chase(scripted: bool) -> void:
	for at in [Vector3(0.8, 0, -0.5), Vector3(-4, 0, -12)]:  # the CEO's death spot by the door, and deep inside
		Game.players[1].pos = at
		cr.global_position = Vector3(0, 0, 5)
		cr._memory.clear()
		cr._scripted = scripted
		if scripted:
			cr._night_t = cr._num[&"scripted_lurk_s"] + 30.0
			cr._stalk_at = cr._night_t - cr._num[&"scripted_chase_after_stalk_s"] - 0.1
		cr.force_state(&"chase", &"test", 1)
		var caught := [0]
		var on_caught := func(_p: int) -> void: caught[0] += 1
		cr.caught.connect(on_caught)
		_ev.clear()
		var inside := false
		for i in 24:
			await _wait(0.25)
			inside = inside or _in_barn(cr.global_position)
		cr.caught.disconnect(on_caught)
		var end: Variant = _last("chase_ended")
		_check(caught[0] == 0 and not inside and end != null and end.how == "lit_building",
			"lit barn, %s chase on %s: caught %d, inside %s, %s" % ["scripted" if scripted else "hunting", at, caught[0], inside, end])
	Game.players[1].pos = Vector3(90, 0, 40)
	cr._scripted = false


func _run() -> void:
	Game = root.get_node("Game")
	main = root.get_node("Main")
	cr = main.get_node("Creature")
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	_check(dev != null and cr._ok, "dev console and a host creature")
	if dev == null or not cr._ok:
		quit(1)
		return
	for p in Game.players:  # far from the barn and silent: nothing it hears or sees changes its goal
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[p].pos = Vector3(90, 0, 40)
	dev.run("phase night")
	await _wait(0.5)
	var cover := Vector3(13, 0, -6)  # cover_01
	var r: Array = await _walk(Vector3(-14, 0, 8), cover, 30.0)
	_check(r[0] and not r[1], "CEO line (-14, 8) -> cover_01 reaches it without entering the barn: %s" % [r])
	await _shoot("cover_01")
	r = await _walk(Vector3(5, 0, -15), cover, 30.0)
	_check(r[0], "barn inside (5, -15) -> cover_01 leaves by the door: %s" % [r])
	var gen: Node = main.get_node("Generator")
	r = await _walk(Vector3(0, 0, -30), Vector3(-4, 0, -12), 30.0)
	_check(not r[0] and not _in_barn(cr.global_position), "lit: north of the barn (0, -30) -> inside (-4, -12) stays out: %s at %s" % [r, cr.global_position])
	await _shoot("lit_stays_out")
	gen.damage()
	r = await _walk(Vector3(0, 0, -30), Vector3(-4, 0, -12), 40.0)
	_check(r[0], "dark: north of the barn (0, -30) -> inside (-4, -12) enters by the door: %s" % [r])
	gen.repair()
	await _lit_chase(false)
	await _lit_chase(true)
	cr.global_position = Vector3(7.4, 0, -4.5)  # where the CEO's creature stood at dawn
	cr.force_state(&"retreat", &"test", 0)
	_ev.clear()
	dev.run("phase dawn")
	await _wait(0.5)
	var e: Variant = _last("creature_dawn_reset")
	var at: Vector3 = cr.global_position
	_check(e != null and not _in_barn(at), "dawn reset logged and it left the barn: %s at %s" % [e, at])
	_check(cr.state == &"lurk", "dawn ends the night's retreat: %s" % cr.state)
	var dir := get_first_node_in_group(&"ai_director")
	var reg: String = dir.region_of(at)
	_check(reg.begins_with("corn_ring") and dir.region_rect(reg).has_point(Vector2(at.x, at.z)), "it stands in the corn ring: %s" % reg)
	_ev.clear()
	dev.run("phase night")
	await _wait(0.2)
	dev.run("phase dawn")
	await _wait(0.5)
	_check(_last("creature_dawn_reset") == null, "no reset when it is already in the corn")
	print("test_p4_25_e2e: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
