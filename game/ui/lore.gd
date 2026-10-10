class_name Lore
extends RefCounted
## P5-48 (doc 11 s5, s6): lookups into data/lore.json, so the CEO edits the text, not the code. Text only: no captions, no
## voice, no new rule (doc 11 s1). Pure statics; every peer reads the same file (the data hash covers it).

const DAWNS_PER_SEASON := 7  ## doc 01 Season and Numbers: seven days; the archive spans 3 x 7 = 21 dawns


static func text(id: StringName, fallback := "") -> String:
	return String(Data.record(&"lore", id).get("text", fallback))


## The clipping for a dawn: season 1 day 1 is clipping 1, season 2 day 1 is clipping 8, and so on, repeating after 21.
## `tenants` fills {tenants} (the last clipping names the current team).
static func clipping(season: int, day: int, tenants: Array) -> Dictionary:
	var list: Array = Data.record(&"lore", &"archive").get("clippings", [])
	if list.is_empty():
		return {}
	var c: Dictionary = list[archive_index(season, day, list.size())]
	var who := ", ".join(tenants) if not tenants.is_empty() else "a new crew"
	return {"head": String(c.head), "text": String(c.text).replace("{tenants}", who)}


static func archive_index(season: int, day: int, n: int) -> int:
	return posmod((season - 1) * DAWNS_PER_SEASON + (day - 1), n)


## The campaign win card's lines (doc 11 s6.5).
static func win_lines() -> Array:
	return Data.record(&"lore", &"win").get("lines", [])


## The names of the players in the match, for the "today" clipping.
static func tenant_names() -> Array:
	var out := []
	for p: int in Game.players:
		if Net.profiles.has(p) and str(Net.profiles[p].get("name", "")) != "":
			out.append(str(Net.profiles[p].name))
	return out
