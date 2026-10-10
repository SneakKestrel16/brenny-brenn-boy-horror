extends Node
## P5-46 QA: the settings menu's mouse sensitivity slider (a multiple of the default, 0.1x to 3.0x) changes the
## Settings value live, changes how far Player.look turns the view, shows a readable value, saves to user://
## and loads back into a fresh menu. Scene run (autoloads needed):
##   "$GODOT" --headless --audio-driver Dummy --path . res://tests/ui/test_mouse_sens.tscn
## Writes user://settings.cfg through Settings.save() and deletes it again if it did not exist before.

var _fails := 0


func _ready() -> void:
	await get_tree().process_frame
	var had := FileAccess.file_exists(Settings.PATH)
	var base := float(Settings.DEFAULTS["mouse_sensitivity"])
	Settings.set_value(&"mouse_sensitivity", base)
	Settings.set_value(&"invert_y", false)
	var player: CharacterBody3D = load("res://game/player/player.gd").new()  # not in the tree: only `look` runs
	var menu := SettingsMenu.new()
	add_child(menu)
	var s: HSlider = menu._sens
	_check(s != null and is_equal_approx(s.min_value, 0.1) and is_equal_approx(s.max_value, 3.0), "slider range is 0.1x to 3.0x")
	_check(is_equal_approx(s.value, 1.0), "default shows as 1.0x, got %s" % s.value)
	var shown: Label = s.get_parent().get_child(s.get_index() + 1)
	_check(shown.text == "1.00x", "readable value, got '%s'" % shown.text)
	player.look(Vector2(100, 0))
	var yaw_default: float = player.yaw
	_check(is_equal_approx(yaw_default, -100.0 * base), "default look speed %s" % yaw_default)

	s.value = 2.0
	_check(is_equal_approx(float(Settings.get_value(&"mouse_sensitivity")), 2.0 * base), "slider drives the setting")
	_check(shown.text == "2.00x", "value text follows, got '%s'" % shown.text)
	player.yaw = 0.0
	player.look(Vector2(100, 0))
	_check(is_equal_approx(player.yaw, 2.0 * yaw_default), "2x turns twice as far, got %s vs %s" % [player.yaw, yaw_default])
	s.value = 0.1
	player.yaw = 0.0
	player.look(Vector2(100, 0))
	_check(is_equal_approx(player.yaw, 0.1 * yaw_default), "0.1x turns a tenth as far")

	s.value = 2.5
	var cfg := ConfigFile.new()
	_check(cfg.load(Settings.PATH) == OK, "settings file written on change")
	_check(is_equal_approx(float(cfg.get_value("settings", "mouse_sensitivity", -1.0)), 2.5 * base), "saved value on disk")
	menu.queue_free()
	await get_tree().process_frame
	var menu2 := SettingsMenu.new()  # a new menu reads the stored setting back
	add_child(menu2)
	_check(is_equal_approx(menu2._sens.value, 2.5), "reopened menu shows 2.5x, got %s" % menu2._sens.value)

	player.free()
	if not had:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	print("MOUSE_SENS ", "PASS" if _fails == 0 else "FAIL")
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
