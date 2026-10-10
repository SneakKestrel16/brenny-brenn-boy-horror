extends Node
## P5-44 QA: every on-screen message wraps and stays inside the viewport, at 1280x720 and 1920x1080, with the
## longest real strings plus a forced 400-character line. Needs a window (labels have no size headless):
##   "$GODOT" --audio-driver Dummy --path . res://tests/ui/test_screen_text.tscn -- --free-mouse [--shots=<dir>]
## Prints one line per offender and "SCREEN_TEXT PASS" or "SCREEN_TEXT FAIL"; exit code 1 on fail.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const FORCED := "This message is far too long for one line and must wrap inside the safe margins of the screen, whatever the window size is, because nobody can read text that runs off the edge of the monitor and the CEO saw exactly that happen. " \
		+ "It keeps going for a long while so that even the widest label has to break it into several lines."
const SLOTS := [["Watering can 4/4", "Hold E on a growing plot: water. Well: refill. G: put down"], ["Fuel can, empty", "Hold E on the generator: refuel. G: put down"],
		["Shovel", "Hold E on a pit: fill it. Pegboard: hang it back"], ["Bear trap", "Hold E on the pegboard: hang it"],
		["Seeds: Corn 12, Pumpkin 4, Tomato 3", "Hold E on an empty plot: plant Corn. Q: change"], ["Crops 8/8", "Hold E at the town stand: sell"],
		["Flare gun, 2 shots", "F: fire (scares it off, loud)"], ["Walkie-talkie, 2 spare batteries", "Hold V: talk on the radio"]]

var _fails := 0
var _shots := ""


class StubPlayer extends CharacterBody3D:
	var ghost := true
	var shaken_s := 99.0
	var stamina := 1.0
	var exhausted := false
	var peer := 1
	var yaw := 0.0
	func sprint_max() -> float:
		return 5.0


class StubHold extends Node:
	var aimed_verb: StringName = &""
	var aimed_target: Node = null
	func hold_state() -> Array:
		return [&"", 0.0, ""]
	func held_can_id() -> int:
		return -1
	func fresh_refusal() -> StringName:
		return &"flag_limit"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	await get_tree().process_frame
	var hud := _hud()
	RejoinToast.show_line(FORCED, get_tree())
	var dev: CanvasLayer = load("res://game/debug/dev_console.gd").new()
	add_child(dev)
	dev._show_message(FORCED)
	Imposter.me = true
	var imp: Node = load("res://game/core/imposter_input.gd").new()
	add_child(imp)
	for size: Vector2i in SIZES:
		get_window().size = size
		await get_tree().create_timer(0.3).timeout
		hud.set_process(false)  # the HUD rewrites its labels each frame: freeze it, then force long text
		hud._hint.visible = true
		hud._hint.modulate.a = 1.0
		hud._top.text = "Season 1  Day 1  Daylight  12:00 left\nCoins 100\n" + FORCED
		await get_tree().process_frame
		hud._banner.text = FORCED  # _process rewrites these each frame; force after it
		hud._prompt.text = FORCED
		hud._top.text = "Season 1  Day 1  Daylight  12:00 left\nCoins 100\n" + FORCED
		hud._show_hotbar(SLOTS)
		await get_tree().create_timer(0.1).timeout
		_check_all(size)
		await _shot("hud_%dx%d" % [size.x, size.y])
		var intro := IntroCard.new()  # only in a windowed run on day 1; the card's own labels must fit too
		add_child(intro)
		await get_tree().create_timer(0.2).timeout
		_check_all(size)
		await _shot("intro_%dx%d" % [size.x, size.y])
		intro.queue_free()
		Game.console_open = false
	print("SCREEN_TEXT ", "PASS" if _fails == 0 else "FAIL")
	get_tree().quit(0 if _fails == 0 else 1)


func _hud() -> CanvasLayer:
	var hud: CanvasLayer = load("res://game/ui/hud.gd").new()
	hud.player = StubPlayer.new()
	add_child(hud.player)
	hud.hold = StubHold.new()
	add_child(hud.hold)
	add_child(hud)
	return hud


func _check_all(size: Vector2i) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(size))
	print("checked %d text controls at %s" % [_walk(get_tree().root, view), size])


func _walk(node: Node, view: Rect2) -> int:
	var n := 0
	if node is Label or node is RichTextLabel:
		var c: Control = node
		if c.is_visible_in_tree() and not (c is Label and (c as Label).text.is_empty()):
			n += 1
			var r := c.get_global_rect()
			if not view.grow(1.0).encloses(r):
				_fails += 1
				print("OFFSCREEN %s rect=%s" % [c.get_path(), r])
	for ch in node.get_children():
		n += _walk(ch, view)
	return n


func _shot(shot_name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, shot_name])
