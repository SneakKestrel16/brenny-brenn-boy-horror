extends SceneTree
## P5-32 contact sheet: tile <dir>/<name>_day.png for each name into one PNG.
##   godot --headless --path . --script tools/blender/montage.gd -- --dir=logs/renders/p5_32/after --out=sheet.png --cols=6 a b c
func _initialize() -> void:
	var dir := ""
	var out := "sheet.png"
	var cols := 6
	var names: PackedStringArray = []
	var suffix := "_day"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.trim_prefix("--dir=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--cols="):
			cols = int(a.trim_prefix("--cols="))
		elif a.begins_with("--suffix="):
			suffix = a.trim_prefix("--suffix=")
		else:
			names.append(a)
	var tile := Vector2i(320, 240)
	var rows := ceili(float(names.size()) / cols)
	var sheet := Image.create(tile.x * cols, tile.y * rows, false, Image.FORMAT_RGBA8)
	for i in names.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://%s/%s%s.png" % [dir, names[i], suffix]))
		if img == null:
			continue
		img.resize(tile.x, tile.y)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, tile), Vector2i((i % cols) * tile.x, (i / cols) * tile.y))
	sheet.save_png(ProjectSettings.globalize_path("res://" + out))
	quit()
