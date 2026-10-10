class_name ImposterInput
extends Node
## P5-11: the imposter's kit keys, on the imposter's own client only (`Imposter.me`). Every other client
## ignores the keys and sends nothing, so a stray press tells the host nothing. `[` throws a whistle
## 15 m ahead (imposter.json whistle_throw, range 25 m); `]` leaves the pen gate open (gate_prop). The host
## validates and stays silent on a refusal. Keys are placeholders (Q-303).

const THROW_M := 15.0
const NOTICE_S := 10.0

var _was := false
var _label: Label
var _left := 0.0


## The private notice: on the rising edge of `Imposter.me` (match start, rejoin, dev pick, host picked), on this
## client only. Nothing is sent; `me` is only ever set on the imposter's own client.
func _process(delta: float) -> void:
	if Imposter.me and not _was:
		_left = NOTICE_S
		if _label == null:
			var layer := CanvasLayer.new()
			add_child(layer)
			_label = Label.new()
			_label.text = "You are the IMPOSTER. Tell no one.\n[  throw a whistle\n]  leave the pen gate open"
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.add_theme_font_size_override("font_size", 22)
			_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
			_label.add_theme_color_override("font_outline_color", Color.BLACK)
			_label.add_theme_constant_override("outline_size", 6)
			_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 60)
			layer.add_child(_label)
	_was = Imposter.me
	_left -= delta
	if _label != null:
		_label.visible = _left > 0.0 and Imposter.me


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not Imposter.me or Game.console_open:
		return
	var pl: Node3D = get_parent().get_node("Players").player(Game.local_peer())
	if pl == null:
		return
	var at := pl.global_position - pl.global_transform.basis.z * THROW_M
	if k.keycode == KEY_BRACKETLEFT:
		Net.to_host(&"request_imposter_act", [&"whistle_throw", at])
	elif k.keycode == KEY_BRACKETRIGHT:
		Net.to_host(&"request_imposter_act", [&"gate_prop", pl.global_position])
