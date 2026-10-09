extends SceneTree
## P4-04: every crop in crops.json plants, grows, harvests and sells; the dawn steps run in doc 02 s9 order; the
## final dawn sells the standing crops at half price and the season ends. One host, no client.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_season.gd -- --host --phase1 --port=45399 --free-mouse

var _t := 0.0
var _done := false
var _fails := 0
var _log: Array = []


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null:
		if _t > 20.0:
			print("test_season: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var Crops: GDScript = load("res://game/farming/crops.gd")
	var farm: Node = main.get_node("Farm")
	var death: Node = main.get_node("Death")
	var clock: Node = root.get_node("Clock")
	var me: int = root.get_node("Game").local_peer()
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _log.append([String(n), d]))
	var plots: Array = []
	for t in farm.targets.values():
		if t.has_method("dawn_wilt"):
			plots.append(t)
	farm.coins = 1000
	load("res://game/farming/debt.gd").first_made = true  # P4-07: the pumpkin is on sale once the first payment is made
	var st: Dictionary = farm.pstate(me)
	st.bag = 0
	st.bag_by = {}
	# every crop in the table: plant, water, grow, harvest, sell
	var p = plots[0]
	for id: StringName in Crops.ids():
		var night := String(Crops.rec(id).harvest_phase) == "night"
		p.bed = night
		clock.day = 7
		clock.phase = &"day"
		p.state = &"empty"
		var verb := StringName("plant:" + id)
		_check(p.can_start(verb, st) == &"", "%s can be planted (got %s)" % [id, p.can_start(verb, st)])
		var coins: int = farm.coins
		p.complete(verb, me, st)
		_check(p.state == &"growing" and p.crop == id, "%s growing" % id)
		_check(coins - farm.coins == int(Crops.rec(id).seed), "%s seed charged" % id)
		p.watered = true
		if night:
			clock.phase = &"night"
			p.on_phase(&"night")
		else:
			for i in int(Crops.rec(id).grow_days):
				p.watered = true
				p.advance_day()
		_check(p.state == &"ripe", "%s ripe (state %s)" % [id, p.state])
		_check(p.wire_state() == StringName("ripe:" + id), "%s wire state" % id)
		var q := {"bag": 0, "bag_by": {}}
		p.complete(&"harvest", me, q)
		_check(int(q.bag_by.get(id, 0)) == 1 and p.state == &"empty", "%s harvested" % id)
		_check(Crops.bag_value(q) == int(Crops.rec(id).sell), "%s sells for its price" % id)
	# a locked crop and the wrong crop for a plot
	clock.day = 1
	p.bed = false
	p.state = &"empty"
	for id: StringName in Crops.ids():
		if int(Crops.rec(id).unlock_day) > 1 and String(Crops.rec(id).harvest_phase) == "day":
			_check(p.can_start(StringName("plant:" + id), st) == &"locked_crop", "%s locked on day 1" % id)
	_check(p.can_start(StringName("plant:" + Crops.night_crop()), st) == &"wrong_crop", "night crop refused in a field plot")
	# dead night crop taints
	p.bed = true
	clock.day = 7
	clock.phase = &"night"
	p.complete(StringName("plant:" + Crops.night_crop()), me, st)
	p.watered = true
	p.on_phase(&"night")
	_check(p.dawn_wilt() and p.state == &"dead" and p.taint_id > 0, "unpicked night crop dies and taints")
	p.complete(&"clear_plot", me, st)
	_check(p.state == &"empty" and p.taint_id == 0, "clearing a dead plot ends its taint")
	p.bed = false
	# dawn order; the final-sale step only pays on the last day
	clock.day = 3
	_log.clear()
	death.dawn()
	var steps: Array = _log.filter(func(e: Array) -> bool: return e[0] == "dawn_step").map(func(e: Array) -> String: return e[1].step)
	var want: Array = death.DAWN_STEPS.map(func(s: StringName) -> String: return String(s))
	_check(steps == want, "dawn steps in order %s (got %s)" % [want, steps])
	_check(_log.all(func(e: Array) -> bool: return e[0] != "end_of_season_sale"), "no end-of-season sale on day 3")
	# final dawn: standing crop sold at end_season_sale_pct, then the clock ends the season
	clock.day = int(root.get_node("Data").value(&"season", &"season_days"))
	p.state = &"empty"
	p.complete(&"plant", me, st)
	var worth: int = p.sell_value()
	farm.coins = 0
	_log.clear()
	death.dawn()
	var pct := int(root.get_node("Data").value(&"season", &"end_season_sale_pct"))
	var sale := 0
	for e in _log:
		if e[0] == "money_changed" and e[1].reason == "end_of_season_sale":
			sale += int(e[1].delta)
	_check(sale == roundi(worth * pct / 100.0) and sale > 0, "final dawn sells the standing crop (%d, worth %d)" % [sale, worth])
	clock.phase = &"dawn"
	clock.dev_advance()
	_check(clock.season_over and not clock.running and clock.day == 7, "season ends after the final dawn")
	print("test_season: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL", what)
