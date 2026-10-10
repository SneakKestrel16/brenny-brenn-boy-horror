extends SceneTree
## P5-33 crow measure (CEO STOP 6: "show crows more often: perched, flying over, landing in fields; no louder").
## Runs day 2 and its dusk at SPEED and counts the `crows` events by kind and the fake-out scares, the crow
## models seen in the air or on a field (the flocks call no sound: `_flyover` and `_land`). Then forces a fake-out and checks the
## perch it burst from shows no still crow until `perch_empty_s` has passed (the P5-27 finding).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_33_crows.gd -- --host --bots=3 --port=54772 --free-mouse --seed=1
## `--measure-only` prints without the checks (the before run). Exits 0 on pass, 1 on any failure.

const SPEED := 8.0  ## Engine.time_scale for the day

var _fails := 0
var _frames := 0
var _ev: Array = []
var Game: Node
var main: Node
var scares: Node


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


## Crow models under Scares: the flocks and bursts (the perched ones sit under the markers).
func _flying() -> int:
	var n := 0
	for c in scares.get_children():
		if c is Node3D and String(c.scene_file_path).ends_with("animal_crow.glb"):
			n += 1
	return n


func _perch_shown(perch: Node3D) -> bool:
	for c in perch.get_children():
		if c is Node3D and c.visible:
			return true
	return false


func _run() -> void:
	Game = root.get_node("Game")
	main = root.get_node("Main")
	scares = main.get_node("Scares")
	var clock := root.get_node("Clock")
	var dev: Node
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	dev.run("day 2")
	var t := 0.0
	var most_flying := 0
	Engine.time_scale = SPEED
	while clock.phase in [&"day", &"dusk"]:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second * SPEED
		most_flying = maxi(most_flying, _flying())
	Engine.time_scale = 1.0
	var by := {}
	for e in _ev:
		if e[0] == "crows":
			by[e[1].kind] = int(by.get(e[1].kind, 0)) + 1
		elif e[0] == "scare" and e[1].kind == "fake_out":
			by["fake_out"] = int(by.get("fake_out", 0)) + 1
	var perches: Array = root.get_tree().get_nodes_in_group(&"crow_perches")
	print("P5-33 crow measure: day+dusk %.0f s, seed %d, perches %d" % [t, Game.seed_value, perches.size()])
	print("  events: ", by)
	print("  most crow models in the air or on a field at once: ", most_flying)
	print("  crows per minute (flyover + land): %.2f" % ((int(by.get("flyover", 0)) + int(by.get("land", 0))) * 60.0 / t))

	var p1: int = Game.players.keys().filter(func(p: int) -> bool: return p == 1)[0]
	dev.run("phase day")
	await physics_frame
	Game.players[p1].pos = (perches[0] as Node3D).global_position + Vector3(1, 0, 0)
	await physics_frame
	scares._fake_out(true)
	var burst: Dictionary = _ev[_ev.size() - 1][1] if _ev[_ev.size() - 1][0] == "scare" else {}
	var at := Vector3(burst.position[0], burst.position[1], burst.position[2]) if burst.has("position") else Vector3.INF
	var perch: Node3D = null
	for n: Node3D in perches:
		if n.global_position.distance_to(at) < 0.5:
			perch = n
	await physics_frame
	var hidden_now := perch != null and not _perch_shown(perch)
	print("  forced fake-out at %s: perch %s, still crow hidden %s" % [at, perch.name if perch else "none", hidden_now])
	var empty_s := float(root.get_node("Data").value(&"ai_director", &"crows", &"perch_empty_s"))
	Engine.time_scale = SPEED
	var w := 0.0
	while w < empty_s + 2.0:
		await physics_frame
		w += 1.0 / Engine.physics_ticks_per_second * SPEED
	Engine.time_scale = 1.0
	var back := perch != null and _perch_shown(perch)
	print("  after %.0f s the still crow is back: %s" % [w, back])
	if not OS.get_cmdline_user_args().has("--measure-only"):
		_check(int(by.get("flyover", 0)) >= 3, "at least 3 flyovers in a day (before P5-33: none)")
		_check(int(by.get("land", 0)) >= 2, "at least 2 field landings in a day (before P5-33: none)")
		_check(most_flying >= 3, "the flocks were drawn (crow models in the air or on a field)")
		_check(hidden_now, "the perch a fake-out bursts from has no still crow (P5-27 finding)")
		_check(back, "the still crow returns after perch_empty_s")
	print("test_p5_33_crows: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
