class_name IntroCard
extends CanvasLayer
## P5-34 (doc 01 pitch, Core Loop, Season and Numbers; CEO STOP 6): before the first day of a new season, what the situation
## is and what the goal is. Local to each peer, so nothing is synced; shown once per new save (never for a loaded season or
## a headless run). Skip with a key or a click. Text only: no captions and no voice. Debug user arg: --no-intro.

const TITLE := "FARMER'S DELIGHT"
const SITUATION := "The farm owes the bank, and the bank wants its money in seven days.\n\nSomething lives in the corn. By day it frightens you, and kills only those who take a risk. By night it hunts, copies the voices it hears, and sets traps that become tomorrow's chores."
const GOAL := "Grow and sell crops, pay the bank, and raise the Prize Pumpkin.\n\nOn the seventh night, the Harvest Moon, load the festival cart and push it out the gate with someone alive. Make the final payment and the farm is yours."
const HINT := "The signboard in the barn explains the work."
const SKIP := "Press any key to begin"

var _root: Control


static func wanted() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-intro") \
		and Save.pending.is_empty() and Clock.day == 1 and Clock.phase == &"day" and Game.season_no == 1


func _ready() -> void:
	if not wanted():
		queue_free()
		return
	layer = 108  # under the Dawn Report (110) and the pause menu (120)
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.03, 0.02, 0.02, 0.94)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 820
	box.add_theme_constant_override(&"separation", 10)
	center.add_child(box)
	_label(box, TITLE, 56, Color(0.95, 0.8, 0.4))
	_label(box, "THE SITUATION", 26, Color(0.8, 0.5, 0.4))
	_label(box, SITUATION, 24, Color(0.92, 0.9, 0.85))
	_label(box, "THE GOAL", 26, Color(0.8, 0.5, 0.4))
	_label(box, GOAL, 24, Color(0.92, 0.9, 0.85))
	_label(box, HINT, 20, Color(0.7, 0.7, 0.65))
	_label(box, SKIP, 20, Color(0.95, 0.8, 0.4))
	Game.console_open = true  # game keys off while the card is up (as the pause menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Log.event(&"intro_shown", {})


func _label(box: Control, text: String, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


func _input(event: InputEvent) -> void:
	if _root == null:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		Game.console_open = false
		if not Game.in_lobby:
			Game.capture_mouse()
		Log.event(&"intro_skipped", {})
		queue_free()
