class_name SettingsMenu
extends Control
## Doc 05 section 16: the settings screen, shared by the main menu and the pause menu. Five tabs:
## Keybinds, Audio, Graphics, Display, Comfort. Every change goes through `Settings.set_value` plus
## `Settings.save()` (local disk, never sent); `SettingsApply` pushes it to the engine.
## Voice copy follows doc 06 section 11 (D-146): Off or Live clips, and what Live clips keeps.

signal closed

const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
const FPS_CAPS := [0, 30, 60, 90, 120, 144, 240]
const PRESETS := {"low": [0.67, 0], "medium": [0.85, 1], "high": [1.0, 2]}  ## render_scale, shadow_quality (placeholders)
const VOLUMES := {"vol_master": "Master", "vol_music": "Music", "vol_sfx": "Effects", "vol_ambience": "Ambience",
		"vol_voice": "Voices", "vol_ui": "Interface"}
const VOICE_COPY := {  ## doc 06 s11 (D-146)
	"off": "Nothing is kept; the creature fakes only your footsteps and tools.",
	"live_clips": "Short clips (3 s at most) of what you say in a match are kept for this session only. The creature" \
			+ " and the Dawn Report can replay them. The recording light shows while any are kept; review or delete" \
			+ " them from the pause menu.",
}
const DISCORD_LINE := "The creature can't hear Discord, and you can't hear where your friends are."

var tabs: TabContainer
var _bind_buttons: Dictionary = {}  ## action -> Button
var _capturing: StringName = &""
var _warn: Label
var _voice_note: Label
var _preset: OptionButton
var _scale: HSlider
var _shadow: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.98)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 80
	box.offset_right = -80
	box.offset_top = 40
	box.offset_bottom = -40
	add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override(&"font_size", 28)
	box.add_child(title)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_keybinds_tab()
	_audio_tab()
	_graphics_tab()
	_display_tab()
	_comfort_tab()
	var close := Button.new()
	close.text = "Back"
	close.pressed.connect(_close)
	box.add_child(close)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--settings-tab="):
			tabs.current_tab = int(a.trim_prefix("--settings-tab="))


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _capturing == &"":
		return
	var ev: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_stop_capture()
			get_viewport().set_input_as_handled()
			return
		ev = event
	elif event is InputEventMouseButton and event.pressed and event.button_index <= MOUSE_BUTTON_XBUTTON2 			and not event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		ev = event
	if ev == null:
		return
	get_viewport().set_input_as_handled()
	var action := _capturing
	var clash := SettingsApply.conflicts(action, ev)
	_warn.text = "%s is also bound to: %s." % [SettingsApply.event_text(ev), ", ".join(clash.map(_nice))] if not clash.is_empty() else ""
	var saved: Dictionary = Settings.get_value(&"keybinds").duplicate()
	saved[String(action)] = [SettingsApply.event_to_dict(ev)]
	_stop_capture()
	_commit(&"keybinds", saved)
	_refresh_binds()


func _stop_capture() -> void:
	_capturing = &""
	_refresh_binds()


func _nice(action: StringName) -> String:
	return String(action).capitalize()


func _commit(key: StringName, v: Variant) -> void:
	Settings.set_value(key, v)
	Settings.save()


func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	tabs.add_child(sc)
	return v


func _row(page: Control, label: String, c: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 240
	h.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(c)
	if c is HSlider:  # value text beside every slider
		var v := Label.new()
		v.custom_minimum_size.x = 56
		v.text = _fmt(c.value, c.step)
		c.value_changed.connect(func(x: float) -> void: v.text = _fmt(x, c.step))
		h.add_child(v)
	page.add_child(h)


func _fmt(v: float, step: float) -> String:
	return "%d" % v if step >= 1.0 else ("%.2f" % v)


func _slider(key: StringName, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.value_changed.connect(func(v: float) -> void: _commit(key, v))
	return s


func _check(key: StringName, text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(on: bool) -> void: _commit(key, on))
	return c


func _options(items: Array, current: int, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	for i in items:
		o.add_item(str(i))
	o.selected = clampi(current, 0, maxi(items.size() - 1, 0))
	o.item_selected.connect(on_pick)
	return o


# --- Keybinds -----------------------------------------------------------------------------------

func _keybinds_tab() -> void:
	var p := _page("Keybinds")
	var hint := Label.new()
	hint.text = "Click a key, then press the new one. Esc cancels."
	p.add_child(hint)
	_warn = Label.new()
	_warn.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.3))
	p.add_child(_warn)
	var reset := Button.new()
	reset.text = "Reset all keys to defaults"
	reset.pressed.connect(func() -> void:
		_warn.text = ""
		_commit(&"keybinds", {})
		_refresh_binds())
	p.add_child(reset)
	p.move_child(reset, 1)
	for action in SettingsApply.game_actions():
		var b := Button.new()
		b.custom_minimum_size.x = 200
		b.pressed.connect(func() -> void:
			_capturing = action
			_warn.text = ""
			_refresh_binds())
		_bind_buttons[action] = b
		_row(p, _nice(action), b)
	_refresh_binds()


func _refresh_binds() -> void:
	for action in _bind_buttons:
		var b: Button = _bind_buttons[action]
		if action == _capturing:
			b.text = "Press a key..."
		else:
			b.text = " / ".join(InputMap.action_get_events(action).map(SettingsApply.event_text))


# --- Audio --------------------------------------------------------------------------------------

func _audio_tab() -> void:
	var p := _page("Audio")
	for k in VOLUMES:
		_row(p, VOLUMES[k] + " volume", _slider(StringName(k), 0.0, 1.0, 0.01))
	p.add_child(_check(&"push_to_talk", "Push to talk (off: open mic)"))
	var devices := AudioServer.get_input_device_list()
	if devices.size() > 1:
		_row(p, "Microphone", _options(devices, devices.find(str(Settings.get_value(&"mic_device"))),
				func(i: int) -> void: _commit(&"mic_device", devices[i])))
	p.add_child(HSeparator.new())
	var d := Label.new()
	d.text = DISCORD_LINE
	p.add_child(d)
	var ids := ["off", "live_clips"]
	var o := OptionButton.new()
	o.add_item("Off")
	o.add_item("Live clips")
	o.selected = ids.find(Game.wire_voice_setting())
	o.item_selected.connect(func(i: int) -> void:
		var s: String = ids[i]
		if s == "off" and Voice.clips.has_kept():  # doc 01 "Voice settings > Off" deletes the clips
			o.selected = 1
			var dlg := ConfirmationDialog.new()
			dlg.dialog_text = "This deletes your kept clips"
			dlg.ok_button_text = "Delete and turn Off"
			dlg.confirmed.connect(func() -> void:
				o.selected = i
				Game.set_voice_setting(s)
				_refresh_voice()
				dlg.queue_free())
			dlg.canceled.connect(dlg.queue_free)
			add_child(dlg)
			dlg.popup_centered()
			return
		Game.set_voice_setting(s)
		_refresh_voice())
	_row(p, "Voice setting", o)
	_voice_note = Label.new()
	_voice_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_voice_note)
	_refresh_voice()


func _refresh_voice() -> void:
	_voice_note.text = VOICE_COPY[Game.wire_voice_setting()]


# --- Graphics -----------------------------------------------------------------------------------

func _graphics_tab() -> void:
	var p := _page("Graphics")
	var names := PRESETS.keys() + ["custom"]
	_preset = _options(names, names.find(str(Settings.get_value(&"quality_preset"))), func(i: int) -> void:
		_commit(&"quality_preset", names[i])
		if PRESETS.has(names[i]):
			_commit(&"render_scale", PRESETS[names[i]][0])
			_commit(&"shadow_quality", PRESETS[names[i]][1])
			_scale.set_value_no_signal(PRESETS[names[i]][0])
			_shadow.selected = PRESETS[names[i]][1])
	_row(p, "Quality preset", _preset)
	_shadow = _options(["Low", "Medium", "High"], int(Settings.get_value(&"shadow_quality")), func(i: int) -> void:
		_commit(&"shadow_quality", i)
		_custom())
	_row(p, "Shadows", _shadow)
	_scale = _slider(&"render_scale", 0.5, 1.0, 0.05)
	_scale.value_changed.connect(func(_v: float) -> void: _custom())
	_row(p, "Render scale", _scale)
	p.add_child(_check(&"vsync", "VSync"))
	_row(p, "FPS cap", _options(FPS_CAPS.map(func(f: int) -> String: return "Unlimited" if f == 0 else str(f)),
			FPS_CAPS.find(int(Settings.get_value(&"fps_cap"))), func(i: int) -> void: _commit(&"fps_cap", FPS_CAPS[i])))
	# No fog or corn density knob: the corn budget and fog are fixed by doc 07 section 10 and every peer must look the same.


func _custom() -> void:
	_commit(&"quality_preset", "custom")
	_preset.selected = _preset.item_count - 1


# --- Comfort (D-047) -----------------------------------------------------------------------------

func _comfort_tab() -> void:
	var p := _page("Comfort")
	_row(p, "Camera shake and head bob", _slider(&"camera_shake", 0.0, 1.0, 0.05))
	p.add_child(_check(&"centre_dot", "Centre dot"))
	p.add_child(_check(&"toggle_holds", "Toggle holds (press to start a hold, press again to stop)"))
	p.add_child(_check(&"toggle_sprint", "Toggle sprint"))
	p.add_child(_check(&"invert_y", "Invert mouse Y"))
	_row(p, "Menu text size", _slider(&"ui_text_scale", 0.8, 1.5, 0.05))
	var note := Label.new()
	note.text = "Per-player voice volume and mute are in the pause menu."
	p.add_child(note)


# --- Display ------------------------------------------------------------------------------------

func _display_tab() -> void:
	var p := _page("Display")
	_row(p, "Window mode", _options(["Windowed", "Borderless", "Fullscreen"], int(Settings.get_value(&"window_mode")),
			func(i: int) -> void: _commit(&"window_mode", i)))
	_row(p, "Resolution (windowed)", _options(RESOLUTIONS, RESOLUTIONS.find(str(Settings.get_value(&"resolution"))),
			func(i: int) -> void: _commit(&"resolution", RESOLUTIONS[i])))
	var screens: Array = []
	for i in DisplayServer.get_screen_count():
		screens.append("Monitor %d" % (i + 1))
	_row(p, "Monitor", _options(screens, int(Settings.get_value(&"monitor")), func(i: int) -> void: _commit(&"monitor", i)))
	_row(p, "Field of view", _slider(&"fov", 60.0, 110.0, 1.0))
	_row(p, "Brightness (night ambient floor)", _slider(&"brightness", 0.2, 0.4, 0.01))
