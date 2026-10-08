extends Node
## Doc 05 section 16: local settings, this machine's disk only (never in the host save, never
## sent). Defaults are placeholders. Volumes are linear 0..1; Soundscape reads them later.

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
}

signal changed(key: StringName)

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(PATH)  # a missing file is fine: defaults


func get_value(key: StringName) -> Variant:
	return _cfg.get_value("settings", String(key), DEFAULTS.get(String(key)))


func set_value(key: StringName, v: Variant) -> void:
	if not DEFAULTS.has(String(key)):
		push_error("Settings: unknown key '%s'" % key)
		return
	_cfg.set_value("settings", String(key), v)
	changed.emit(key)


func save() -> Error:
	return _cfg.save(PATH)
