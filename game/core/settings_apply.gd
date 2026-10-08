class_name SettingsApply
extends Node
## Doc 05 section 16: pushes `Settings` to the engine at boot and on every change: keybinds into the
## InputMap, the six volume sliders onto their buses, window and graphics options, brightness and
## gamma (a screen pass above everything, including menus), mic device. Lives on the root so it
## survives scene changes. Display and graphics keys apply only once the player has set them
## (`Settings.is_set`), so launch flags and the QA window tiling keep working.
## Debug arg: `--ui-shot=<png>` saves the window after 90 frames and quits (menu screenshots).

const BUSES := {"vol_master": "Master", "vol_music": "Music", "vol_sfx": "SFX", "vol_ambience": "Ambience",
		"vol_voice": "Voice", "vol_ui": "UI"}
const SHADOW_ATLAS := [1024, 2048, 4096]  ## shadow_quality 0..2 (doc 07 s10.1: shadows are the first thing to cut)
## Actions whose default keys deliberately share a key: the ghost spectate keys reuse interact and whistle.
const SHARED := {"spectate_next": "interact", "spectate_prev": "whistle", "interact": "spectate_next", "whistle": "spectate_prev"}

static var defaults: Dictionary = {}  ## action -> Array[InputEvent], captured before any rebind

var _tone: ColorRect
var _shot := ""
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ui-shot="):
			_shot = a.trim_prefix("--ui-shot=")
	for action in game_actions():
		defaults[action] = InputMap.action_get_events(action).duplicate()
	var layer := CanvasLayer.new()
	layer.layer = 127
	_tone = ColorRect.new()
	_tone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform sampler2D tex : hint_screen_texture, filter_nearest;\n" \
			+ "uniform float brightness = 1.0;\nuniform float gamma = 1.0;\n" \
			+ "void fragment() { vec3 c = textureLod(tex, SCREEN_UV, 0.0).rgb; COLOR = vec4(pow(c * brightness, vec3(1.0 / gamma)), 1.0); }\n"
	m.shader = sh
	_tone.material = m
	layer.add_child(_tone)
	add_child(layer)
	Settings.changed.connect(_on_changed)
	apply_binds()
	for k in BUSES:
		_volume(k)
	_graphics()
	_display()
	_mic()
	_tone_pass()


func _process(_d: float) -> void:
	if _shot != "":
		_frames += 1
		if _frames == 90:
			get_viewport().get_texture().get_image().save_png(_shot)
			get_tree().quit()


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
	if d.get("t") == "k":
		var k := InputEventKey.new()
		k.physical_keycode = int(d.c) as Key
		return k
	if d.get("t") == "m":
		var m := InputEventMouseButton.new()
		m.button_index = int(d.b) as MouseButton
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
			for d in saved[String(action)]:
				var ev := dict_to_event(d)
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
	elif k in ["brightness", "gamma"]:
		_tone_pass()


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


func _mic() -> void:
	if not Settings.is_set(&"mic_device") or DisplayServer.get_name() == "headless":
		return
	var dev := str(Settings.get_value(&"mic_device"))
	if dev in AudioServer.get_input_device_list():
		AudioServer.input_device = dev


func _tone_pass() -> void:
	var b := float(Settings.get_value(&"brightness"))
	var g := float(Settings.get_value(&"gamma"))
	_tone.visible = not (is_equal_approx(b, 1.0) and is_equal_approx(g, 1.0))
	(_tone.material as ShaderMaterial).set_shader_parameter(&"brightness", b)
	(_tone.material as ShaderMaterial).set_shader_parameter(&"gamma", g)
