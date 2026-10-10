extends SceneTree
## P5-33 measure (CEO STOP 6 "the creature must go after players at night"): a talking group outdoors on a
## non-scripted night. Four players stand in the open and each speaks at normal volume every TALK_S (voice
## noise, doc 03 s3.1: byte 160 is about 23 m). No dev commands touch the creature. It prints the night's
## stalks and chases by reason, the deaths and the seconds spent in each AI Director phase, then checks that
## the creature went after a player without any dev command.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_33_night.gd -- --host --bots=3 --port=54761 --free-mouse --seed=1
## `--measure-only` prints without the checks (the before run). Exits 0 on pass, 1 on any failure.

const TALK_S := 1.5  ## placeholder: a group chatting
const TALK_BYTE := 160  ## 60 m x (160 / 255)^2 = 23.6 m, normal speech (doc 03 s3.1)
const SPEED := 4.0  ## Engine.time_scale for the night
const SPOTS := [Vector3(22, 0, 0), Vector3(30, 0, 4), Vector3(-20, 0, 8), Vector3(4, 0, 8)]  ## open ground (bot.gd IDLE_SPOTS)

var _fails := 0
var _frames := 0
var _ev: Array = []
var Game: Node
var main: Node
var dev: Node
var dir: Node


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
	Game = root.get_node("Game")
	main = root.get_node("Main")
	dir = main.get_node("AiDirector")
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d, root.get_node("Clock").phase]))
	var ids: Array = Game.players.keys()
	for i in ids.size():
		Game.players[ids[i]].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[ids[i]].pos = SPOTS[i % SPOTS.size()]
	dev.run("day 2")  # night 2: the scripted lurk still runs first (doc 03 s18), then the hunt
	dev.run("phase night")
	var clock := root.get_node("Clock")
	var night_s: float = clock.length_of(&"night")
	Engine.time_scale = SPEED
	var phase_s := {}
	var talk := 0.0
	var t := 0.0
	while clock.phase == &"night":
		await physics_frame
		var dt := 1.0 / Engine.physics_ticks_per_second * SPEED
		t += dt
		phase_s[dir.phase] = float(phase_s.get(dir.phase, 0.0)) + dt
		talk += dt
		if talk >= TALK_S:
			talk = 0.0
			for p: int in Game.players:
				if not Game.is_ghost(p):
					root.get_node("NoiseBus").emit_voice(Game.players[p].pos, TALK_BYTE, p)
	Engine.time_scale = 1.0
	var by := {}
	var deaths := 0
	for e in _ev:
		if e[2] != &"night":
			continue
		if e[0] == "creature_state" and e[1].to in ["stalk", "chase", "lure"]:
			var k := "%s/%s" % [e[1].to, e[1].reason]
			by[k] = int(by.get(k, 0)) + 1
		elif e[0] == "death":
			deaths += 1
	print("P5-33 night measure: night %.0f s, seed %d, players %d" % [night_s, Game.seed_value, ids.size()])
	print("  phase seconds: ", phase_s)
	print("  stalk/chase/lure by reason: ", by)
	print("  deaths: ", deaths)
	var hunted := 0
	for k: String in by:
		if (k.begins_with("chase/") or k.begins_with("stalk/")) and not (k.ends_with("/scripted") or k.ends_with("/dev")):
			hunted += by[k]
	print("  unscripted stalks and chases: ", hunted)
	if not OS.get_cmdline_user_args().has("--measure-only"):
		_check(hunted >= 3, "the creature went after the talking group at least 3 times after the script (before P5-33: 1 to 2)")
		_check(float(phase_s.get(&"fade", 0.0)) + float(phase_s.get(&"relax", 0.0)) < 0.6 * t, "fade and relax hold under 60% of the night (before P5-33: 63 to 79%)")
	print("test_p5_33_night: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)
