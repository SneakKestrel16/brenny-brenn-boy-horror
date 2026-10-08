class_name SettingsApply
extends Node
## Doc 05 section 16: pushes `Settings` to the engine at boot and on every change: keybinds into the
## InputMap, the six volume sliders onto their buses, window and graphics options, the brightness
## slider (the night ambient floor, 0.2 to 0.4; it touches no light, doc 07 s5), mic device. Lives on the root so it
## survives scene changes. Display and graphics keys apply only once the player has set them
## (`Settings.is_set`), so launch flags and the QA window tiling keep working.
## Debug arg: `--ui-shot=<png>` saves the window after 90 frames (or `--ui-shot-s=<seconds>`) and quits
## (menu screenshots).

const BUSES := {"vol_master": "Master", "vol_music": "Music", "vol_sfx": "SFX", "vol_ambience": "Ambience",
		"vol_voice": "Voice", "vol_ui": "UI"}
const SHADOW_ATLAS := [1024, 2048, 4096]  ## shadow_quality 0..2 (doc 07 s10.1: shadows are the first thing to cut)
## Actions whose default keys deliberately share a key: the ghost spectate keys reuse interact and whistle.
const SHARED := {"spectate_next": "interact", "spectate_prev": "whistle", "interact": "spectate_next", "whistle": "spectate_prev"}

static var defaults: Dictionary = {}  ## action -> Array[InputEvent], captured before any rebind

var _env: WorldEnvironment
var _theme: Theme
var _shot := ""
var _frames := 0
var _shot_s := 0.0


func _ready() -> void:
	process_priority = 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ui-shot="):
			_shot = a.trim_prefix("--ui-shot=")
		elif a.begins_with("--ui-shot-s="):
			_shot_s = a.trim_prefix("--ui-shot-s=").to_float()
	for action in game_actions():
		defaults[action] = InputMap.action_get_events(action).duplicate()
	Settings.changed.connect(_on_changed)
	apply_binds()
	for k in BUSES:
		_volume(k)
	_graphics()
	_display()
	_mic()
	_text_scale()


func _process(_d: float) -> void:
	_ambient_floor()
	if _shot != "":
		_frames += 1
		if (_shot_s <= 0.0 and _frames == 90) or (_shot_s > 0.0 and Time.get_ticks_msec() >= _shot_s * 1000.0):
			get_viewport().get_texture().get_image().save_png(_shot)
			_shot = ""
			get_tree().quit()


## Raises the ambient to the player's floor after WorldLook set the phase value (process_priority makes
## this run last). Never lowers it, touches no light (doc 07 s5).
func _ambient_floor() -> void:
	if not Settings.is_set(&"brightness"):
		return
	if not is_instance_valid(_env):
		_env = null
		for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			_env = n
	if _env and _env.environment:
		var env := _env.environment
		env.ambient_light_energy = maxf(env.ambient_light_energy, clampf(float(Settings.get_value(&"brightness")), 0.2, 0.4))


## Every InputMap action the game defines (Godot's own `ui_*` are not game actions).
static func game_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for a in InputMap.get_actions():
		if not String(a).begins_with("ui_"):
			out.append(a)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"t": "k", "c": (ev as InputEventKey).physical_keycode}
	if ev is InputEventMouseButton:
		return {"t": "m", "b": (ev as InputEventMouseButton).button_index}
	return {}


static func dict_to_event(d: Dictionary) -> InputEvent:
	if d.get("t") == "k" and int(d.get("c", 0)) != 0:
		var k := InputEventKey.new()
		k.physical_keycode = int(d.get("c", 0)) as Key
		return k
	if d.get("t") == "m" and int(d.get("b", 0)) != 0:
		var m := InputEventMouseButton.new()
		m.button_index = int(d.get("b", 0)) as MouseButton
		return m
	return null


static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	if ev is InputEventMouseButton:
		return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return "?"


## Other actions already using `ev`, minus the shared ghost pairs.
static func conflicts(action: StringName, ev: InputEvent) -> Array[StringName]:
	var out: Array[StringName] = []
	var d := event_to_dict(ev)
	for other in game_actions():
		if other == action or SHARED.get(action, "") == String(other):
			continue
		for e in InputMap.action_get_events(other):
			if event_to_dict(e) == d:
				out.append(other)
	return out


## Saved binds over the project defaults. Called at boot and after a rebind or reset.
func apply_binds() -> void:
	var saved: Dictionary = Settings.get_value(&"keybinds")
	for action in game_actions():
		if saved.has(String(action)):
			InputMap.action_erase_events(action)
			for d in saved[String(action)] if saved[String(action)] is Array else []:
				var ev := dict_to_event(d) if d is Dictionary else null
				if ev:
					InputMap.action_add_event(action, ev)
		elif defaults.has(action):
			InputMap.action_erase_events(action)
			for ev in defaults[action]:
				InputMap.action_add_event(action, ev)


func _on_changed(key: StringName) -> void:
	var k := String(key)
	if k == "keybinds":
		apply_binds()
	elif BUSES.has(k):
		_volume(k)
	elif k in ["render_scale", "shadow_quality", "vsync", "fps_cap"]:
		_graphics()
	elif k in ["window_mode", "resolution", "monitor"]:
		_display()
	elif k == "mic_device":
		_mic()
	elif k == "ui_text_scale":
		_text_scale()

func _volume(key: String) -> void:
	var idx := AudioServer.get_bus_index(BUSES[key])
	if idx < 0:
		return
	var v := float(Settings.get_value(StringName(key)))
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func _graphics() -> void:
	if Settings.is_set(&"render_scale"):
		get_tree().root.scaling_3d_scale = clampf(float(Settings.get_value(&"render_scale")), 0.5, 1.0)
	if Settings.is_set(&"shadow_quality"):
		var size: int = SHADOW_ATLAS[clampi(int(Settings.get_value(&"shadow_quality")), 0, 2)]
		RenderingServer.directional_shadow_atlas_set_size(size, true)
		get_tree().root.positional_shadow_atlas_size = size
	if Settings.is_set(&"vsync") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.get_value(&"vsync") else DisplayServer.VSYNC_DISABLED)
	if Settings.is_set(&"fps_cap"):
		Engine.max_fps = int(Settings.get_value(&"fps_cap"))


func _display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not (Settings.is_set(&"window_mode") or Settings.is_set(&"resolution") or Settings.is_set(&"monitor")):
		return
	var screen := clampi(int(Settings.get_value(&"monitor")), 0, DisplayServer.get_screen_count() - 1)
	var mode := int(Settings.get_value(&"window_mode"))
	var res: PackedStringArray = str(Settings.get_value(&"resolution")).split("x")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == 1)
	DisplayServer.window_set_current_screen(screen)
	if mode == 1:
		DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
	elif mode == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif res.size() == 2:
		var size := Vector2i(int(res[0]), int(res[1]))
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen) + (DisplayServer.screen_get_size(screen) - size) / 2)


## D-047 menu text size: a root-window theme with a scaled default font size (controls read the nearest theme, so
## `ThemeDB.fallback_font_size` alone changes nothing; QA P2-15). Menus use it; the HUD and titles set their own sizes.
func _text_scale() -> void:
	if _theme == null:
		_theme = Theme.new()
		get_tree().root.theme = _theme
	_theme.default_font_size = roundi(16.0 * clampf(float(Settings.get_value(&"ui_text_scale")), 0.8, 1.5))


func _mic() -> void:
	if not Settings.is_set(&"mic_device") or DisplayServer.get_name() == "headless":
		return
	var dev := str(Settings.get_value(&"mic_device"))
	if dev in AudioServer.get_input_device_list():
		AudioServer.input_device = dev
