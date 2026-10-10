extends Node
## QA review of P5-44 / P5-46. Modes (user arg):
##   --mode=save      set mouse_sensitivity through the Comfort slider (2.0x) and quit (headless)
##   --mode=load      a fresh boot: print the loaded value and the slider (headless)
##   --mode=screens   windowed: Comfort tab, Dawn Report and ghost banner with long strings at 1280x720 and 1920x1080;
##                    prints OFFSCREEN lines and QA_SCREENS PASS|FAIL; --shots=<dir> saves PNGs. The HUD is freed
##                    before the second window size, so a UiText.fit lambda left on size_changed prints
##                    "Lambda capture at index 0 was freed" (P5-44 QA fail).

const LONG := "Brennan-the-extremely-long-named-farmhand-from-the-far-side-of-the-county watched the creature drag the scarecrow across three fields while the generator coughed and every crow on the farm screamed at once, and nobody, not one of them, thought to fetch the shovel before the pit was dug under the porch." \
		+ " Then it came back for the cans."
const UNBROKEN := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

var _fails := 0
var _shots := ""


func _ready() -> void:
	var mode := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.trim_prefix("--mode=")
		if a.begins_with("--shots="):
			_shots = a.trim_prefix("--shots=")
	await get_tree().process_frame
	if mode == "save":
		var m := SettingsMenu.new()
		add_child(m)
		m._sens.value = 2.0
		print("QA_SAVE stored=", Settings.get_value(&"mouse_sensitivity"))
	elif mode == "load":
		var m := SettingsMenu.new()
		add_child(m)
		print("QA_LOAD value=", Settings.get_value(&"mouse_sensitivity"), " slider=", m._sens.value)
	else:
		await _screens()
	get_tree().quit(0 if _fails == 0 else 1)


func _screens() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = size
		await get_tree().create_timer(0.3).timeout
		var m := SettingsMenu.new()
		add_child(m)
		m.tabs.current_tab = m.tabs.get_tab_idx_from_control(m.tabs.get_node("Comfort")) if m.tabs.has_node("Comfort") else 0
		await get_tree().create_timer(0.2).timeout
		_check(size)
		await _shot("comfort_%dx%d" % [size.x, size.y])
		m.queue_free()
		var dr: CanvasLayer = load("res://game/ui/dawn_report.gd").new()
		add_child(dr)
		await get_tree().process_frame
		dr._show({"season": 1, "day": 3, "trait_line": LONG, "streamer_safe": false, "final": false,
			"ledger": [["Cash-in", 120, false], ["Crops left in the ground, half price", 40, false], ["Medical bill", -60, true],
				["Added to the final payment", 30, true], ["Farm damage", -15, true], ["Balance", 999999, false]],
			"sections": [{"id": "a", "title": "Deaths", "lines": [LONG, UNBROKEN], "replays": []},
				{"id": "b", "title": UNBROKEN, "lines": [LONG], "replays": []}]})
		dr._t = 99.0
		for i in 10:
			await get_tree().create_timer(0.1).timeout
		_check(size)
		await _shot("dawn_%dx%d" % [size.x, size.y])
		dr.queue_free()
		Game.console_open = false
		var hud: CanvasLayer = _hud()
		await get_tree().create_timer(0.3).timeout  # real ghost banner from _process
		print("ghost banner: ", hud._banner.text.substr(0, 40))
		_check(size)
		await _shot("ghost_%dx%d" % [size.x, size.y])
		hud.queue_free()
		await get_tree().process_frame
	print("QA_SCREENS ", "PASS" if _fails == 0 else "FAIL")


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
		return &""


func _hud() -> CanvasLayer:
	var hud: CanvasLayer = load("res://game/ui/hud.gd").new()
	hud.player = StubPlayer.new()
	add_child(hud.player)
	hud.hold = StubHold.new()
	add_child(hud.hold)
	add_child(hud)
	return hud


func _check(size: Vector2i) -> void:
	print("checked %d at %s" % [_walk(get_tree().root, Rect2(Vector2.ZERO, Vector2(size)).grow(1.0)), size])


func _walk(node: Node, view: Rect2) -> int:
	var n := 0
	if node is Label or node is RichTextLabel:
		var c: Control = node
		if c.is_visible_in_tree() and not (c is Label and (c as Label).text.is_empty()) and not (c is Label and (c as Label).clip_text):
			n += 1
			var r := c.get_global_rect()
			if not view.encloses(r):
				_fails += 1
				print("OFFSCREEN %s rect=%s text=%s" % [c.get_path(), r, (c as Label).text.substr(0, 30) if c is Label else ""])
	if node is ScrollContainer:  # content scrolls and is clipped: the box itself must fit
		n += 1
		if not view.encloses((node as Control).get_global_rect()):
			_fails += 1
			print("OFFSCREEN %s rect=%s" % [node.get_path(), (node as Control).get_global_rect()])
		return n
	for ch in node.get_children():
		n += _walk(ch, view)
	return n


func _shot(n: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, n])
