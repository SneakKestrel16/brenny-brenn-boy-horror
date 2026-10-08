class_name Rejoin
extends RefCounted
## D-048, D-049, D-050 (doc 01 "Joining and leaving", doc 06 s5): the client's rejoin memory, on this PC only.
## `last_session.cfg` holds where the last match was (written at match start, cleared on a clean Leave or
## match end); `rejoin_bag.cfg` holds the mockery-line shuffle bag. Both live in `Net.user_dir()` (`user://`,
## or the QA `--profile=<name>` folder so two local copies keep their own).

const SESSION := "last_session.cfg"
const BAG := "rejoin_bag.cfg"


static func save_session(address: String, session_id: String) -> void:
	var c := ConfigFile.new()
	c.set_value("session", "address", address)
	c.set_value("session", "session_id", session_id)
	c.save(Net.user_dir() + SESSION)


## {"address": "ip:port", "session_id": ...} or {} when there is nothing to rejoin.
static func last_session() -> Dictionary:
	var c := ConfigFile.new()
	if c.load(Net.user_dir() + SESSION) != OK or str(c.get_value("session", "address", "")).is_empty():
		return {}
	return {"address": str(c.get_value("session", "address")), "session_id": str(c.get_value("session", "session_id", ""))}


static func clear_session() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Net.user_dir() + SESSION))


## D-050: a shuffle bag. `seen` is the lines shown this round, so the bag is everything else; a line added to
## the data file joins the bag, a removed one drops out. An empty bag starts a new round that never opens on
## `last`. Picks uniformly from the bag (the same thing as drawing from a shuffled order) and saves the draw.
static func next_line(lines: Array, path: String = "") -> String:
	if lines.is_empty():
		return ""
	if path.is_empty():
		path = Net.user_dir() + BAG
	var c := ConfigFile.new()
	c.load(path)
	var seen: Array = c.get_value("bag", "seen", []).filter(func(l: Variant) -> bool: return l in lines)
	var last := str(c.get_value("bag", "last", ""))
	var bag: Array = lines.filter(func(l: Variant) -> bool: return not l in seen)
	if bag.is_empty():
		seen = []
		bag = lines.filter(func(l: Variant) -> bool: return l != last) if lines.size() > 1 else lines.duplicate()
	var pick: String = bag[randi() % bag.size()]
	seen.append(pick)
	c.set_value("bag", "seen", seen)
	c.set_value("bag", "last", pick)
	c.save(path)
	return pick


## The line for a rejoiner, from `data/rejoin_lines.json`.
static func line() -> String:
	return next_line(Data.record(&"rejoin_lines", &"lines").get("lines", []))
