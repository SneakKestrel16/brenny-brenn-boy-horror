extends SceneTree
## P4-25 on a live host: the CEO's Harvest Moon test. Players started and stopped pushing and the creature only
## ever stood off, because it went only for pushers (doc 03 section 14). Act 2 with nobody pushing: it goes for
## the sensed player nearest the cart, but never into a lit building.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p4_25_harvest_e2e.gd -- --host --bots=1 --port=24732 --free-mouse
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


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _in_barn(p: Vector3) -> bool:
	return p.x > -8.0 and p.x < 8.0 and p.z > -20.0 and p.z < 0.0  # doc 04 s4: barn x -8..8, z -20..0


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
	for p in Game.players:
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[p].pos = Vector3(90, 0, 40)
	root.get_node("Clock").day = int(root.get_node("Data").value(&"season", &"season_days"))
	dev.run("phase harvest_moon")
	var farm: Node = main.get_node("Farm")
	var cart: Node = farm.cart
	var gen: Node = main.get_node("Generator")
	cart.act = cart.PUSH  # act 2 without the loading (test_cart covers that)
	cart.offset = 25.0
	cart._place()
	await _wait(0.5)
	var caught := [0]
	cr.caught.connect(func(_p: int) -> void: caught[0] += 1)
	# Lit barn, nobody pushing: no kill and it stays out.
	gen.repair()
	Game.players[1].pos = Vector3(-4, 0, -12)
	cr.global_position = Vector3(0, 0, 6)
	var inside := false
	for i in 24:
		await _wait(0.25)
		inside = inside or _in_barn(cr.global_position)
	_check(caught[0] == 0 and not inside, "act 2, nobody pushing, player in the lit barn: caught %d, inside %s" % [caught[0], inside])
	# The CEO's pattern: push 1 s, let go 1 s, by the cart outdoors. Before P4-25 it only stood off.
	gen.damage()
	cr.global_position = cart.target_pos() + Vector3(12, 0, 0)
	_ev.clear()
	var t := 0.0
	while t < 60.0 and caught[0] == 0:  # a knock-off retreat lasts retreat_s 30 (data/creature.json)
		if Game.is_ghost(1):
			break
		Game.players[1].pos = cart.target_pos()  # the player walks with the cart
		if int(t) % 2 == 0:
			farm.registry.request(1, &"push_cart", "cart")
		else:
			farm.registry.cancel(1)
		await _wait(0.25)
		t += 0.25
	farm.registry.cancel(1)
	var why: Array = _ev.filter(func(e: Array) -> bool: return e[0] == "chase_started").map(func(e: Array) -> String: return e[1].reason)
	# P5-39: a second lunge after the knock-off retreat also counts. Whether it comes back as a no_pushers chase or a
	# knock-off depends on where lurk wanders after retreat_s; standing off (no second chase) still fails.
	_check(caught[0] >= 1 or why.has("no_pushers") or why.size() >= 2,"start/stop pushing: it went for the player (caught %d, chases %s, %.1f s)" % [caught[0], why, t])
	print("test_p4_25_harvest_e2e: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
