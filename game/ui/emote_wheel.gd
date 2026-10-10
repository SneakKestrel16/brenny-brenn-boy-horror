extends Control
## Doc 05 s14 (P3-11, P5-45): the emote wheel. Hold `emote_wheel` (Z): the emote names sit on a ring around the
## screen centre, the first at the top, clockwise in `data/emotes.json` order; the mouse picks the nearest by angle
## (it does not turn the head while the wheel is open); releasing fires it. A short mouse move picks nothing.
## Plain text, no art yet, local only (`WhistleEmotes` owns it and sets `kinds` before it enters the tree).

signal picked(kind: StringName)

var kinds: Array[StringName] = [&"wave", &"point", &"shrug", &"scream"]
const RADIUS := Vector2(380.0, 250.0)  ## px from the centre to each outer word (placeholder); an ellipse, words are wide
const INNER_RADIUS := Vector2(190.0, 115.0)  ## P5-60: the second ring, for emotes past OUTER_MAX
const OUTER_MAX := 11  ## emotes on the outer ring (placeholder; what fits at 1280x720 without words colliding)
const AIM := 260.0  ## px the aim point can travel
const SPLIT := 130.0  ## px of aim travel below which the inner ring is picked (if there is one)
const DEAD := 25.0  ## px of mouse travel before anything is picked

var _aim := Vector2.ZERO
var _ring := {}  ## emote -> true if on the inner ring
var _labels := {}
var _dirs := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer := mini(kinds.size(), OUTER_MAX)  # P5-60: the first OUTER_MAX on the outer ring, the rest on an inner ring
	for i in kinds.size():
		var k := kinds[i]
		var inner := i >= outer
		var n := kinds.size() - outer if inner else outer
		var a := TAU * (i - outer if inner else i) / n
		var c := Vector2(sin(a), -cos(a)) * (INNER_RADIUS if inner else RADIUS)  # offsets from the screen centre
		_dirs[k] = c.normalized()  # pick by the direction the word sits on screen, not the ring angle
		_ring[k] = inner
		var l := Label.new()
		l.text = String(k).replace("_", " ")
		l.add_theme_font_size_override(&"font_size", 20 if inner else 26)
		l.add_theme_color_override(&"font_outline_color", Color.BLACK)
		l.add_theme_constant_override(&"outline_size", 10 if inner else 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_CENTER)
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
		_aim = (_aim + event.relative).limit_length(AIM)
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
	var inner := _aim.length() < SPLIT
	for k in _dirs:
		if _ring[k] != inner and _ring.values().has(inner):
			continue  # aim near the centre picks the inner ring, farther out the outer
		if best == &"" or _aim.normalized().dot(_dirs[k]) > _aim.normalized().dot(_dirs[best]):
			best = k
	return best


func _paint() -> void:
	var k := _choice()
	for n in _labels:
		_labels[n].modulate = Color(1, 0.85, 0.3) if n == k else Color(1, 1, 1, 1.0 if _ring[n] else 0.6)
