extends Node
## Loads every GDScript under res:// so parse errors surface as SCRIPT ERROR lines.
## The headless import only parses scripts it needs (class_name, autoloads, scenes), so a broken
## script nothing references yet would otherwise pass the smoke run. Folders with a .gdignore
## and dot-folders are skipped. Loading a script does not run it.
## Runs as a scene, not a -s script: autoloads are not registered in -s mode (Q-040).

var _checked: int = 0
var _failed: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_walk("res://")
	print("QA_PARSE_CHECK checked=%d failed=%d" % [_checked, _failed.size()])
	for path: String in _failed:
		print("QA_PARSE_FAIL " + path)
	get_tree().quit(1 if _failed.size() > 0 else 0)


func _walk(dir_path: String) -> void:
	if FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() != "gd":
			continue
		var path: String = dir_path.path_join(file_name)
		if path == (get_script() as Script).resource_path:
			continue  # Reloading the running script crashes Godot; it parsed to get here.
		_checked += 1
		var script: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
		# A script with a parse error still loads, but cannot be instantiated.
		if script == null or not (script.can_instantiate() or script.is_abstract()):
			_failed.append(path)
	for sub: String in DirAccess.get_directories_at(dir_path):
		if sub.begins_with("."):
			continue
		_walk(dir_path.path_join(sub))
