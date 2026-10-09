extends SceneTree
## P4-11 end to end on a live host (QA): the D-085 `no_scrap` refusal and the scrap spend, a pumpkin gnaw that
## lands at dawn and one blocked by a guard, and a full wipe (doubled trample, 2 extra traps next night).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p4_11_e2e.gd -- --host --bots=1 --port=56621 --free-mouse
## Exits 0 on pass, 1 on any failure.

var _fails := 0
var _frames := 0
var _ev: Array = []  # [name, data] from Log.logged
var Game: Node
var Clock: Node
var Data: Node
var main: Node
var farm: Node
var sab: Node
var dev: Node


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 60:
		_run()
	return false


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _last(name: String) -> Variant:
	for i in range(_ev.size() - 1, -1, -1):
		if _ev[i][0] == name:
			return _ev[i][1]
	return null


func _wait(s: float) -> void:
	await create_timer(s).timeout


## Pin every player at `at` (the host drops their own frames until then, as death.gd's respawn does).
func _pin_all(at: Vector3) -> void:
	for p in Game.players:
		Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
		Game.players[p].pos = at


func _run() -> void:
	Game = root.get_node("Game")
	Clock = root.get_node("Clock")
	Data = root.get_node("Data")
	main = root.get_node("Main")
	farm = main.get_node("Farm")
	sab = get_first_node_in_group(&"sabotage")
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	print("players ", Game.players.keys())
	_check(Game.players.size() >= 2, "host plus a bot")
	_check(dev != null, "dev console present")
	if dev == null:
		quit(1)
		return
	await _scrap()
	await _gnaw()
	await _wipe()
	print("test_p4_11_e2e: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)


func _scrap() -> void:
	var reg: Node = farm.registry
	var gen: Node = main.get_node("Generator")
	var spot: Vector3 = farm.targets["generator"].target_pos()
	_pin_all(spot)
	farm.free_scrap = 0
	farm.store.scrap_bought = 0
	farm.coins = 0  # the bot cannot buy scrap either
	gen.damage()
	_ev.clear()
	reg.request(1, &"repair_generator", "generator")
	var r: Variant = _last("hold_refused")
	_check(r != null and r.reason == "no_scrap", "repair_generator refused no_scrap with 0 scrap: %s" % [r])
	farm.free_scrap = 1
	_ev.clear()
	reg.request(1, &"repair_generator", "generator")
	_check(_last("hold_refused") == null and reg.holds.has(1), "repair_generator starts with 1 scrap")
	await _wait(8.0)
	_check(not gen.damaged and farm.store.scrap_total() == 0 and _last("scrap_used") != null, "repair done, scrap spent (%s)" % [_last("scrap_used")])
	# A FixTarget (strange seeds): the same rule.
	_check(sab._place(&"strange_seeds"), "strange_seeds placed")
	var job: Array = []
	for j: Array in sab.fix_jobs():
		if j[0] == &"pull_seeds":
			job = j
	_check(not job.is_empty(), "pull_seeds job listed")
	if job.is_empty():
		return
	_pin_all(farm.targets[job[1]].target_pos())
	_ev.clear()
	reg.request(1, job[0], job[1])
	r = _last("hold_refused")
	_check(r != null and r.reason == "no_scrap", "pull_seeds refused no_scrap: %s" % [r])
	farm.free_scrap = 1
	_ev.clear()
	reg.request(1, job[0], job[1])
	await _wait(float(Data.record(&"sabotage", &"strange_seeds").fix_hold_s) + 3.0)
	_check(_last("disturbance_fixed") != null and farm.store.scrap_total() == 0, "pull_seeds fixed, scrap spent (%s)" % [_last("disturbance_fixed")])


## Trap kinds the creature will plan tonight without a wipe (creature.gd `_plan_traps`).
func _base_traps(day: int) -> int:
	var cr: Node = main.get_node("Creature")
	var row: Dictionary = Data.record(&"ramp_up", StringName("day_%d" % clampi(day, 1, 7)))
	var heads := clampi(Game.player_count(), 2, Game.max_players())
	var n := 0
	for k in [[&"bear", &"bear_trap", "bear_4p"], [&"pit", &"pit", "pit_4p"]]:
		if not bool(Data.record(&"traps", k[1]).get("enabled", true)) or row.get(k[2]) == null:
			continue
		var have: int = cr._traps.values().filter(func(t: Dictionary) -> bool: return t.kind == k[0] and t.armed).size()
		n += maxi(Data.scaled(int(row[k[2]]), &"traps", heads) - have, 0)
	return n


func _gnaw() -> void:
	var pk: Node = farm.targets["prize_pumpkin"]
	var barn: Vector3 = Game.players[1].pos
	dev.run("day 3")
	dev.run("pumpkin plant")
	var far := Vector3(pk.target_pos().x + 60.0, 0.0, pk.target_pos().z)
	_pin_all(far)
	_ev.clear()
	_check(sab._place(&"pumpkin_gnaw"), "gnaw spent on day 3")
	_check(_last("pumpkin_gnaw_spent") != null, "pumpkin_gnaw_spent logged")
	_check(not sab._place(&"pumpkin_gnaw"), "a second gnaw the same day is refused")
	dev.run("phase night")
	await _wait(1.0)
	dev.run("phase dawn")
	await _wait(0.5)
	var g: Variant = _last("pumpkin_gnaw")
	_check(g != null and pk.drops == 1, "unguarded gnaw landed at dawn: %s" % [g])
	var dp: Variant = null
	for e in _ev:
		if e[0] == "disturbance_placed" and e[1].get("kind", "") == "pumpkin_gnaw":
			dp = e[1]
	_check(dp != null, "teeth marks placed: %s" % [dp])
	var steps: Array = _ev.filter(func(e: Array) -> bool: return e[0] in ["dawn_step", "trample", "pumpkin_gnaw"]).map(func(e: Array) -> String: return e[0] if e[0] != "dawn_step" else e[1].step)
	_check(steps.find("trample") > steps.find("farm_damage") and steps.find("pumpkin_gnaw") < steps.find("save"), "trample and gnaw in step 5: %s" % [steps])
	# Day 4: a guard within 20 m blocks it.
	dev.run("phase day")
	_pin_all(far)
	_ev.clear()
	_check(sab._place(&"pumpkin_gnaw"), "gnaw spent on day 4")
	var base := _base_traps(Clock.day)
	dev.run("phase night")
	var tp: Variant = _last("trap_plan")
	_check(tp != null and tp.plan.size() == base, "control night: trap_plan %d == base %d" % [tp.plan.size() if tp else -1, base])
	_pin_all(pk.target_pos() + Vector3(5.0, 0.0, 0.0))
	await _wait(1.0)
	_pin_all(barn)
	dev.run("phase dawn")
	await _wait(0.5)
	var b: Variant = _last("pumpkin_gnaw_blocked")
	_check(b != null and b.reason == "guarded" and pk.drops == 1, "guarded gnaw blocked: %s, drops %d" % [b, pk.drops])


func _wipe() -> void:
	var cr: Node = main.get_node("Creature")
	dev.run("phase day")
	dev.run("grow ripe")
	_pin_all(Game.players[1].pos)
	dev.run("phase night")
	await _wait(0.5)
	var plain: Variant = null
	for p in Game.players.keys():
		dev.run("kill %d" % p)
	_check(Game.players.keys().all(func(p: int) -> bool: return Game.is_ghost(p)), "every player a ghost")
	_ev.clear()
	dev.run("phase dawn")
	await _wait(0.5)
	var t: Variant = _last("trample")
	var rec: Dictionary = sab._recs.trample
	plain = sab.Logic.trample_count(rec, 0.0, sab._nobody_s, false)
	_check(t != null and t.full_wipe, "trample logs full_wipe: %s" % [t])
	if t:
		var gen_dead: bool = t.generator_dead
		plain = sab.Logic.trample_count(rec, float(t.best_outside_s), float(t.nobody_outside_s), gen_dead)
		_check(int(t.want) == 2 * int(plain), "trample want %d == 2 x %d" % [t.want, plain])
	_check(cr.wipe_traps == 2, "creature holds 2 wipe traps (%d)" % cr.wipe_traps)
	_check(Game.players.keys().all(func(p: int) -> bool: return not Game.is_ghost(p)), "everyone respawned after the steps")
	dev.run("phase day")
	_ev.clear()
	var base := _base_traps(Clock.day)
	dev.run("phase night")
	var tp: Variant = _last("trap_plan")
	_check(tp != null and tp.plan.size() == base + 2, "next night trap_plan %d == base %d + 2: %s" % [tp.plan.size() if tp else -1, base, tp.plan if tp else []])
	_check(cr.wipe_traps == 0, "wipe traps used once")
	dev.run("phase dawn")
	await _wait(0.5)
	var t2: Variant = _last("trample")
	_check(t2 != null and not t2.full_wipe, "the next dawn is not a wipe")
