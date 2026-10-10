class_name Campaign
extends RefCounted
## P5-04 (doc 01 "Next season", doc 02 s21, doc 03 s22, doc 05 s18): the rules of a campaign's next season. Numbers are
## in `data/next_season.json` and `data/creature_traits.json`. The pure helpers take plain values so
## tests/gameplay/test_next_season.gd runs them with no scene. `Game.start_next_season` (host) drives the flow:
## `build_carry` reads the live nodes at the season end, Main reloads, `apply_carry` pushes the carry into the new nodes.


static func rule(id: StringName) -> Dictionary:
	return Data.record(&"next_season", id) if Data.has_table(&"next_season") else {}


static func seasons_max() -> int:
	return int(rule(&"campaign").get("seasons_max", 1))


## Doc 02 s21.2: `savings_pct` of the spare coins, rounded down, at most `savings_cap_coins`.
static func savings(spare: int) -> int:
	var c := rule(&"carry")
	return mini(maxi(spare, 0) * int(c.get("savings_pct", 0)) / 100, int(c.get("savings_cap_coins", 0)))


## Doc 03 s22.1: uniform among the traits not gained yet, seeded by (host seed, season) so the same seed and season
## give the same trait. "" when every trait is gained.
static func draw_trait(seed_value: int, season: int, gained: Array) -> String:
	var left: Array[String] = []
	for r in Data.records(&"creature_traits"):
		if not gained.has(r.id):
			left.append(r.id)
	if left.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d" % [seed_value, season])
	return left[rng.randi() % left.size()]


## Doc 02 s21.4: the season's debt base for `players` (clamped 2 to max), 0 in season 1 (debt.json decides there).
static func debt_base(season: int, players: int) -> int:
	var r := rule(StringName("season_%d" % season)) if season > 1 else {}
	return int(r.get("debt_total_4p_by_players", {}).get(str(clampi(players, 2, Game.max_players())), r.get("debt_total_4p", 0)))


## Doc 02 s21.2: carried plot ids that still fit under `ceiling` when `open_now` plots are open.
static func clamp_plots(ids: Array, open_now: int, ceiling: int) -> Array:
	return ids.slice(0, maxi(ceiling - open_now, 0))


## Host, the season is over: what carries (doc 02 s21.2). Reads the live nodes; Main is freed after this.
static func build_carry(tree: SceneTree) -> Dictionary:
	var farm := tree.get_first_node_in_group(&"farm")
	var s := Save.build(tree, true)  # the same upgrade / owner / plot bookkeeping the dawn save keeps
	var upgrades := {}
	for r in Data.records(&"store"):
		if bool(r.upgrade) and r.id != "plot_pair" and s.store.team.has(r.id):
			upgrades[r.id] = int(s.store.team[r.id])
	return {"team": upgrades, "own": s.store.own, "plots": s.store.plots, "spare": farm.coins, "savings": savings(farm.coins)}


## Host, end of Main._ready of the new season (Save.apply_pending): upgrades, plots, savings.
static func apply_carry(main: Node) -> void:
	var c := Game.carry
	Game.carry = {}
	var farm: Node = main.get_node("Farm")
	var st: Node = farm.store
	Save._apply_store(farm, {"team": c.team, "own": c.own}, main)
	var opened := 0
	for id in clamp_plots(c.plots, st.open_plots(), farm.plot_ceiling()):  # doc 02 s21.2: never past the new headcount's ceiling
		var t: Node = farm.targets.get(id)
		if t == null:
			continue
		if t.locked:
			t.locked = false
			t._refresh()
			farm.plot_changed(t)
		st.plots.append(id)
		opened += 1
	if opened > 0:
		st.team[&"plot_pair"] = (opened + 1) / 2
	if int(st.team.get(&"flare_gun", 0)) > 0:
		st.flare_shots = st.flare_capacity()
	st._send()
	Save._remap(st)
	farm.add_coins(int(c.savings), &"savings", 0)
	Log.event(&"season_started", {"season": Game.season_no, "savings": int(c.savings), "spare": int(c.spare), "coins": farm.coins,
			"plots": st.plots.duplicate(), "plots_carried": c.plots.size(), "upgrades": c.team, "headcount": farm.headcount,
			"traits": Game.traits.duplicate()})
