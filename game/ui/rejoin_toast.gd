class_name RejoinToast
extends CanvasLayer
## D-049: the one mocking line a rejoiner sees on coming back. Lives on the root so a scene change
## does not remove it; fades after a few seconds. Shown only to the rejoiner.

const SHOW_S := 7.0  ## placeholder


static func show_line(text: String, tree: SceneTree) -> void:
	if text.is_empty():
		return
	var t := RejoinToast.new()
	t.layer = 110
	var l := Label.new()
	l.text = text
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = 80
	l.add_theme_font_size_override(&"font_size", 26)
	l.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	l.add_theme_constant_override(&"shadow_offset_x", 2)
	l.add_theme_constant_override(&"shadow_offset_y", 2)
	t.add_child(l)
	tree.root.add_child(t)
	Log.event(&"rejoin_line", {"line": text})
	var tw := t.create_tween()
	tw.tween_interval(SHOW_S)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(t.queue_free)
