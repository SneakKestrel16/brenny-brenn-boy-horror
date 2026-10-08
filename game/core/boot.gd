extends Node3D
## Boot: reads the user arguments (after `--`) and starts or joins a session; Game then switches
## to main.tscn. Arguments (doc 05 section 3): --host, --join=<ip[:port]>, --port=<n>, --phase1 and
## --data-dir (read by Data), --seed=<n>, --bots=<n>, --debug-view, --lobby, --lobby-start=<n>, --menu.
## A bare launch (no arguments, a window) shows the main menu (P2-10); any argument keeps the legacy
## path so the QA scripts and playtest .bat files run unchanged. Headless never shows the menu
## unless `--menu` is given.


func _ready() -> void:
	var raw := OS.get_cmdline_user_args()
	var args := Game.parse_args(raw)
	if raw.has("--menu") or (raw.is_empty() and DisplayServer.get_name() != "headless"):
		get_tree().change_scene_to_file.call_deferred(Game.MENU_SCENE)
		return
	Game.begin(args)
