extends SceneTree
## P5-57: bot teammates on the full farm. (1) The walk grid's paths never cross a wall, fence or prop (layer 1) between
## turns, where straight lines do. (2) A bot leaving the barn through its closed door and walking into the closed tool
## shed opens each door with the `open_door` hold and is never past a closed door. (3) With no coins a bot buys no seed and logs no `store_refused`.
## godot --headless --audio-driver Dummy -s res://tests/bots/test_p5_57.gd -- --host --port=56620 --free-mouse --seed=1 --bots=2
## Prints "test_p5_57: PASS" or the failures; exit code 0 on pass. Single instance.

const LIMIT_S := 120.0
const SHED := Rect2(-18, 26, 6, 5)  ## tool shed floor (farm.tscn ToolShed walls)
const BARN := Rect2(-8, -20, 16, 20)
## Stand points across the farm: barn inside, farmhouse inside, shed inside, sell box, well, fuel drum, town stand, fields.
const SPOTS := [Vector3(0, 0, -5), Vector3(-45, 0, -4), Vector3(-15, 0, 29), Vector3(22, 0, 0), Vector3(50.6, 0, -20),
		Vector3(-11.5, 0, 27), Vector3(116, 0, -5), Vector3(30, 0, 1), Vector3(-20, 0, 8), Vector3(-47, 0, 20)]

var _t := 0.0
var _fails: Array[String] = []
var _holds: Array = []  ## [peer, verb, id] of every hold request
var _refused := 0
var _leaks := 0
var _bot: Node
var _doors: Node
var _was_inside_barn := false


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")
	_run.call_deferred()


func _physics_process(delta: float) -> bool:
	_t += delta
	if _t > LIMIT_S:
		_fail("timed out at %.0f s" % _t)
		_finish()
	if _bot and _doors:
		var p: Vector3 = _bot._pos
		if not _doors.open["door_barn"] and _was_inside_barn and not BARN.has_point(Vector2(p.x, p.z)):
			_leaks += 1
		if not _doors.open["door_toolshed"] and SHED.has_point(Vector2(p.x, p.z)):
			_leaks += 1
	return false


func _run() -> void:
	while not (root.has_node("Main/Bots/Bot1") and root.has_node("Main/Doors")):
		await process_frame
	await create_timer(1.0).timeout
	_bot = root.get_node("Main/Bots/Bot1")
	_doors = root.get_node("Main/Doors")
	var bots: Node = root.get_node("Main/Bots")
	var net: Node = root.get_node("Net")
	net.request_received.connect(func(what: StringName, peer: int, a: Array) -> void:
		if what == &"hold":
			_holds.append([peer, a[0], a[1]]))
	root.get_node("Log").logged.connect(func(n: StringName, _d: Dictionary) -> void:
		if n == &"store_refused":
			_refused += 1)

	# (1) grid paths
	var grid: RefCounted = bots.grid()
	if grid == null:
		_fail("no walk grid (ai_director.json bots.grid_route)")
		_finish()
		return
	var space: PhysicsDirectSpaceState3D = _bot.get_viewport().world_3d.direct_space_state
	var skip: Array[RID] = []
	for id: String in _doors.open:
		skip.append_array(_doors.own_bodies(id))
	var straight_blocked := 0
	for a: Vector3 in SPOTS:
		for b: Vector3 in SPOTS:
			if a == b:
				continue
			if _blocked(space, a, b, skip):
				straight_blocked += 1
			var pts: Array = [a] + grid.path(a, b)
			if pts.back() != b:
				_fail("%s -> %s does not end at the target" % [a, b])
			for i in range(1, pts.size() - 2):  # the first and last legs are within a cell of a stand point
				if _blocked(space, pts[i], pts[i + 1], skip):
					_fail("%s -> %s crosses a solid body between %s and %s" % [a, b, pts[i], pts[i + 1]])
					break
	if straight_blocked == 0:
		_fail("no straight line between the spots is blocked: the check has no teeth")

	# (2) doors: out of the closed barn, into the closed tool shed
	if not BARN.has_point(Vector2(_bot._pos.x, _bot._pos.z)):
		_fail("bot did not spawn in the barn (%s)" % _bot._pos)
	_was_inside_barn = true
	_doors.host_set("door_barn", false, 0)
	_doors.host_set("door_toolshed", false, 0)
	await _bot._walk(Vector3(0, 0, 8))
	_was_inside_barn = false
	await _bot._walk(Vector3(-15, 0, 29))
	for id: String in ["door_barn", "door_toolshed"]:
		if not _holds.any(func(h: Array) -> bool: return h[0] == _bot.peer and h[1] == &"open_door" and h[2] == id):
			_fail("no open_door hold on %s" % id)
		if not _doors.open[id]:
			_fail("%s still closed" % id)
	if not SHED.has_point(Vector2(_bot._pos.x, _bot._pos.z)):
		_fail("bot not inside the tool shed (%s)" % _bot._pos)
	if _leaks > 0:
		_fail("bot passed a closed door %d times" % _leaks)

	# (3) no coins, no seed, no store_refused
	var farm: Node = _bot.farm
	farm.coins = 0
	_refused = 0
	var st: Dictionary = farm.pstate(_bot.peer)
	for t: Node in farm.targets.values():
		if t.get(&"state") == &"empty" and not t.locked and not t.bed and farm.store.seed_count(t.crop_for(&"plant")) == 0:
			if _bot._plantable(t, st):
				_fail("plantable with no coins and no seed")
			break
	if _refused > 0:
		_fail("%d store_refused with no coins" % _refused)
	_finish()


func _blocked(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, skip: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0), 1, skip)
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.collider is StaticBody3D


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("FAIL ", msg)


func _finish() -> void:
	print("test_p5_57: %s" % ("PASS" if _fails.is_empty() else "%d FAILED" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)
