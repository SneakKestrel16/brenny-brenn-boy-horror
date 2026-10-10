class_name ImposterInput
extends Node
## P5-11, P5-25: the imposter's kit keys, on the imposter's own client only (`Imposter.me`). Every other client
## ignores the keys and sends nothing, so a stray press tells the host nothing. Each kit action is a hold like any
## other (doc 05 s27): keep the key down until the bar fills. `[` throws a whistle 15 m ahead (imposter.json
## whistle_throw, range 25 m), `]` leaves the pen gate open (gate_prop), `\` flips the pegboard outline you face
## (pegboard_mark). The client tells the host when the hold starts and when it ends; the host times the gap and
## stays silent on a refusal. `false_flag` is the normal flag hold. Keys are placeholders (Q-303).

const THROW_M := 15.0
const PEG_REACH_M := 2.0  ## where the pegboard mark aims, ahead of the imposter
const NOTICE_S := 10.0
const KEYS := {&"whistle_throw": KEY_BRACKETLEFT, &"gate_prop": KEY_BRACKETRIGHT, &"pegboard_mark": KEY_BACKSLASH}

var _was := false
var _label: Label
var _left := 0.0
var _kind := &""  ## the kit piece being held, or empty
var _held := 0.0
var _spent := &""  ## a finished hold waits for its key to be released
var _bar: ProgressBar
var _bar_label: Label


## The private notice: on the rising edge of `Imposter.me` (match start, rejoin, dev pick, host picked), on this
## client only. Nothing is sent; `me` is only ever set on the imposter's own client.
func _process(delta: float) -> void:
	if Imposter.me and not _was:
		_left = NOTICE_S
		if _label == null:
			var layer := CanvasLayer.new()
			add_child(layer)
			_label = Label.new()
			_label.text = "You are the IMPOSTER. Tell no one.\nHold [  throw a whistle\nHold ]  leave the pen gate open\nHold \\  fake a pegboard outline"
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.add_theme_font_size_override("font_size", 22)
			_label.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
			_label.add_theme_color_override("font_outline_color", Color.BLACK)
			_label.add_theme_constant_override("outline_size", 6)
			_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 60)
			layer.add_child(_label)
			_bar = ProgressBar.new()
			_bar.custom_minimum_size = Vector2(240, 18)
			_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 140)
			_bar.show_percentage = false
			_bar.visible = false
			layer.add_child(_bar)
			_bar_label = Label.new()  # child of the bar, sitting just above it
			_bar_label.add_theme_color_override("font_outline_color", Color.BLACK)
			_bar_label.add_theme_constant_override("outline_size", 4)
			_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_bar_label.size = Vector2(240, 24)
			_bar_label.position = Vector2(0, -28)
			_bar.add_child(_bar_label)
	_was = Imposter.me
	_left -= delta
	if _label != null:
		_label.visible = _left > 0.0 and Imposter.me
		_hold(delta)


func _hold(delta: float) -> void:
	var kind := &""
	if Imposter.me and not Game.console_open:
		for k: StringName in KEYS:
			if Input.is_key_pressed(KEYS[k]) and k != _spent:
				kind = k
	if _spent != &"" and not Input.is_key_pressed(KEYS[_spent]):
		_spent = &""
	if kind != _kind:  # a new key (restart) or a release (drop)
		_kind = kind
		_held = 0.0
		if kind != &"":
			Net.to_host(&"request_imposter_hold", [kind])
	_bar.visible = kind != &""
	if kind == &"":
		return
	_held += delta
	var need := Imposter.hold_s(kind)
	_bar.value = clampf(_held / need, 0.0, 1.0) * 100.0
	_bar_label.text = "%s... %d%%" % [String(kind).capitalize().replace("_", " "), int(_bar.value)]
	if _held < need:
		return
	var pl: Node3D = get_parent().get_node("Players").player(Game.local_peer())
	if pl != null:
		var at := pl.global_position
		if kind == &"whistle_throw":
			at -= pl.global_transform.basis.z * THROW_M
		elif kind == &"pegboard_mark":
			at -= pl.global_transform.basis.z * PEG_REACH_M
		Net.to_host(&"request_imposter_act", [kind, at])
	_spent = kind
	_kind = &""
