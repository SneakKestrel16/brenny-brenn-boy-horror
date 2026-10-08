extends Node
## Doc 05 section 16: local settings, this machine's disk only (never in the host save, never
## sent). Defaults are placeholders. Volumes are linear 0..1. `SettingsApply` (a child of the root,
## made here) pushes them to the engine at boot and on every change.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"mouse_sensitivity": 0.0025,  ## radians per pixel, placeholder
	"fov": 75.0,  ## degrees, placeholder
	"toggle_crouch": false,
	"reduce_scares": false,
	"push_to_talk": false,  ## doc 01 "Mic mode": open mic by default; Voice reads it (Q-042, D-027)
	"vol_master": 1.0, "vol_music": 1.0, "vol_sfx": 1.0, "vol_ambience": 1.0, "vol_voice": 1.0,
	"vol_ui": 1.0,
	"voice_gain_db": 6.0,  ## remote voices, plain gain (no AGC, doc 06); placeholder, playtest 1
	"player_name": "Farmer",
	## Doc 06 s11 "Setting IDs": `unchosen`, `off` or `lobby_lines`. Unchosen goes on the wire as `off`.
	"voice_setting": "unchosen",
	"lines_recorded": false,  ## P2-03 sets it once at least one line is kept
	"keybinds": {},  ## action -> [{"t": "k", "c": physical keycode} | {"t": "m", "b": button}]; empty = project defaults
	"mic_device": "Default",
	"quality_preset": "high",  ## low | medium | high | custom
	"render_scale": 1.0,
	"shadow_quality": 2,  ## 0 low, 1 medium, 2 high: shadow atlas size
	"vsync": true,
	"fps_cap": 0,  ## 0 = unlimited
	"window_mode": 0,  ## 0 windowed, 1 borderless, 2 fullscreen
	"resolution": "1280x720",
	"monitor": 0,
	"brightness": 0.25,  ## ambient floor 0.2..0.4, doc 07 s5; default is the 0.25 night floor
}

signal changed(key: StringName)

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(PATH)  # a missing file is fine: defaults
	var apply: Node = SettingsApply.new()
	apply.name = "SettingsApply"
	get_tree().root.add_child.call_deferred(apply)


func get_value(key: StringName) -> Variant:
	return _cfg.get_value("settings", String(key), DEFAULTS.get(String(key)))


## True when the player (not the default) chose this value. Display keys apply only then, so launch
## flags and the QA window tiling are never overridden by a default.
func is_set(key: StringName) -> bool:
	return _cfg.has_section_key("settings", String(key))


func set_value(key: StringName, v: Variant) -> void:
	if not DEFAULTS.has(String(key)):
		push_error("Settings: unknown key '%s'" % key)
		return
	_cfg.set_value("settings", String(key), v)
	changed.emit(key)


func save() -> Error:
	return _cfg.save(PATH)
