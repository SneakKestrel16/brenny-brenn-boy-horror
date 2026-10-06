extends SceneTree
## Prints the project's real user:// folder for tools/qa (multi.py collects logs from it).


func _init() -> void:
	print("QA_USER_DATA_DIR=" + OS.get_user_data_dir())
	quit()
