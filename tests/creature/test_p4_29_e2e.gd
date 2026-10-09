extends SceneTree
## P4-29 end to end on a live host (QA): a bear trap springs on the host player, the pry frees them (slowed),
## the sprung trap stays at its spot as a pickup, the player takes it and hangs it on the pegboard (an empty
## outline fills). A second pried trap left lying is the creature's at nightfall (D-104).
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p4_29_e2e.gd -- --host --bots=1 --port=24768 --free-mouse
## Exits 0 on pass, 1 on any failure.

const PICKUP := "res://game/creature/trap_pickup.gd"  # not preloaded: its base reads autoloads this SceneTree cannot compile against

var _fails := 0
var _frames := 0
var _ev: Array = []  # [name, data] from Log.logged
var Game: Node
var Data: Node
var main: Node
var farm: Node
var cr: Node
var race: Node
var sweep: Node
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


func _last(name: String, state := "") -> Variant:
	for i in range(_ev.size() - 1, -1, -1):
		if _ev[i][0] == name and (state == "" or _ev[i][1].get("state", "") == state):
			return _ev[i][1]
	return null


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _pin(p: int, at: Vector3) -> void:
	Game.players[p].freeze_until = Time.get_ticks_msec() + 3600000
	Game.players[p].pos = at


func _run() -> void:
	Game = root.get_node("Game")
	Data = root.get_node("Data")
	main = root.get_node("Main")
	farm = main.get_node("Farm")
	cr = main.get_node("Creature")
	race = main.get_node("TrapRace")
	sweep = get_first_node_in_group(&"trap_sweep")
	for c in main.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
			dev = c
	root.get_node("Log").logged.connect(func(n: StringName, d: Dictionary) -> void: _ev.append([String(n), d]))
	_check(Game.full_farm and Game.players.size() >= 2 and dev != null, "full farm, host plus a bot, dev console")
	for p in Game.players:
		_pin(p, Vector3(0, 0, -200))  # away from every spot
	var spots: Array = get_nodes_in_group(&"trap_spots")
	await _cycle(spots[0])
	await _theft(spots[spots.size() - 1])
	print("test_p4_29_e2e: ", "FAIL %d" % _fails if _fails else "PASS")
	quit(1 if _fails else 0)


## Spring, pry free, then the trap lies at its spot. Returns its id.
func _spring_and_pry(spot: Node3D) -> String:
	var id := String(spot.name)
	cr._arm(spot, &"bear", {})
	_ev.clear()
	_pin(1, spot.global_position)
	await _wait(0.3)
	_check(race.races.has(id) and race.victims.get(id) == 1, "%s sprung, host player pinned" % id)
	if race.races.has(id):
		race.races[id].deadline += 30.0  # the day's rolled start distance can be shorter than the pry
	farm.registry.request(1, &"pry", id)
	await _wait(Data.hold_s(&"pry") + 0.5)
	_check(not race.victims.has(id) and not bool(Game.players[1].get("pinned", false)), "pried free")
	_check(is_equal_approx(float(Game.players[1].speed_mult), race.SLOW_MULT), "slowed after the trap")
	var r: Variant = _last("trap_race_result")
	_check(r != null and r.survived, "trap race result survived: %s" % [r])
	_check(_last("trap_changed", "loose") != null, "trap_changed loose logged")
	_check(cr._traps.get(id, {}).get("loose", false), "creature keeps the trap at its spot, loose")
	_check(_is_pickup(farm.targets.get(id)), "the spot holds a TrapPickup, not the pry target")
	_check(spot.get_node_or_null(^"Sprung") == null, "the pinned-trap art is gone")
	var art: Variant = farm.targets[id].get_meta(&"art") if _is_pickup(farm.targets.get(id)) else null
	_check(art != null and is_instance_valid(art) and art.get_parent() == spot, "sprung trap art lies at the spot")
	return id


func _cycle(spot: Node3D) -> void:
	sweep.take_trap()  # one empty outline to fill
	var before: int = sweep.filled.count(true)
	var id: String = await _spring_and_pry(spot)
	farm.registry.request(1, &"take_trap", id)
	await _wait(float(farm.targets[id].INSTANT_S[&"take_trap"]) + 0.3)
	_check(bool(Game.players[1].get("trap", false)), "picked up: the trap is in the hands (refused: %s)" % [_last("hold_refused")])
	_check(_last("trap_changed", "picked_up") != null and not cr._traps.has(id), "picked_up logged, spot free")
	_check(not farm.targets.has(id), "pickup gone from the spot")
	_pin(1, farm.targets["pegboard"].target_pos())
	farm.registry.request(1, &"hang_trap", "pegboard")
	await _wait(Data.hold_s(&"hang_trap") + 0.5)
	var h: Variant = _last("pegboard_changed")
	_check(h != null and h.change == "hung" and h.by == 1, "pegboard_changed hung: %s" % [h])
	_check(sweep.filled.count(true) == before + 1 and not bool(Game.players[1].get("trap", false)), "outline filled, hands empty")


func _theft(spot: Node3D) -> void:
	var id: String = await _spring_and_pry(spot)
	cr._stash = 0  # the night's bear sets need traps
	_pin(1, Vector3(0, 0, -200))
	_ev.clear()
	dev.run("phase night")
	await _wait(0.5)
	var s: Variant = null
	for e in _ev:
		if e[0] == "trap_stolen" and e[1].from == "ground":
			s = e[1]
	_check(s != null and s.trap == "ground:%s" % id, "the lying trap is stolen at nightfall: %s" % [s])
	_check(not cr._traps.has(id) and not farm.targets.has(id), "stolen trap gone from the spot")


func _is_pickup(n: Variant) -> bool:
	return n is Node and n.get_script() != null and n.get_script().resource_path == PICKUP
