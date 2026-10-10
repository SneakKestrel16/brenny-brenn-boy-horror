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
	"voice_setting": "live_clips",  ## doc 06 s11 "Setting IDs" (D-146): `off` or `live_clips`
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
	## D-047 comfort and convenience (doc 01), per player on this PC. Not sent anywhere.
	"camera_shake": 1.0,  ## 0..1 head bob and shake; 0 also keeps the knockdown camera level
	"centre_dot": false,
	"voice_peer_volume": {},  ## player key (profile uid, else peer id) -> 0..1; 0 mutes live voice and the creature's replays of them
	"toggle_holds": false,  ## press once to start a hold, again to stop; hold times unchanged
	"toggle_sprint": false,
	"invert_y": false,
	"ui_text_scale": 1.0,  ## 0.8..1.5 menu text
}

signal changed(key: StringName)

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(PATH)  # a missing file is fine: defaults
	# D-146: the P2-03 settings `unchosen` and `lobby_lines` become the default, Live clips; Off stays Off.
	if _cfg.has_section_key("settings", "voice_setting") and not str(_cfg.get_value("settings", "voice_setting")) in ["off", "live_clips"]:
		_cfg.erase_section_key("settings", "voice_setting")
	if _cfg.has_section_key("settings", "lines_recorded"):
		_cfg.erase_section_key("settings", "lines_recorded")
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


## D-047: the key a peer's volume is stored under: its profile uid (stable between sessions), else the peer id.
func peer_key(peer: int) -> String:
	return str(Net.profiles.get(peer, {}).get("uid", peer))


func peer_volume(peer: int) -> float:
	return clampf(float(get_value(&"voice_peer_volume").get(peer_key(peer), 1.0)), 0.0, 1.0)


func set_peer_volume(peer: int, v: float) -> void:
	var d: Dictionary = get_value(&"voice_peer_volume").duplicate()
	d[peer_key(peer)] = clampf(v, 0.0, 1.0)
	set_value(&"voice_peer_volume", d)


func save() -> Error:
	return _cfg.save(PATH)
