class_name UiText
extends RefCounted
## P5-44: the one place screen messages get their width. A label with no autowrap is as wide as its text, so a long
## line (a ghost banner, a host's dev message, a toast) ran past the screen edge. `fit` turns wrapping on, caps the
## width at `max_w`, and keeps it inside `MARGIN` of the viewport edges, re-clamping when the window resizes.
## The caller sets the vertical anchors and offsets; `fit` owns the horizontal ones.

const MARGIN := 24.0  ## safe margin from every screen edge (px)


## side: -1 left edge, 0 centred, 1 right edge. Call after the label is in the tree.
static func fit(l: Control, max_w: float, side := 0) -> void:
	if l is Label:
		(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.grow_horizontal = Control.GROW_DIRECTION_END
	var apply := func() -> void:
		if not l.is_inside_tree():
			return
		var w := clampf(minf(max_w, l.get_viewport_rect().size.x - 2.0 * MARGIN), 1.0, max_w)
		l.anchor_left = [0.0, 0.5, 1.0][side + 1]
		l.anchor_right = l.anchor_left
		l.offset_left = [MARGIN, -w / 2.0, -MARGIN - w][side + 1]
		l.offset_right = l.offset_left + w
	# Connected only while in the tree: a viewport lambda holding a freed label errors on the next resize.
	var hook := func() -> void:
		apply.call()
		l.get_viewport().size_changed.connect(apply)
	l.tree_entered.connect(hook)
	l.tree_exiting.connect(func() -> void: l.get_viewport().size_changed.disconnect(apply))
	if l.is_inside_tree():
		hook.call()


## Width for one of `n` side-by-side blocks (the hotbar), at most `max_w`, so the row fits the safe area.
static func slot_width(n: int, max_w: float, gap: float, viewport_w: float) -> float:
	return clampf((viewport_w - 2.0 * MARGIN) / maxf(n, 1) - gap, 60.0, max_w)
