extends SceneTree
## P5-33 bear trap check (CEO STOP 6: the trap "kills so quickly and randomly"). Three springs on frozen bots:
##   A, day: the race clock is start_m / 3.5 m/s, the creature body starts start_m away and walks in, and a
##      teammate's finished pry frees the victim (before P5-33 it was ignored and the victim died).
##   B, day: nobody pries; the victim dies by the clock with the creature at their side.
##   C, night: no clock; the victim lives until the creature's catch.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_33_trap.gd -- --host --bots=3 --port=54771 --free-mouse
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
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	var ids: Array = Game.players.keys()
	ids.sort()
	for p: int in ids:
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[p].pos = Vector3(-60, 0, -60) + Vector3(p % 7, 0, 0)  # away from every spot
	for b in main.get_node("Bots").get_children():
		b.process_mode = Node.PROCESS_MODE_DISABLED  # the victims never pry themselves (bot.gd `_pry`)
	var spots: Array = []
	for n: Node3D in root.get_tree().get_nodes_in_group(&"trap_spots"):
		if n.get_meta("kind", "") != "deep":
			spots.append(n)
	print("P5-33 trap check: players %s, normal trap spots %d" % [ids, spots.size()])
	var dev: Node
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	dev.run("day 2")
	await _wait(1.0)
	var speed := float(root.get_node("Data").value(&"creature", &"trap_race_speed_mps", &"speed_mps"))

	print("A: day, a teammate pries")
	var va: int = ids[1]
	var id := await _spring(spots[0], va)
	_check(id != "", "the day spring pinned peer %d" % va)
	if id != "":
		var r: Dictionary = race.races[id]
		var d0: float = creature.global_position.distance_to(Game.players[va].pos)
		print("    start_m %.1f deadline %.2f s, creature %.1f m away, HUD end set %s" % [r.start_m, r.deadline, d0, race.ends.has(id)])
		_check(r.start_m >= 29.0 and r.start_m <= 35.0, "start distance is 32 +- 3 m (was 25 +- 3)")
		_check(absf(r.deadline - r.start_m / speed) < 0.01, "the clock is start_m / %.1f m/s" % speed)
		_check(absf(d0 - r.start_m) < 1.5, "the creature body starts start_m away")
		_check(race.ends.has(id), "every peer gets the race end for the HUD")
		await _wait(2.0)
		var d1: float = creature.global_position.distance_to(Game.players[va].pos)
		print("    after 2 s the creature is %.1f m away (closed %.1f m)" % [d1, d0 - d1])
		_check(d0 - d1 > 4.0, "the creature walks in on the deadline")
		var helper: int = ids[ids.size() - 1]  # the host player, beside the trap, holds pry on it
		Game.players[helper].pos = Game.players[va].pos + Vector3(1.0, 0.0, 0.0)
		root.get_node("Net").request_received.emit(&"hold", helper, [&"pry", id])
		var t := 0.0
		while Game.players[va].pinned and t < 6.0:
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		print("    the teammate's pry took %.2f s" % t)
		Game.players[helper].pos = Vector3(-60, 0, -60)
		var res := _last("trap_race_result")
		_check(not Game.players[va].pinned, "a teammate's pry freed the victim")
		_check(bool(res.get("survived", false)) and not bool(res.get("solo", true)), "trap_race_result survived, not solo: %s" % res)

	print("B: day, nobody pries")
	var vb: int = ids[2]
	id = await _spring(spots[1], vb)
	_check(id != "", "the second day spring pinned peer %d" % vb)
	if id != "":
		var dl: float = race.races[id].deadline
		var t := 0.0
		var dead := {}
		while t < dl + 2.0 and dead.is_empty():
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			var e := _last("death")
			if not e.is_empty() and int(e.get("player", 0)) == vb:
				dead = e
		var at: float = creature.global_position.distance_to(Game.players[vb].pos)
		print("    death %s at %.2f s of %.2f, creature %.1f m away" % [dead, t, dl, at])
		_check(String(dead.get("cause", "")) == "trap_race", "the clock killed with cause trap_race")
		_check(absf(t - dl) < 0.2, "at the deadline")
		_check(at <= 3.0, "with the creature at the victim (the warning walked in)")

	print("C: night, no clock")
	dev.run("phase night")
	await _wait(1.0)
	var vc: int = ids[3]
	id = await _spring(spots[2], vc)
	_check(id != "", "the night spring pinned peer %d" % vc)
	if id != "":
		_check(is_inf(float(race.races[id].deadline)), "a night pin has no deadline")
		_check(not race.ends.has(id), "no HUD clock at night")
		var pin := _last("trap_pinned")
		_check(pin.get("race") == false, "trap_pinned race false: %s" % pin)
		await _wait(12.0)
		_check(not Game.is_ghost(vc), "12 s pinned at night and alive")
		creature.caught.emit(vc)
		await _wait(0.5)
		var e := _last("death")
		_check(Game.is_ghost(vc) and String(e.get("cause", "")) == "night_trap", "the creature's catch kills a night pin: %s" % e)
	print("test_p5_33_trap: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
