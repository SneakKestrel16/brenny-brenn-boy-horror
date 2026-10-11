extends SceneTree
## P5-72 creature AI checks (outside review), on frozen bots at night:
##   A, sight: lists the world (layer 1) and corn (layer 16) bodies that reach the 1.65 m eye line and are not
##      buildings, bounds, trees or doors; a player stood just behind a prop or the pen fence is seen, one behind
##      the barn wall is not.
##   B, stuck in a chase: a chase pushing into the pen's north fence logs creature_stuck (state chase) and gets
##      round it to the target. The old code (lurk-only stuck recovery) pushed on and never got closer.
##   C, a target-less stalk (a noise, doc 03 s4.2) walks to it through the corn: fewer open metres than straight.
##   D, a lost stalk searches round the last sensed position for `search_s`, from sensed positions only (D-189).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_72.gd -- --host --bots=3 --port=46720 --free-mouse
## Exits 0 on pass, 1 on any failure.

const Logic := preload("res://game/creature/creature_logic.gd")

var _fails := 0
var _frames := 0
var _ev: Array = []
var Game: Node
var main: Node
var cr: Node


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


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## World-space AABB of a body's collision shapes, empty for none.
func _body_box(b: CollisionObject3D) -> AABB:
	var box := AABB()
	var first := true
	for c in b.get_children():  # its own shapes only (an interact Area3D child is another body)
		var s := c as CollisionShape3D
		if s == null or s.shape == null or s.disabled:
			continue
		var bb: AABB = s.global_transform * s.shape.get_debug_mesh().get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	return box


func _sees(p: int, at: Vector3, from: Vector3) -> bool:
	Game.players[p].pos = at
	Game.players[p]["crouch"] = false
	cr.global_position = from
	cr._seen.erase(p)
	cr._sense()
	if not cr._seen.has(p):
		var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * cr.EYE_M, at + Vector3.UP * cr.EYE_M, 1 | 16)
		var hit: Dictionary = cr.get_world_3d().direct_space_state.intersect_ray(q)
		print("    not seen at %s from %s: hit %s" % [at, from, root.get_path_to(hit.collider) if hit else "nothing"])
	return cr._seen.has(p)


func _run() -> void:
	Game = root.get_node("Game")
	main = root.get_node("Main")
	cr = main.get_node("Creature")
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	var dir: Node = main.get_node("AiDirector")
	var ids: Array = Game.players.keys()
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
	await _wait(1.0)
	dev.run("phase night")
	await _wait(0.5)
	cr._scripted = false
	cr._set_state(&"lurk", &"dev", 0)
	var v: int = ids[0]
	var park := func() -> void:
		for p: int in ids:
			Game.players[p].pos = Vector3(-60, 0, -60) + Vector3(p % 7, 0, 0)

	print("A: sight past props, not through walls")
	var farm: Node = main.get_node("World")  # farm.tscn (main.gd); "Farm" is the farm script node
	var odd: Array = []
	for b in farm.find_children("*", "CollisionObject3D", true, false):
		var co := b as CollisionObject3D
		if co.collision_layer & (1 | 16) == 0:
			continue
		var path := String(farm.get_path_to(co))
		if path.begins_with("Buildings") or path.begins_with("Bounds") or path.begins_with("Trees") or path.begins_with("CornBlockers") \
				or path.begins_with("Doors") or co.is_in_group(&"doors"):
			continue
		var box := _body_box(co)
		if box.size != Vector3.ZERO and box.end.y > cr.EYE_CROUCH_M:
			odd.append("%s top %.2f m" % [path, box.end.y])
	print("    layer 1/16 bodies above the crouch eye (0.9 m), not buildings/bounds/trees/corn/doors: %s" % [odd])
	var props := ["Props/Generator", "Props/FuelDrum", "Props/Well", "Props/ShippingCrate", "Props/TownStand", "Pen/NorthW", "Pen/SouthR"]
	for path: String in props:
		var n := farm.get_node_or_null(path) as Node3D
		if n == null:
			_check(false, "%s exists" % path)
			continue
		var c := n.global_position
		c.y = 0.0
		# the prop between the creature (5 m one side) and the player (1.2 m the other side), on the x and z axes; seen
		# from either end proves the prop does not block (a barn wall or the shed's door leaf stands at some far ends)
		var seen_x := _sees(v, c + Vector3(1.2, 0, 0), c - Vector3(5, 0, 0)) or _sees(v, c - Vector3(1.2, 0, 0), c + Vector3(5, 0, 0))
		var seen_z := _sees(v, c + Vector3(0, 0, 1.2), c - Vector3(0, 0, 5)) or _sees(v, c - Vector3(0, 0, 1.2), c + Vector3(0, 0, 5))
		_check(seen_x and seen_z, "a player just behind %s is seen (x %s, z %s)" % [path, seen_x, seen_z])
	var barn: Rect2 = cr._rects[cr._rect_names.find("Barn")]
	var inside := Vector3(barn.get_center().x, 0, barn.get_center().y)
	var outside := Vector3(barn.end.x + 4.0, 0, barn.get_center().y)
	_check(not _sees(v, inside, outside), "a player inside the barn is not seen through its wall from 4 m outside")
	park.call()

	print("B: a chase into the pen fence gets round it")
	_ev.clear()
	dir.phase = &"peak"
	var pv := Vector3(-24, 0, -20)  # south of the pen; its south side has the gate gap at x -24
	cr.global_position = Vector3(-24, 0, -41)  # north of the north fence (z -38, x -30 to -18): the straight line hits it
	cr._memory.clear()
	cr._goal = Vector3.INF
	cr._set_state(&"chase", &"dev", v)
	var start: float = cr.global_position.distance_to(pv)
	var best := start
	var t := 0.0
	while t < 20.0 and cr.state == &"chase":
		Game.players[v].pos = pv
		cr._seen = {v: {"position": pv, "t": cr._now}}
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		best = minf(best, cr.global_position.distance_to(pv))
	var stuck := _ev.filter(func(e: Array) -> bool: return e[0] == "creature_stuck" and e[1].get("state") == "chase")
	_check(not stuck.is_empty(), "creature_stuck logged in chase (%d)" % stuck.size())
	_check(best <= cr._num[&"reach_m"] + 1.0, "it got round the fence to the target: %.1f m at best, from %.1f m (%.1f s)" % [best, start, t])
	cr._set_state(&"lurk", &"dev", 0)
	park.call()
	cr._seen.clear()

	print("C: a target-less stalk walks to the noise through the corn")
	var corn: Array = cr._corn_rects()
	var c10 := Vector3(-47, 0, 42)  # doc 04 s7.2 cover_10, Prize Pumpkin
	var c01 := Vector3(13, 0, -6)  # cover_01, barn door
	cr.global_position = c10
	cr._goal = Vector3.INF
	cr._set_state(&"stalk", &"dev", 0)
	cr._memory = [{"position": c01, "margin": 5.0, "t": cr._now, "peer": 0, "kind": &"generator"}]
	cr._hunt(0.016)
	var hops: Array = [_flat(cr._goal)] + cr._route
	var walk_open := 0.0
	var at := _flat(c10)
	for h: Vector2 in hops:
		walk_open += Logic.open_m(at, h, corn)
		at = h
	var straight := Logic.open_m(_flat(c10), _flat(c01), corn)
	_check(cr.state == &"stalk" and hops[-1].distance_to(_flat(c01)) < 0.1, "it heads for the noise: %s, ends at %s" % [cr.state, hops[-1]])
	_check(walk_open < straight * 0.75, "%.0f open metres routed, %.0f straight (%d hops)" % [walk_open, straight, hops.size()])
	cr.global_position = c01 + Vector3(1, 0, 0)
	cr._hunt(0.016)
	_check(cr.state == &"lurk", "at the noise it looks, then goes back: %s" % cr.state)
	cr._memory.clear()

	print("D: a lost stalk searches round where it last sensed the target")
	dir.phase = &"build_up"  # stalks, no chases (doc 03 section 11.2)
	var cover: Array = get_nodes_in_group(&"creature_cover").map(func(n: Node3D) -> Vector3: return n.global_position)
	var last: Vector3 = cover[3]
	cr.global_position = last + Vector3(14, 0, 0)
	cr._set_state(&"stalk", &"dev", v)
	cr._seen = {v: {"position": last, "t": cr._now - 1.0}}  # sensed there, not in sight now; the true position is parked
	cr._hunt(0.016)
	_check(cr.state == &"stalk" and cr._goal == last, "stalking toward the sensed position: %s" % cr.state)
	cr._seen[v].t = cr._now - cr._num[&"hearing_memory_s"] - 1.0  # forgotten
	_ev.clear()
	cr._hunt(0.016)
	var st: Dictionary = {}
	for e: Array in _ev:
		if e[0] == "creature_state":
			st = e[1]
	_check(cr.state == &"lurk" and st.get("reason") == "lost_track", "lost: lurk, reason %s" % st.get("reason"))
	_check(is_equal_approx(cr._search_until, cr._now + cr._num.get(&"search_s", -1.0)), "searches for search_s (%.0f s)" % cr._num.get(&"search_s", -1.0))
	_check(cr._search_c == last and cr._goal == last, "round the last sensed position %s, not the true one %s" % [cr._search_c, Game.players[v].pos])
	cr.global_position = last
	await _wait(0.3)
	var radius: float = cr._num[&"search_radius_m"]
	_check(cr._goal != Vector3.INF and cr._goal != last and cr._goal.distance_to(last) <= radius, "then checks cover round it: goal %s (%.1f m off)" % [cr._goal, cr._goal.distance_to(last) if cr._goal != Vector3.INF else -1.0])

	print("test_p5_72: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
