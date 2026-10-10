class_name PauseMenu
extends CanvasLayer
## P2-10 pause menu (doc 05 section 16), in the lobby and the match. It does not pause the game (it is
## a network session); it frees the mouse, tells Player and HoldController to ignore game keys
## (`Game.console_open`) and offers Resume, Settings, Leave and Quit (the lobby screen has Start, P4-23),
## plus this player's live clips with Play and Delete (P4-37).
## It also shows the host-left card. Debug user arg: --pause-open.

var _panel: Control
var _box: VBoxContainer
var _open := false
var _settings: SettingsMenu
var _host_left := false


func _ready() -> void:
	layer = 120
	_panel = Control.new()  # dim backdrop plus a centred column
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size.x = 260
	center.add_child(_box)
	Net.host_left.connect(func(_how: StringName) -> void: _on_host_left())  # P4-10: clean quit or timeout, once
	if OS.get_cmdline_user_args().has("--pause-open"):
		set_open.call_deferred(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not _host_left and _settings == null:
		set_open(not _open)
		get_viewport().set_input_as_handled()


func set_open(on: bool) -> void:
	_open = on
	_panel.visible = on
	Game.console_open = on
	if on:
		_rebuild()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not Game.in_lobby:  # the lobby is a menu screen (P4-23)
		Game.capture_mouse()


func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	if _host_left:
		_label("The host left.\nThe season continues from the last dawn save.\nAny farmhand from this season can host it.")
		_button("Back to menu", Game.leave_session)
		return
	_label("Paused" if not Game.in_lobby else "The lobby")
	_button("Resume", set_open.bind(false))
	_roster_volumes()
	_box.add_child(CosmeticsPanel.new())  # P5-05: wear what you own (lobby and match)
	_own_clips()
	_join_code()
	_button("Settings", _open_settings)
	_button("Leave to menu", Game.leave_session)
	_button("Quit game", Game.quit)


## D-049: the host's join code with a Copy button, for a dropped player who cannot use the rejoin prompt.
func _join_code() -> void:
	var code := Net.join_code()
	if code == "":
		return
	_label("Join code: %s" % code)
	_button("Copy join code", func() -> void: DisplayServer.clipboard_set(code))


## Doc 06 s11 (D-146): this session's live clips of this player, each with Play and Delete.
func _own_clips() -> void:
	var own: Array = Voice.clips.own_clips()
	if own.is_empty():
		return
	_label("Your live clips (this session only)")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = mini(own.size(), 5) * 34
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in own.size():
		var c: Dictionary = own[i]
		var h := HBoxContainer.new()
		var n := Label.new()
		n.text = "Clip %d (%.1f s)" % [i + 1, c.frames * VoiceClips.FRAME_S]
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var play := Button.new()
		play.text = "Play"
		play.pressed.connect(func() -> void: Voice.clips.play(Game.local_peer(), c.clip_id))
		h.add_child(play)
		var del := Button.new()
		del.text = "Delete"
		del.pressed.connect(func() -> void:
			Voice.clips.delete_own(c.clip_id)
			_rebuild.call_deferred())
		h.add_child(del)
		list.add_child(h)
	_box.add_child(scroll)


## D-047: one volume slider per other player; 0 is mute. Applies to their live voice and to the creature's replays of their clips.
func _roster_volumes() -> void:
	for p in Game.players:
		if p <= 0 or p == Game.local_peer():
			continue
		var h := HBoxContainer.new()
		var n := Label.new()
		n.text = str(Net.profiles.get(p, {}).get("name", "Farmhand"))
		n.custom_minimum_size.x = 110
		h.add_child(n)
		var s := HSlider.new()
		s.max_value = 1.0
		s.step = 0.05
		s.value = Settings.peer_volume(p)
		s.custom_minimum_size.x = 110
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(s)
		var m := CheckBox.new()
		m.text = "Mute"
		m.button_pressed = s.value <= 0.0
		h.add_child(m)
		s.value_changed.connect(func(v: float) -> void:
			Settings.set_peer_volume(p, v)
			Settings.save()
			m.set_pressed_no_signal(v <= 0.0))
		m.toggled.connect(func(on: bool) -> void: s.value = 0.0 if on else 1.0)
		_box.add_child(h)


func _label(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)


func _button(t: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	_box.add_child(b)


func _open_settings() -> void:
	_panel.visible = false
	_settings = SettingsMenu.new()
	_settings.closed.connect(func() -> void:
		_settings = null
		_panel.visible = _open)
	add_child(_settings)


func _on_host_left() -> void:
	_host_left = true
	if _settings:
		_settings.queue_free()
		_settings = null
	set_open(true)
	_panel.visible = true
