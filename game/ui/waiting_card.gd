class_name WaitingCard
extends CanvasLayer
## P4-10 (doc 06 s5, doc 05 s17): a season that started with 2 or more players never plays on with one. If the
## dawn finds only the host left, the clock stops at the dawn (the save is already written) and this card asks
## for a farmhand. It lifts when a second human joins; the clock then runs on. Host only, local: no peer is
## connected while it shows, so it needs no RPC. The last dawn ends the season instead of waiting.

var _root: Control
var waiting := false


func _ready() -> void:
	layer = 105  # under the Dawn Report (110) and the pause menu (120)
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0, 0, 0, 0.7)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	var l := Label.new()
	l.text = "Waiting for a farmhand"
	l.add_theme_font_size_override(&"font_size", 32)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(l)
	if Game.is_host():
		Clock.phase_changed.connect(func(ph: StringName) -> void:
			if ph == &"dawn":
				_check.call_deferred())
		Game.player_joined.connect(func(_p: int) -> void: _check())


## Wait at a dawn with fewer than 2 humans after a 2+ player start; go on once a second human is back.
func _check() -> void:
	if not Game.is_host() or Clock.season_over:
		return
	var alone := Game.match_roster.size() >= 2 and Game.humans() < 2
	if alone and not waiting and Clock.phase == &"dawn" and Clock.day < int(Data.value(&"season", &"season_days")):
		waiting = true
		Clock.stop()
		_root.visible = true
		Log.event(&"waiting_for_farmhand", {"day": Clock.day, "humans": Game.humans()})
	elif waiting and not alone:
		waiting = false
		Clock.running = true
		_root.visible = false
		Log.event(&"farmhand_returned", {"day": Clock.day, "humans": Game.humans()})
