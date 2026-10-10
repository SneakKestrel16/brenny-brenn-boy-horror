extends SceneTree
## P5-39 (was AI-IMPROVE-01) checks, one per fix, on frozen bots:
##   A, day: a teammate's finished pry logs `trap_changed` loose `by` the helper, not the victim (Q-345 4).
##   B, a day race still running after nightfall ends on the creature's catch (Q-345 1).
##   C, lurk never picks a wander point under its feet; an empty region (town_road) sends it to points near it.
##   D, lurk: a silent player in sight and out of the light starts a stalk (doc 03 section 4.2 "seen").
##   E, a hold whose target leaves the tree is cancelled `target_gone` by hold_registry (Q-345 3).
##   F, a chase into a dark building stops at the door and bangs `door_bang_s` (sent to every peer), then goes in
##      (doc 03 section 6 "always bangs first").
##   G, a night stalk creeps to a hiding spot on a ring `stalk_hold_far_m` round the sensed target, not straight at
##      it; when stalk_max_s runs out it walks away and leaves that player alone for `stalk_rest_s`.
##   H, a retreat runs to varied cover at least `retreat_min_m` off, away from the target.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_39.gd -- --host --bots=3 --port=54781 --free-mouse
## Exits 0 on pass, 1 on any failure.

var _fails := 0
var _frames := 0
var _ev: Array = []
var Game: Node
var main: Node
var race: Node
var creature: Node


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


func _last(kind: String) -> Dictionary:
	for i in range(_ev.size() - 1, -1, -1):
		if _ev[i][0] == kind:
			return _ev[i][1]
	return {}


## Arms a bear trap on `spot` and stands `peer` on it; returns the trap id once the race holds it.
func _spring(spot: Node3D, peer: int) -> String:
	creature._arm(spot, &"bear", {"dev": true})
	Game.players[peer].pos = spot.global_position
	for i in 240:
		await physics_frame
		for id in race.races:
			if race.races[id].victim == peer:
				return id
	return ""


func _run() -> void:
	Game = root.get_node("Game")
	main = root.get_node("Main")
	race = main.get_node("TrapRace")
	creature = main.get_node("Creature")
	var registry: Node = main.get_node("Farm").registry
	var dir: Node = main.get_node("AiDirector")
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	var ids: Array = Game.players.keys()
	ids.sort()
	var away := func(p: int) -> void: Game.players[p].pos = Vector3(-60, 0, -60) + Vector3(p % 7, 0, 0)
	for p: int in ids:
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		away.call(p)
	for b in main.get_node("Bots").get_children():
		b.process_mode = Node.PROCESS_MODE_DISABLED
	var spots: Array = []
	for n: Node3D in root.get_tree().get_nodes_in_group(&"trap_spots"):
		if n.get_meta("kind", "") != "deep":
			spots.append(n)
	var dev: Node
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	dev.run("day 2")
	await _wait(1.0)
	var helper: int = ids[ids.size() - 1]  # the host player

	print("A: a helper's pry logs `by` the helper")
	var id := await _spring(spots[0], ids[0])
	_check(id != "", "the day spring pinned peer %d" % ids[0])
	if id != "":
		Game.players[helper].pos = Game.players[ids[0]].pos + Vector3(1.0, 0.0, 0.0)
		root.get_node("Net").request_received.emit(&"hold", helper, [&"pry", id])
		var t := 0.0
		while Game.players[ids[0]].pinned and t < 6.0:
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		away.call(helper)
		var loose := _last("trap_changed")
		_check(loose.get("state") == "loose" and int(loose.get("by", 0)) == helper, "loose by the helper %d: %s" % [helper, loose])

	print("B: a day race at nightfall ends on the catch")
	var vb: int = ids[1]
	id = await _spring(spots[1], vb)
	_check(id != "", "the day spring pinned peer %d" % vb)
	if id != "":
		dev.run("phase night")
		await _wait(0.5)
		_check(race.races.has(id) and is_finite(float(race.races[id].deadline)), "the day race runs on into the night")
		creature.caught.emit(vb)
		await _wait(0.5)
		var e := _last("death")
		_check(not race.races.has(id) and Game.is_ghost(vb) and String(e.get("cause", "")) == "night_trap", "the catch ends it: %s" % e)
	else:
		dev.run("phase night")
		await _wait(0.5)

	print("C: lurk wander points")
	var rect: Rect2 = dir.region_rect("town_road")
	var keep_region: String = dir.wander_region
	dir.wander_region = "town_road"
	var hop := float(root.get_node("Data").value(&"creature", &"wander_min_hop_m", &"metres"))
	var near_ok := 0
	var far_ok := 0
	for i in 40:
		creature.global_position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		creature._goal = Vector3.INF
		creature._wander()
		var g: Vector3 = creature._goal
		if g != Vector3.INF and g.distance_to(creature.global_position) >= hop:
			far_ok += 1
		if rect.grow(creature.REGION_M).has_point(Vector2(g.x, g.z)):
			near_ok += 1
	dir.wander_region = keep_region
	_check(far_ok == 40, "40 of 40 picks at least %.0f m away (%d)" % [hop, far_ok])
	_check(near_ok == 40, "40 of 40 picks within %.0f m of town_road (%d)" % [creature.REGION_M, near_ok])

	print("D: lurk stalks a silent player it sees")
	var vd: int = ids[2]
	creature._scripted = false
	creature._set_state(&"lurk", &"dev", 0)
	creature._memory.clear()
	var at := Vector3(22, 0, 0)  # open ground (bot.gd IDLE_SPOTS), far from the town stand
	creature.global_position = at + Vector3(6, 0, 0)
	Game.players[vd].pos = at
	creature._seen = {vd: {"position": at, "t": creature._now}}
	dir.phase = &"peak"
	creature._hunt(0.016)
	_check(creature.state == &"stalk" and creature.target == vd, "lurk to stalk on sight: %s %d" % [creature.state, creature.target])
	var st := _last("creature_state")
	_check(st.get("reason") == "seen", "reason seen: %s" % st)

	print("E: a hold target leaving the tree ends its holds")
	var ve: int = ids[0]
	id = await _spring(spots[2], ve)
	_check(id != "", "the night spring pinned peer %d" % ve)
	if id != "":
		Game.players[helper].pos = Game.players[ve].pos + Vector3(1.0, 0.0, 0.0)
		root.get_node("Net").request_received.emit(&"hold", helper, [&"pry", id])
		await physics_frame
		_check(registry.holds.has(helper), "the helper holds pry")
		race._forget(id)  # the trap goes: its hold target is queue_freed
		await _wait(0.2)
		var c := _last("hold_cancelled")
		_check(not registry.holds.has(helper) and c.get("reason") == "target_gone", "cancelled target_gone: %s" % c)

	var Data_: Node = root.get_node("Data")
	var num := func(id: StringName, f: StringName) -> float: return float(Data_.value(&"creature", id, f))

	print("F: a dark building: it bangs first")
	var vf: int = ids[1] if not Game.is_ghost(ids[1]) else ids[2]
	dev.run("gen damage")
	await _wait(0.5)
	var bangs := [0]
	root.get_node("Net").apply_received.connect(func(what: StringName, a: Array) -> void:
		if what == &"lure" and a[0] == "door_bang":
			bangs[0] += 1)
	var bi := 0
	var br: Rect2 = creature._rects[bi]
	var in_b := func() -> bool: return br.has_point(Vector2(creature.global_position.x, creature.global_position.z))
	var inside := Vector3(br.get_center().x, 0.0, br.get_center().y)
	Game.players[vf].pos = inside
	var door_id := "door_" + String(creature._rect_names[bi]).to_lower()
	main.get_node("Doors").host_set(door_id, false, 0)  # QA P5-55: shut, as a player would leave it
	creature.global_position = creature._door_step(bi, 8.0)
	creature._scripted = false
	creature._goal = Vector3.INF
	creature._set_state(&"chase", &"dev", vf)
	var see := func() -> void: creature._seen = {vf: {"position": inside, "t": creature._now}}
	see.call()
	var tf := 0.0
	while _last("creature_door_bang").is_empty() and tf < 8.0:
		see.call()
		await physics_frame
		tf += 1.0 / Engine.physics_ticks_per_second
	var bang := _last("creature_door_bang")
	_check(String(bang.get("building", "")) == creature._rect_names[bi], "it banged on %s: %s" % [creature._rect_names[bi], bang])
	_check(not in_b.call(), "outside at the bang")
	tf = 0.0
	var stayed := true
	while tf < num.call(&"door_bang_s", &"seconds") - 0.2:
		see.call()
		stayed = stayed and not in_b.call()
		await physics_frame
		tf += 1.0 / Engine.physics_ticks_per_second
	_check(stayed and bangs[0] >= 2, "it waits outside for door_bang_s, banging (%d bangs sent)" % bangs[0])
	tf = 0.0
	while not in_b.call() and tf < 6.0:
		see.call()
		await physics_frame
		tf += 1.0 / Engine.physics_ticks_per_second
	_check(in_b.call() or Game.is_ghost(vf), "then it goes in")
	_check(main.get_node("Doors").open[door_id], "the door it banged on stands open when it goes in (doc 01: enters through a door)")
	# QA P5-55: a player shuts the door behind it, then the target is outside: it walks out and the door opens once
	main.get_node("Doors").host_set(door_id, false, 0)
	var outside: Vector3 = creature._door_step(bi, 14.0)
	Game.players[vf].pos = outside
	creature.global_position = Vector3(br.get_center().x, 0.0, br.get_center().y)  # the barn centre, far from the door
	var opens := [0]
	var door_cb := func(what: StringName, a: Array) -> void:
		if what == &"door" and a[0] == door_id and a[1]:
			opens[0] += 1
	root.get_node("Net").apply_received.connect(door_cb)
	var thr: Vector3 = creature._door_step(bi, 0.0)
	var d_open := -1.0
	tf = 0.0
	while in_b.call() and tf < 20.0:
		creature._seen = {vf: {"position": outside, "t": creature._now}}
		await physics_frame
		tf += 1.0 / Engine.physics_ticks_per_second
		if d_open < 0.0 and main.get_node("Doors").open[door_id]:
			d_open = Vector2(creature.global_position.x - thr.x, creature.global_position.z - thr.z).length()
	root.get_node("Net").apply_received.disconnect(door_cb)
	_check(d_open > 0.0 and d_open <= 2.6, "the door stays shut until it reaches the threshold (opened at %.1f m)" % d_open)
	_check(opens[0] == 1, "the door opens once on the way out (%d)" % opens[0])
	_check(not in_b.call(), "it walks out of the building")
	_check(main.get_node("Doors").open[door_id], "the door it walks out through stands open")
	await _wait(0.3)
	_check(creature._banged == -1, "leaving clears the bang, so the next entry bangs again (_banged %d)" % creature._banged)
	dev.run("gen repair")
	away.call(vf)

	print("G: a night stalk creeps to a hiding spot, then gives up and leaves")
	var vg: int = ids[2] if not Game.is_ghost(ids[2]) else ids[0]
	dir.phase = &"build_up"  # stalks, no chases (doc 03 section 11.2)
	var pg := Vector3(22, 0, 0)
	Game.players[vg].pos = pg
	creature.global_position = pg + Vector3(30, 0, 0)
	creature._set_state(&"stalk", &"dev", vg)
	creature._seen = {vg: {"position": pg, "t": creature._now - 1.0}}  # sensed, not in sight now (no chase on sight)
	creature._hunt(0.016)
	var hold: Vector3 = creature._hold
	var far_m: float = num.call(&"stalk_hold_far_m", &"metres")
	_check(hold != Vector3.INF and absf(hold.distance_to(pg) - far_m) < 0.2, "a hiding spot %.1f m from the target (want %.0f)" % [hold.distance_to(pg) if hold != Vector3.INF else -1.0, far_m])
	# QA P5-39: the spot is hidden from the target's eye, or it is the 45 degree flank fallback (no ring point hidden)
	var eye: Vector3 = Vector3.UP * creature.EYE_M
	var hidden: bool = hold != Vector3.INF and creature._blocked(pg + eye, hold + eye, 1 | 16)
	var flank := [pg + Vector3.RIGHT.rotated(Vector3.UP, PI / 4.0) * far_m, pg + Vector3.RIGHT.rotated(Vector3.UP, -PI / 4.0) * far_m]
	var flanked: bool = hold != Vector3.INF and (hold.distance_to(flank[0]) < 0.2 or hold.distance_to(flank[1]) < 0.2)
	_check(hidden or flanked, "the spot is out of the target's sight (hidden %s) or the flank fallback (%s)" % [hidden, flanked])
	creature._t_state = num.call(&"stalk_max_s", &"seconds")
	creature._seen = {vg: {"position": pg, "t": creature._now - 1.0}}
	creature._hunt(0.016)
	_check(creature.state == &"lurk" and creature._goal == Vector3.INF, "stalk_max: lurk with no goal at the target: %s %s" % [creature.state, creature._goal])
	creature._seen = {vg: {"position": pg, "t": creature._now}}
	dir.phase = &"peak"
	creature._hunt(0.016)
	_check(creature.state == &"lurk", "it does not re-stalk that player in stalk_rest_s: %s" % creature.state)
	creature._rest.clear()

	print("H: varied retreat away from the target")
	var goals := {}
	var ok_n := 0
	creature.global_position = Vector3(0, 0, 30)
	creature._seen = {vg: {"position": pg, "t": creature._now}}
	for i in 20:
		creature._set_state(&"retreat", &"dev", vg)
		creature._goal = Vector3.INF
		creature._goal_retreat()
		var g: Vector3 = creature._goal
		goals[g] = true
		if g.distance_to(creature.global_position) >= num.call(&"retreat_min_m", &"metres") and g.distance_to(pg) > g.distance_to(creature.global_position):
			ok_n += 1
		creature._set_state(&"lurk", &"dev", 0)
	_check(ok_n == 20 and goals.size() >= 2, "20 of 20 retreats far and away (%d), %d different spots" % [ok_n, goals.size()])
	print("test_p5_39: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
