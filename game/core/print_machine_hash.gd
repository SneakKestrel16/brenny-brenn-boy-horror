extends SceneTree
## Prints this machine's gate hash (DevGate, D-044) and quits. Only the hash is printed, never the raw id.
##   "$GODOT" --headless --path . -s res://game/core/print_machine_hash.gd 2>/dev/null | tail -1


func _initialize() -> void:
	print(DevGate.machine_hash())
	quit()
