class_name Quirks
extends RefCounted
## P5-09 (doc 01 "Quirks", D-052, D-158): the opt-in group option. Each player gets one of ten quirks, drawn without
## replacement and seeded by host seed + season + roster, kept by uid so a rejoiner keeps theirs (doc 01 "Rejoining") and
## saved with the season. Numbers are in `data/quirks.json`; nothing here is a number. A quirk never shows the creature
## clearly, harms it, fakes an honest signal or touches debt and prices, and none of them flashes anything: the
## only light flicker in the game is the ghosts' (doc 01 "Photosensitivity safety").
## Host: `Game.quirks` (uid -> id) is the truth and `Game.players[peer].quirk` its live view (host only, never sent).
## A client learns only its own, in `mine`, through the `apply_roles` RPC (`sync`). Everyone learns all at season end
## (`reveal`, shown on the Season Awards card).

static var mine: StringName = &""  ## this client's own quirk, "" with the option off or as a ghost-less spectator
static var last_name := {}  ## host: uid -> last known player name, kept after they leave, for the reveal
static var season_n := 1  ## the season's number for the draw seed; P5-04 calls `reroll` when a new season starts


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in Data.records(&"quirks"):
		if r.has("effects"):  # the `assign` record has none
			out.append(StringName(r.id))
	return out


static func effects(id: StringName) -> Dictionary:
	return Data.record(&"quirks", id).get("effects", {}) if id != &"" and Data.has_table(&"quirks") else {}


static func display_name(id: StringName) -> String:
	return str(Data.record(&"quirks", id).get("name", id)) if id != &"" else ""


## Pure: `held` (uid -> id) plus a draw for every uid in `uids` without one. Without replacement within the team
## (wraps only past ten players). The result depends on the seed, the season and the sorted roster, not join order.
static func draw(uids: Array, seed_value: int, season: int, held: Dictionary, pool: Array) -> Dictionary:
	var out := held.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d" % [seed_value, season])
	var bag := pool.duplicate()
	for i in range(bag.size() - 1, 0, -1):  # Fisher-Yates
		var j := rng.randi_range(0, i)
		var t = bag[i]
		bag[i] = bag[j]
		bag[j] = t
	var order := uids.duplicate()
	order.sort()
	for u in order:
		if out.has(u):
			continue
		var free := bag.filter(func(q: Variant) -> bool: return not q in out.values())
		out[u] = free[0] if not free.is_empty() else bag[out.size() % bag.size()]  # ponytail: a team over ten repeats quirks
	return out


## Pure: the season-end reveal, one line per held quirk, players who left included (D-161, D-052: the real disorder
## name). `name_of` is uid -> last known name; a uid with none shows as "A farmhand".
static func reveal(held: Dictionary, name_of: Dictionary) -> Array:
	var out: Array = []
	for u in held:
		out.append("%s: %s" % [name_of.get(u, "A farmhand"), display_name(StringName(str(held[u])))])
	return out


# --- host ------------------------------------------------------------------------------------------

static func _uid(peer: int) -> String:
	return str(Net.profiles.get(peer, {}).get("uid", ""))


## The quirk `peer` holds, even as a ghost (Narcolepsy reads it at dawn). Host only.
static func held(peer: int) -> StringName:
	return StringName(str(Game.players.get(peer, {}).get("quirk", "")))


## The quirk `peer` has now: ghosts have none (doc 01). Host only.
static func of(peer: int) -> StringName:
	return &"" if Game.is_ghost(peer) else held(peer)


## Host: an effect number of `peer`'s quirk, `fallback` when it has none or lacks that key.
static func effect(peer: int, key: StringName, fallback: Variant = 1.0) -> Variant:
	return effects(of(peer)).get(String(key), fallback)


## Host: the bag's capacity for this player state (labor.json carry plus Hoarding disorder's extra slot).
static func carry_cap(st: Dictionary) -> int:
	var id := StringName(str(st.get("quirk", "")))
	return int(Data.value(&"labor", &"carry", &"capacity")) + (0 if bool(st.get("ghost", false)) else int(effects(id).get("carry_extra_slots", 0)))


## Host, lobby only: the group option.
static func set_on(on: bool) -> void:
	if not Game.is_host() or not Game.in_lobby:
		return
	Game.quirks_on = on
	Log.event(&"group_settings", {"difficulty": String(Game.difficulty), "streamer_safe": Game.streamer_safe, "quirks": on})
	Roles.sync()


## Host: a new season redraws every quirk (doc 01 "redrawn each season"). P5-04 calls this at the new season's start.
static func reroll(season: int) -> void:
	if not Game.is_host():
		return
	season_n = season
	Game.quirks.clear()
	Roles.sync()


## Host: draw for whoever lacks one (match start, a rejoin, a new season), log it, then put each quirk on its player
## and send each peer its own. Called by `Roles.sync`.
static func sync() -> void:
	if not Game.is_host():
		return
	var on := Game.quirks_on
	if on and not Game.in_lobby:
		var uids: Array = []
		for p in Game.players:
			if _uid(p) != "":
				uids.append(_uid(p))
				last_name[_uid(p)] = str(Net.profiles[p].get("name", ""))
		var before := Game.quirks.duplicate()
		Game.quirks = draw(uids, Game.seed_value, season_n, before, ids())
		for u in Game.quirks:
			if not before.has(u):
				Log.event(&"quirk_assigned", {"uid": u, "quirk": Game.quirks[u], "season": season_n, "seed": Game.seed_value})
	for p in Game.players:
		var id: String = str(Game.quirks.get(_uid(p), "")) if on and not Game.in_lobby else ""
		Game.players[p].quirk = StringName(id)
		var t := {"quirks_on": on, "quirk": id}
		if p == 1:
			apply(t)
		elif p > 1:
			Net.to_peers(&"apply_roles", [t], [p])


## Every peer: the table `Roles.apply` got (its own quirk and the option).
static func apply(table: Dictionary) -> void:
	if table.has("quirks_on"):
		Game.quirks_on = bool(table.quirks_on)
	if table.has("quirk"):
		mine = StringName(str(table.quirk))


## This client's effect number (movement and the HUD are client side). Ghosts have none.
static func local(key: StringName, fallback: Variant = 1.0) -> Variant:
	if mine == &"" or Game.is_ghost(Game.local_peer()):
		return fallback
	return effects(mine).get(String(key), fallback)
