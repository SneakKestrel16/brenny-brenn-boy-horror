extends Control
## Doc 05 s14 (P3-11): the emote wheel. Hold `emote_wheel` (Z): four words around the screen centre;
## the mouse picks one (it does not turn the head while the wheel is open); releasing fires it. A short
## mouse move picks nothing. Plain text, no art yet, local only (`WhistleEmotes` owns it).

signal picked(kind: StringName)

const DIRS := {&"wave": Vector2.UP, &"point": Vector2.RIGHT, &"shrug": Vector2.DOWN, &"scream": Vector2.LEFT}
const RADIUS := 120.0  ## px from the centre to each word (placeholder)
const DEAD := 25.0  ## px of mouse travel before anything is picked

var _aim := Vector2.ZERO
var _labels := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in DIRS:
		var l := Label.new()
		l.text = String(k)
		l.add_theme_font_size_override(&"font_size", 28)
		l.add_theme_color_override(&"font_outline_color", Color.BLACK)
		l.add_theme_constant_override(&"outline_size", 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_CENTER)
		var c: Vector2 = DIRS[k] * RADIUS  # offsets from the screen centre
		l.offset_left = c.x - 80.0
		l.offset_right = c.x + 80.0
		l.offset_top = c.y - 20.0
		l.offset_bottom = c.y + 20.0
		add_child(l)
		_labels[k] = l
	visible = false


func open() -> void:
	_aim = Vector2.ZERO
	visible = true
	_paint()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if Game.console_open:
		visible = false
	elif event is InputEventMouseMotion:
		_aim = (_aim + event.relative).limit_length(RADIUS)
		_paint()
		get_viewport().set_input_as_handled()  # the head stays put while choosing
	elif event.is_action_released(&"emote_wheel"):
		visible = false
		var k := _choice()
		if k != &"":
			picked.emit(k)


func _choice() -> StringName:
	if _aim.length() < DEAD:
		return &""
	var best: StringName = &""
	for k in DIRS:
		if best == &"" or _aim.normalized().dot(DIRS[k]) > _aim.normalized().dot(DIRS[best]):
			best = k
	return best


func _paint() -> void:
	var k := _choice()
	for n in _labels:
		_labels[n].modulate = Color(1, 0.85, 0.3) if n == k else Color(1, 1, 1, 0.6)
