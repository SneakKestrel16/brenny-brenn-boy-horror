extends CanvasLayer
## P1-16 (Q-046): the plainest prompt layer a first-time tester needs. Text only, no art, no markers
## pointing at anything (doc 05 section 3 "No HUD markers"; doc 01 "Onboarding" wants in-world intros, which
## come later). Local player only. Built in code; the same on a headless run (controls exist, nothing draws).

const HINT_S := 20.0  ## controls hint stays this long after first spawn (placeholder)
const PHASE_TEXT := {&"day": "Daylight", &"dusk": "Dusk", &"night": "NIGHT", &"dawn": "Dawn", &"harvest_moon": "HARVEST MOON"}
const VERB_TEXT := {&"plant": "Plant", &"water": "Water", &"harvest": "Harvest", &"sell": "Sell the crop",
		&"fill_can": "Fill the watering can", &"pry": "Pry free", &"refuel": "Refuel",
		&"disarm_bear": "Disarm the bear trap", &"fill_pit": "Fill the pit", &"place_flag": "Plant a flag",
		&"hang_trap": "Hang the trap on the board", &"take_shovel": "Take the shovel", &"return_shovel": "Hang the shovel back", &"take_trap": "Pick up the trap"}
const REFUSED_TEXT := {&"locked": "Locked", &"need_shovel": "You need the shovel", &"hands_full": "Your hands are full",
		&"pegboard_full": "No free hook", &"flag_here": "A flag is already here", &"not_armed": "Nothing set here"}

var player: CharacterBody3D
var hold: Node  ## the player's HoldController

var _top: Label
var _prompt: Label
var _banner: Label
var _hint: Label
var _bar: ProgressBar
var _dot: ColorRect
var _t := 0.0
var _shaken_s := 0.0


func _ready() -> void:
	layer = 10
	_top = _label(Vector2(16, 12), 20)
	_prompt = _label(Vector2.ZERO, 26)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -170
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner = _label(Vector2.ZERO, 34)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 90
	_banner.offset_left = -420
	_banner.offset_right = 420
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _label(Vector2.ZERO, 22)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hint.offset_left = -260
	_hint.offset_right = 260
	_hint.offset_top = -150
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "CONTROLS\n%s  move\n%s  sprint (runs out, and it is loud)\n%s  crouch (quiet)\n%s  stand still (silent)\nHold %s  work the thing you look at\nHold %s  plant a flag where you look\n%s  free the mouse" % [
			_move_keys(), _key(&"sprint"), _key(&"crouch"), _key(&"go_still"), _key(&"interact"), _key(&"alt_use"), _key(&"pause")]
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(220, 14)
	_bar.max_value = float(Data.value(&"labor", &"sprint", &"max_s"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.9, 0.9)
	_bar.add_theme_stylebox_override(&"fill", fill)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.offset_left = 16
	_bar.offset_top = -34
	_bar.offset_right = 236
	_bar.offset_bottom = -20
	add_child(_bar)
	_dot = ColorRect.new()  # D-047 centre dot: a plain dot, points at nothing
	_dot.color = Color(1, 1, 1, 0.8)
	_dot.custom_minimum_size = Vector2(4, 4)
	_dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dot.offset_left = -2
	_dot.offset_right = 2
	_dot.offset_top = -2
	_dot.offset_bottom = 2
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dot)
	Net.apply_received.connect(func(what: StringName, args: Array) -> void:
		if what == &"shaken":
			_shaken_s = float(args[0]))


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	_shaken_s = maxf(_shaken_s - delta, 0.0)
	var left := maxf(Clock.length_of(Clock.phase) - Clock.t_phase, 0.0)
	var farm := get_tree().get_first_node_in_group(&"farm")
	_top.text = "Day %d  %s  %d:%02d left\nCoins %d%s" % [Clock.day, PHASE_TEXT.get(Clock.phase, String(Clock.phase)),
			int(left) / 60, int(left) % 60, farm.coins if farm else 0,
			"\nShaken: slow for %d s" % ceili(_shaken_s) if _shaken_s > 0.0 else ""]
	_bar.value = player.stamina
	_dot.visible = bool(Settings.get_value(&"centre_dot")) and not player.ghost
	_bar.modulate = Color(1, 0.4, 0.3) if player.exhausted else Color.WHITE
	_bar.visible = not player.ghost
	_hint.visible = _t < HINT_S and not Game.console_open  # hidden behind the pause menu
	_hint.modulate.a = clampf((HINT_S - _t) / 3.0, 0.0, 1.0)
	var text := ""
	if player.ghost:
		text = "YOU ARE DEAD. You are a ghost: nobody hears or sees you.\n%s / %s watch a friend. You come back at dawn." % [
				_key(&"spectate_prev"), _key(&"spectate_next")]
	elif player.pinned:
		text = "CAUGHT IN A TRAP. Hold %s on the trap to pry free. A friend can help." % _key(&"interact")
	_banner.text = text
	var hs: Array = hold.hold_state()
	var prompt := ""
	if hs[0] != &"":
		prompt = "%s... %d%%" % [_verb_text(hs[0]), int(hs[1] * 100.0)]
	elif hold.aimed_verb != &"":
		prompt = "Hold %s: %s" % [_key(&"interact"), _verb_text(hold.aimed_verb)]
	var why: StringName = hold.fresh_refusal()
	if why != &"" and hs[0] == &"":
		prompt = REFUSED_TEXT.get(why, String(why).capitalize().replace("_", " "))
	_prompt.text = prompt


func _verb_text(verb: StringName) -> String:
	return VERB_TEXT.get(verb, String(verb).capitalize().replace("_", " "))


func _key(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode if e.physical_keycode != 0 else e.keycode)
		if e is InputEventMouseButton:
			return "Mouse %d" % e.button_index
	return "?"


func _move_keys() -> String:
	return "%s%s%s%s" % [_key(&"move_forward"), _key(&"move_left"), _key(&"move_back"), _key(&"move_right")]
