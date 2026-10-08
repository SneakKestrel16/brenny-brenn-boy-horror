class_name PauseMenu
extends CanvasLayer
## P2-10 pause menu (doc 05 section 16), in the lobby and the match. It does not pause the game (it is
## a network session); it frees the mouse, tells Player and HoldController to ignore game keys
## (`Game.console_open`) and offers Resume, Settings, Start match (host, lobby only), Leave and Quit.
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
	multiplayer.server_disconnected.connect(_on_host_left)
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
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	if _host_left:
		_label("The host left the farm.")
		_button("Back to menu", Game.leave_session)
		return
	_label("Paused" if not Game.in_lobby else "The barn")
	_button("Resume", set_open.bind(false))
	if Game.in_lobby and Game.is_host():
		_button("Start match", Game.start_match)
	_button("Settings", _open_settings)
	_button("Leave to menu", Game.leave_session)
	_button("Quit game", func() -> void: get_tree().quit())


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
