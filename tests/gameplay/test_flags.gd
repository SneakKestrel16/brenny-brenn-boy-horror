extends SceneTree
## P4-33: the flag limit per player, anyone pulling up a flag and a leaver's flags going (doc 01 "Flags", D-120,
## D-142). One host on the full farm, no client; holds go through the HoldRegistry and are ticked by hand.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_flags.gd -- --host --port=24861 --free-mouse

var FlagSpot: GDScript  ## loaded after the autoloads (a preload here fails to compile: it names Game)

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
		if _t > 30.0:
			print("test_flags: FAIL (no Main after 30 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	FlagSpot = load("res://game/traps_player/flag_spot.gd")
	var data: Node = root.get_node("Data")
	var game: Node = root.get_node("Game")
	var farm: Node = main.get_node("Farm")
	var sweep: Node = get_first_node_in_group(&"trap_sweep")
	var me: int = game.local_peer()
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _log.append([String(n), d]))
	var lim: int = sweep.limit()
	_check(lim == int(data.record(&"labor", &"place_flag").max_per_player) and lim >= 1, "limit read from labor.json (%d)" % lim)
	var st: Dictionary = farm.pstate(me)
	var base := Vector3(-12.0, 0.0, 22.0)  # open ground east of the shed
	st.pos = base
	var ids: Array = []
	for i in lim:
		var id: String = FlagSpot.make_id(base + Vector3(i * 1.5 - 1.5, 0, 1.0))
		ids.append(id)
		_hold(farm, me, &"place_flag", id)
	_check(sweep.count_of(me) == lim and sweep.flags.size() == lim, "%d flags placed" % lim)
	_check(_last("flag_placed").get("mine") == lim, "flag_placed logs the player's count")
	var extra: String = FlagSpot.make_id(base + Vector3(0, 0, -1.5))
	_hold(farm, me, &"place_flag", extra)
	_check(sweep.count_of(me) == lim and _last("hold_refused").get("reason") == "flag_limit", "one over the limit: refused flag_limit")
	var other := 99  # a second player has their own slots
	game.players[other] = {}
	var ost: Dictionary = farm.pstate(other)
	ost.pos = base
	_hold(farm, other, &"place_flag", extra)
	_check(sweep.count_of(other) == 1 and sweep.flags.size() == lim + 1, "another player's limit is separate")
	var drawn: Array = []
	for n in sweep.find_children("*", "", true, false):
		if n.get_script() == FlagSpot:
			drawn.append(n)
	_check(drawn.size() == lim + 1, "every flag is drawn with a pick target (%d)" % drawn.size())
	_check(drawn.all(func(s: Node) -> bool: return s.verbs_for({}) == [&"remove_flag"]), "every flag offers remove_flag to anyone (D-142)")
	_hold(farm, other, &"remove_flag", ids[0])
	var rm := _last("flag_removed")
	_check(sweep.count_of(me) == lim - 1 and rm.get("player") == other and rm.get("owner") == me,
			"another player pulls up my flag: my slot frees, flag_removed logs both (%s)" % rm)
	_hold(farm, me, &"remove_flag", ids[0])
	_check(_last("hold_refused").get("reason") == "no_flag", "no flag left there: refused no_flag")
	_hold(farm, me, &"remove_flag", ids[1])
	_check(sweep.count_of(me) == lim - 2 and _last("flag_removed").get("player") == me, "the owner pulls up their own too")
	_hold(farm, me, &"place_flag", FlagSpot.make_id(base + Vector3(0, 0, 3.0)))
	_check(sweep.count_of(me) == lim - 1, "a freed slot takes a new flag")
	sweep.remove_flags_near(sweep.flags.filter(func(f: Dictionary) -> bool: return f.by == me)[0].pos, 0.5)
	_check(sweep.count_of(me) == lim - 2, "a flag cleared by a disarm frees its slot too")
	game.players.erase(other)
	game.player_left.emit(other)
	_check(sweep.count_of(other) == 0 and sweep.count_of(me) == lim - 2 and _last("flags_dropped").get("count") == 1,
			"a leaver's flags go with them, nobody else's (D-142)")
	print("test_flags: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(1 if _fails > 0 else 0)
	return false


## Request a hold and tick the registry until it ends.
func _hold(farm: Node, peer: int, verb: StringName, id: String) -> void:
	farm.registry.request(peer, verb, id)
	for i in 5:
		if not farm.registry.holds.has(peer):
			return
		farm.registry._physics_process(0.5)


func _last(n: String) -> Dictionary:
	for i in range(_log.size() - 1, -1, -1):
		if _log[i][0] == n:
			return _log[i][1]
	return {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
