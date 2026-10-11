extends SceneTree
## P5-70 (CEO D-188 on D-12): a door shut on the creature is flung open again; it never walks through a shut door.
## A night chase into the dark building 0 bangs, goes in, walks out again. Every time the door stands open and the
## creature is within 3 m of it, the test shuts it (as a player would, at most every 0.3 s). Each frame, before the
## creature moves, the door must not be shut while the creature stands in the doorway (0.6 m of the door point).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_70.gd -- --host --bots=1 --port=40701 --free-mouse
## Exits 0 on pass, 1 on any failure.

var _fails := 0
var _frames := 0


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


func _run() -> void:
	var Game: Node = root.get_node("Game")
	var main: Node = root.get_node("Main")
	var creature: Node = main.get_node("Creature")
	var doors: Node = main.get_node("Doors")
	var ids: Array = Game.players.keys()
	ids.sort()
	for p: int in ids:
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[p].pos = Vector3(-60, 0, -60) + Vector3(p % 7, 0, 0)
	for b in main.get_node("Bots").get_children():
		b.process_mode = Node.PROCESS_MODE_DISABLED
	var dev: Node
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	dev.run("day 2")
	dev.run("phase night")
	dev.run("gen damage")
	for i in 30:
		await physics_frame
	var v: int = ids[0]
	var bi := 0
	var br: Rect2 = creature._rects[bi]
	var door_id := "door_" + String(creature._rect_names[bi]).to_lower()
	var door: Vector2 = creature._doors[bi]
	var at := func() -> Vector2: return Vector2(creature.global_position.x, creature.global_position.z)
	var in_b := func() -> bool: return br.has_point(at.call())
	# the far half of the building from the door, so the chase passes the doorway well before any catch
	var c := br.get_center()
	var far := c + (c - door).normalized() * minf(br.size.x, br.size.y) * 0.3
	var inside := Vector3(far.x, 0.0, far.y)
	var outside: Vector3 = creature._door_step(bi, 14.0)
	doors.host_set(door_id, false, 0)
	creature.global_position = creature._door_step(bi, 8.0)
	creature._scripted = false
	creature._goal = Vector3.INF
	creature._set_state(&"chase", &"dev", v)
	var shuts := [0]
	var overlaps := [0]
	var last_shut := [-1.0]
	var t := [0.0]
	# one frame: the overlap check, then shut the door on it if it stands open and the creature is near
	var step := func(target: Vector3) -> void:
		Game.players[v].pos = target
		creature._seen = {v: {"position": target, "t": creature._now}}
		await physics_frame
		t[0] += 1.0 / Engine.physics_ticks_per_second
		var d: float = at.call().distance_to(door)
		if d < 0.6 and not doors.open[door_id]:
			overlaps[0] += 1
		if doors.open[door_id] and d < 3.0 and t[0] - last_shut[0] >= 0.3:
			doors.host_set(door_id, false, 0)
			last_shut[0] = t[0]
			shuts[0] += 1

	print("in: shut on it after the bang")
	while not in_b.call() and t[0] < 20.0:
		await step.call(inside)
	_check(in_b.call(), "it went in (%.1f s)" % t[0])
	var in_shuts: int = shuts[0]
	_check(in_shuts >= 1, "the door was shut on it on the way in (%d times)" % in_shuts)
	for i in 30:  # deeper in, past the doorway
		await step.call(inside)
	_check(overlaps[0] == 0, "never in the doorway with the door shut on the way in (%d frames)" % overlaps[0])

	print("out: shut on it as it leaves")
	var t_out: float = t[0]
	while in_b.call() and t[0] - t_out < 20.0:
		await step.call(outside)
	for i in 60:
		await step.call(outside)
	_check(not in_b.call(), "it walked out")
	_check(shuts[0] > in_shuts, "the door was shut on it on the way out (%d times)" % (shuts[0] - in_shuts))
	_check(overlaps[0] == 0, "never in the doorway with the door shut, in or out (%d frames)" % overlaps[0])

	print("P5-70 %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)
