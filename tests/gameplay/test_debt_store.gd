extends SceneTree
## P4-07 x P4-06 (QA): a missed first payment seizes from the real store by season.json
## `foreclosure_seizure_order` (doc 02 s7.4): dearest upgrade over the plot_pair price, else a bought plot pair,
## else 2 starting plots. A per-player upgrade is taken from one owner only.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_debt_store.gd -- --host --phase1 --port=48431 --free-mouse

var _t := 0.0
var _done := false
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null or main.get_node_or_null("Farm") == null:
		if _t > 20.0:
			print("test_debt_store: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var farm: Node = main.get_node("Farm")
	var death: Node = main.get_node("Death")
	var d: Node = death.debt
	var store: Node = farm.store
	var clock: Node = root.get_node("Clock")
	var me: int = root.get_node("Game").local_peer()
	var seized := [""]
	root.get_node("Log").logged.connect(func(n: StringName, data: Dictionary) -> void:
		if n == &"foreclosure":
			seized[0] = String(data.seized))

	# A: flare gun (50) beats a plot pair (22): the flare gun goes
	_miss(farm, d, store, clock, death, me, [&"flare_gun", &"plot_pair"])
	_check(seized[0] == "flare_gun" and int(store.team.get(&"flare_gun", 0)) == 0 and int(store.team.get(&"plot_pair", 0)) == 1,
			"dearest upgrade over 2 plots seized: %s" % seized[0])
	# B: scarecrow (20) is not over 22: the bought plot pair goes and relocks
	_miss(farm, d, store, clock, death, me, [&"scarecrow", &"plot_pair"])
	_check(seized[0] == "plot_pair" and int(store.team.get(&"plot_pair", 0)) == 0 and store.plots.is_empty()
			and int(store.team.get(&"scarecrow", 0)) == 1, "bought plot pair seized when no upgrade is over 22: %s" % seized[0])
	# C: only a scarecrow: 2 starting plots go
	_miss(farm, d, store, clock, death, me, [&"scarecrow"])
	_check(seized[0].begins_with("starting_plots:2") and int(store.team.get(&"scarecrow", 0)) == 1,
			"starting plots seized when nothing qualifies: %s" % seized[0])
	# D: two players each own a brighter lantern (25, per_player): one upgrade seized = one owner loses it
	_miss(farm, d, store, clock, death, me, [], func() -> void:
		store.team[&"brighter_lantern"] = 2
		store.own = {me: {&"brighter_lantern": true}, 9999: {&"brighter_lantern": true}})
	var owners := 0
	for p in store.own:
		if store.own[p].has(&"brighter_lantern"):
			owners += 1
	_check(seized[0] == "brighter_lantern" and int(store.team.get(&"brighter_lantern", 0)) == 1 and owners == 1,
			"per-player upgrade: one owner loses it (%s, team %d, owners %d)" % [seized[0], int(store.team.get(&"brighter_lantern", 0)), owners])

	print("test_debt_store: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)
	return false


## Fresh store and debt, buy `ids`, then miss the first payment at dawn 4.
func _miss(farm: Node, d: Node, store: Node, clock: Node, death: Node, me: int, ids: Array, extra := Callable()) -> void:
	for pid in store.plots.duplicate():
		store.seize(&"plot_pair")
	store.team = {}
	store.own = {}
	store.scarecrows.clear()
	d.paid = 0
	d.penalty = 0
	d.foreclosed = false
	d.first_made = false
	d._pcts = [d.pct_for(root.get_node("Game").player_count())] as Array[int]
	clock.day = 1
	farm.coins = 1000
	for id: StringName in ids:
		var why: StringName = store.buy(me, id, false)
		if why != &"":
			_check(false, "buy %s refused: %s" % [id, why])
	if extra.is_valid():
		extra.call()
	farm.coins = 10
	clock.day = 3
	death.dawn()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL", what)
