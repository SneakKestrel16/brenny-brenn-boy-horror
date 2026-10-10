extends Node
## P5-48 unit checks for Lore and data/lore.json (doc 11 s5, s6).
##   "$GODOT" --headless --path . res://tests/gameplay/test_lore.tscn  (a scene: the Data autoload must exist)
## Exits 0 on pass, 1 on any failure.

var _fails := 0


func _ready() -> void:
	# The archive runs in order across 21 dawns, then repeats (doc 11 s6.4).
	_check(Lore.archive_index(1, 1, 21) == 0, "season 1 day 1 is clipping 1")
	_check(Lore.archive_index(1, 7, 21) == 6, "season 1 day 7 is clipping 7")
	_check(Lore.archive_index(2, 1, 21) == 7, "season 2 day 1 is clipping 8")
	_check(Lore.archive_index(3, 7, 21) == 20, "season 3 day 7 is clipping 21")
	_check(Lore.archive_index(4, 1, 21) == 0, "season 4 day 1 wraps to clipping 1")

	var d: Node = Data  # autoload
	_check(d.errors.is_empty(), "data loads: %s" % [d.errors])
	var rec: Dictionary = Data.record(&"lore", &"archive")
	_check(rec.get("clippings", []).size() == 21, "21 clippings")
	_check(Data.record(&"lore", &"notes").get("notes", []).size() >= 10, "a note per verb")
	_check(Lore.win_lines().size() == 3, "3 win lines")
	_check(Lore.text(&"masthead") == "THE HALVERS CREEK COURIER", "masthead")
	_check(not Lore.text(&"intro").is_empty(), "intro line")

	# {tenants} is filled, and no token is left over.
	var last := Lore.clipping(3, 7, ["Ann", "Bo"])
	_check("Ann, Bo" in last.text and not "{" in last.text, "tenants filled: %s" % last.text)
	_check(not "{" in Lore.clipping(3, 7, []).text, "empty crew still reads")

	# Player-facing text never says Taint (P5-37), and carries no caption text (doc 11 s1).
	var all := FileAccess.get_file_as_string("res://data/lore.json")
	_check(not "taint" in all.to_lower(), "no 'Taint' in lore.json")
	_check(not "caption" in all.to_lower(), "no caption text")

	print("test_lore: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)
