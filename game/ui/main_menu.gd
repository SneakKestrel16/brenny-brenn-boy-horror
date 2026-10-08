extends Control
## P2-10 main menu (doc 05 section 16): Host, Join, Settings, Quit. Join takes a raw IP or IP:port
## (D-024: friends join over Tailscale; no join codes). Host and Join both land in the barn lobby.
## Debug user args: --menu-open=settings, --ui-shot=<png> (SettingsApply).

var _ip: LineEdit
var _port: LineEdit
var _status: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 380
	v.add_theme_constant_override(&"separation", 10)
	center.add_child(v)
	var title := Label.new()
	title.text = ProjectSettings.get_setting("application/config/name")
	title.add_theme_font_size_override(&"font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var ver := Label.new()
	ver.text = "build " + Game.build_id()
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.modulate = Color(1, 1, 1, 0.4)
	v.add_child(ver)
	_port = LineEdit.new()
	_port.text = str(Net.DEFAULT_PORT)
	_port.placeholder_text = "Port"
	_buttons.append(_button(v, "Host", _host))
	v.add_child(_port)
	_ip = LineEdit.new()
	_ip.placeholder_text = "Host's Tailscale IP (or IP:port)"
	_ip.text_submitted.connect(func(_t: String) -> void: _join())
	v.add_child(_ip)
	_buttons.append(_button(v, "Join", _join))
	_buttons.append(_button(v, "Settings", _open_settings))
	_buttons.append(_button(v, "Quit", func() -> void: get_tree().quit()))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	multiplayer.connection_failed.connect(_failed)
	for a in OS.get_cmdline_user_args():
		if a == "--menu-open=settings":
			_open_settings.call_deferred()


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## A bare exe has no `--phase1` flag, so the menu turns Phase 1 content on and reloads (the full farm
## and its data are P2-02; switch this off then).
func _data() -> bool:
	if not Data.phase1:
		Data.phase1 = true
		Data.load_dir("res://data", true)
	if not Data.ok:
		_status.text = "Game data failed to load. See the log."
	return Data.ok


func _host() -> void:
	if not _data():
		return
	var err := Game.start_host(int(_port.text) if _port.text.is_valid_int() else Net.DEFAULT_PORT, true)
	if err != OK:
		_status.text = "Could not open the port (%s). Is another copy running?" % error_string(err)


func _join() -> void:
	var addr := _ip.text.strip_edges()
	if addr == "" or not _data():
		_status.text = "Type the host's IP address first." if addr == "" else _status.text
		return
	var err := Net.join(addr, int(_port.text) if _port.text.is_valid_int() else Net.DEFAULT_PORT)
	if err != OK:
		_status.text = "Could not start connecting (%s)." % error_string(err)
		return
	_status.text = "Connecting to %s ..." % addr
	for b in _buttons:
		b.disabled = true
	get_tree().create_timer(Net.CONNECT_TIMEOUT_S + 1.0).timeout.connect(func() -> void:
		if is_inside_tree() and not Game.in_session:
			_failed())


func _failed() -> void:
	multiplayer.multiplayer_peer = null
	_status.text = "Could not reach the host. Check the IP, that the host is running, and Tailscale."
	for b in _buttons:
		b.disabled = false


func _open_settings() -> void:
	add_child(SettingsMenu.new())
