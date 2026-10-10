extends SceneTree
## P5-31 and P5-51 on a live host: the Creature reaches every new corn cover point (cover_17..31) in Lurk, and Stalks a player
## standing in the open next to each from inside it.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://game/world/check_corn_creature.gd -- --host --bots=1 --port=54721 --free-mouse
## Exits 0 on pass, 1 on any failure.

const OPEN := {17: Vector3(73, 0, -7), 18: Vector3(88, 0, -5), 19: Vector3(72, 0, 3), 20: Vector3(73.5, 0, -5),
		21: Vector3(85.5, 0, 23), 22: Vector3(69, 0, 24.5),
		23: Vector3(53, 0, -28), 24: Vector3(28, 0, -12), 25: Vector3(-1, 0, -27), 26: Vector3(11, 0, 22), 27: Vector3(28, 0, 14),
		28: Vector3(59, 0, 34), 29: Vector3(90, 0, 36), 30: Vector3(89, 0, 12), 31: Vector3(-35, 0, 32)}  # a player in the open 10 to 15 m from each cover point (17..22 P5-31, 23..31 P5-51)
const START := {17: Vector3(72, 0, -47), 18: Vector3(110, 0, -30), 19: Vector3(80, 0, 57), 20: Vector3(40, 0, -30),
		21: Vector3(115, 0, 30), 22: Vector3(70, 0, 60),
		23: Vector3(45, 0, -62), 24: Vector3(28, 0, -60), 25: Vector3(-1, 0, -62), 26: Vector3(11, 0, 70), 27: Vector3(28, 0, 70),
		28: Vector3(59, 0, 70), 29: Vector3(78, 0, 70), 30: Vector3(89, 0, 70), 31: Vector3(-35, 0, 70)}  # in the ring, away from the patch

var _fails := 0
var _frames := 0
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


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	var game := root.get_node("Game")
	main = root.get_node("Main")
	cr = main.get_node("Creature")
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	_check(dev != null and cr._ok, "dev console and a host creature")
	if dev == null or not cr._ok:
		quit(1)
		return
	for p in game.players:
		game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		game.players[p].pos = Vector3(-20, 0, 40)
	dev.run("phase night")
	await create_timer(0.5).timeout
	var covers := {}
	for n: Node3D in get_nodes_in_group(&"creature_cover"):
		covers[int(String(n.name).trim_prefix("cover_"))] = n.global_position
	for id in OPEN:
		dev.run("phase night")  # 15 points outlast one night
		var cover: Vector3 = covers[id]
		cr.global_position = START[id]
		cr._scripted = false
		cr._memory.clear()
		cr.force_state(&"lurk", &"test", 0)
		cr._search_until = -1.0
		var t := 0.0
		while t < 60.0 and _flat(cr.global_position, cover) > 1.5:
			if root.get_node("Clock").phase != &"night":
				dev.run("phase night")
			cr._goal = cover
			await create_timer(0.25).timeout
			t += 0.25
		_check(_flat(cr.global_position, cover) <= 1.5, "Lurk reaches cover_%d %s from %s in %.0f s (at %s)" % [id, cover, START[id], t, cr.global_position])
		# Stalk: a player in the open, the Creature starts inside the patch and closes in
		game.players[1].pos = OPEN[id]
		var best := _flat(cr.global_position, OPEN[id])
		cr._memory.clear()
		cr.force_state(&"stalk", &"test", 1)
		t = 0.0
		while t < cr._num[&"stalk_max_s"] + 1.0 and cr.state == &"stalk":
			cr._memory.append({"position": OPEN[id], "margin": 0.0, "t": cr._now, "peer": 1, "kind": &"step_walk"})
			await create_timer(0.25).timeout
			t += 0.25
			best = minf(best, _flat(cr.global_position, OPEN[id]))
		_check(best <= cr._num[&"stalk_hold_near_m"] + 3.0 or cr.state == &"chase", "Stalk from cover_%d closes to its stand-off or starts the chase (the AI Director may allow it) from the player at %s: %.1f m (start %.1f), state %s" % [id, OPEN[id], best, _flat(cover, OPEN[id]), cr.state])
	print("check_corn_creature: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
