extends SceneTree
## P4-34 (D-115) on a live host: at the town stand a kill, lure, scare, stalk pick or knock-off on a player is
## less likely but still possible (seeded, many trials); away from it every roll is won. A creature that
## reaches a player at the stand kills on a won roll and backs off on a lost one.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p4_34.gd -- --host --bots=1 --port=24851 --free-mouse
## Exits 0 on pass, 1 on any failure.

const TRIALS := 2000
const STAND := Vector3(120.0, 0.0, -5.0)  # farm.tscn Props/Sanctuary
const AWAY := Vector3(60.0, 0.0, 0.0)

var _fails := 0
var _frames := 0
var _ev: Array = []  # [name, data] from Log.logged
var Game: Node
var dev: Node
var dir: Node
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


func _pin_all(at: Vector3) -> void:
	for p in Game.players:
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[p].pos = at


## Share of TRIALS fresh rolls of `kind` on peer 1 that were won (each trial past the reroll hold).
func _rate(kind: StringName) -> float:
	var won := 0
	for i in TRIALS:
		dir._now += float(dir._d.town_stand.reroll_s) + 1.0
		if dir.stand_ok(kind, 1):
			won += 1
	return float(won) / TRIALS


func _run() -> void:
	Game = root.get_node("Game")
	var main := root.get_node("Main")
	dir = get_first_node_in_group(&"ai_director")
	cr = get_first_node_in_group(&"creature")
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	_check(dir != null and dir._ok and cr != null and dev != null, "host AI Director, creature and dev console present")
	if _fails:
		quit(1)
		return
	_check(cr._at_stand(STAND) and not cr._at_stand(AWAY), "STAND is inside the stand radius, AWAY is not")
	var ts: Dictionary = dir._d.town_stand
	for kind: StringName in [&"lure", &"scare", &"stalk", &"knock_off", &"kill"]:
		var mult := float(ts[String(kind) + "_mult"])
		_check(mult > 0.0 and mult < 1.0, "%s_mult %.2f is a chance, not a rule" % [kind, mult])
		_pin_all(STAND)
		var at := _rate(kind)
		_check(at > 0.0 and at < 1.0 and absf(at - mult) < 0.05, "%s at the stand won %.3f of %d (mult %.2f)" % [kind, at, TRIALS, mult])
		_pin_all(AWAY)
		_check(_rate(kind) == 1.0, "%s away from the stand always won" % kind)
	# One roll holds for reroll_s: asking every frame cannot wear it down.
	_pin_all(STAND)
	dir._now += float(ts.reroll_s) + 1.0
	var first: bool = dir.stand_ok(&"kill", 1)
	var same := true
	for i in 100:
		dir._now += 0.1
		same = same and dir.stand_ok(&"kill", 1) == first
	_check(same, "100 asks inside reroll_s give the first answer")
	await _reach(false)
	await _reach(true)
	print("test_p4_34: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)


## A hunting creature reaches player 1 at the stand with the kill roll forced to `won`.
func _reach(won: bool) -> void:
	dev.run("phase night")
	await create_timer(0.5).timeout
	for p in Game.players.keys():
		if Game.is_ghost(p):
			dev.run("respawn %d" % p)
	_pin_all(STAND)
	for p in Game.players.keys():
		if p != 1:
			Game.players[p].pos = AWAY + Vector3(0.0, 0.0, 5.0 * p)
	cr._scripted = false
	cr.global_position = STAND + Vector3(0.5, 0.0, 0.0)
	cr.force_state(&"chase", &"test", 1)
	cr._t_state = 100.0
	dir._stand["kill:1"] = [INF, won]
	_ev.clear()
	await create_timer(0.5).timeout
	var st: Variant = null
	for e in _ev:
		if e[0] == "creature_state" and e[1].from == "chase":
			st = e[1]
	_check(st != null and st.to == "retreat" and st.reason == ("reached" if won else "town_stand"),
		"roll %s: chase ends %s" % [won, st])
	_check(Game.is_ghost(1) == won, "roll %s: player 1 %s" % [won, "killed" if won else "alive"])
	dir._stand.erase("kill:1")
	dev.run("phase day")
	await create_timer(0.5).timeout
