extends Node3D
## Boot: reads the user arguments (after `--`) and starts or joins a session; Game then switches
## to main.tscn. Arguments (doc 05 section 3): --host, --join=<ip[:port]>, --port=<n>, --phase1 and
## --data-dir (read by Data), --seed=<n>, --bots=<n>, --debug-view. No arguments hosts a solo
## session until the main menu (game/ui/) exists.


func _ready() -> void:
	Game.begin(Game.parse_args(OS.get_cmdline_user_args()))
