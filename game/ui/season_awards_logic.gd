extends RefCounted
## P4-15 Season Awards rules (doc 01 "Season Awards", doc 03 section 17.4, doc 05 section 15), pure so
## tests/ui/test_season_awards_logic.gd checks them headless. `tally` folds one season's host log events into
## per-player counts; `build` turns the counts into the screen's dictionary (text only, sent by `apply_season_awards`).

const Report := preload("res://game/ui/dawn_report_logic.gd")
## Reasons that are not earned coins (doc 01 "Season Awards": most coins earned). Placeholder: sales and the dawn cash-in count.
const NOT_EARNED := ["start_coins", "dev"]
## Award id -> tally key, in the order doc 03 section 17.4 lists them.
const CATEGORIES := [["award_traps_disarmed", "disarmed"], ["award_fooled_by_voice", "fooled"], ["award_most_coins", "coins"],
		["award_barn_goblin", "inside"]]


static func empty_tally() -> Dictionary:
	return {"disarmed": {}, "fooled": {}, "coins": {}, "inside": {}}


## Folds one log event into `t` (host, as the log writes them; the season keeps one tally).
static func tally(t: Dictionary, name: String, d: Dictionary) -> void:
	match name:
		"trap_changed":  # as the Dawn Report's Hero: a disarm or a pit filled, by a player
			if d.get("state") in ["disarmed", "filled"] and d.get("by") is int:
				_add(t.disarmed, int(d.by), 1)
		"lure_fooled":
			_add(t.fooled, int(d.target), 1)
		"money_changed":
			if d.get("player") != null and int(d.delta) > 0 and String(d.reason) not in NOT_EARNED:
				_add(t.coins, int(d.player), int(d.delta))
		"inside_at_night":
			_add(t.inside, int(d.player), int(round(float(d.seconds))))


static func _add(m: Dictionary, p: int, n: int) -> void:
	m[p] = m.get(p, 0) + n


## `lost`: the caller's ruling (Q-130): the final payment missed, or everyone dead on the Harvest Moon before the cart is out.
## Every player in ctx.players ends with at least one award: the four winners, then "Still Here" for the rest.
static func build(t: Dictionary, ctx: Dictionary, templates: Dictionary, lost: bool) -> Dictionary:
	var names: Dictionary = ctx.get("names", {})
	var awards: Array = []
	var got := {}
	for c: Array in CATEGORIES:
		var counts: Dictionary = t[c[1]].duplicate()
		for p: int in counts.keys():
			if counts[p] <= 0 or not ctx.players.has(p):
				counts.erase(p)
		var best := Report._top(counts, {})
		if best != 0:
			got[best] = true
			awards.append({"id": c[0], "player": best, "line": Report._fmt(templates, c[0], {"name": Report._name(names, best), "n": counts[best]})})
	for p: int in ctx.players:
		if not got.has(p):
			awards.append({"id": "award_participation", "player": p, "line": Report._fmt(templates, "award_participation", {"name": Report._name(names, p)})})
	return {"day": ctx.get("day", 0), "lost": lost, "awards": awards}
