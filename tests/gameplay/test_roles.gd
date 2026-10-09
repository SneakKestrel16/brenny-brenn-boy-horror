extends SceneTree
## P4-09: role perks (pure) and the host flow: pick in the barn, taken refused, locked at match start, kept on rejoin.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_roles.gd -- --host --lobby --port=45611 --free-mouse
var Interactable
var Roles

var _fails := 0
var _frames := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _pure() -> void:
	_check(Roles.ids().size() == 10, "ten roles in roles.json")
	_check(Roles.hold_mult(&"repair_generator", &"mechanic") == 0.6, "Mechanic repair x0.6")
	_check(Roles.hold_mult(&"repair_generator", &"tracker") == 1.0, "Tracker repairs at normal speed")
	_check(Roles.hold_mult(&"disarm_bear", &"tracker") == 0.6, "Tracker disarm x0.6")
	_check(Roles.hold_mult(&"harvest", &"night_owl", true) == 0.6 and Roles.hold_mult(&"harvest", &"night_owl") == 1.0, "Night Owl: moonflower only")
	_check(Interactable.hold_seconds(&"repair_generator", &"mechanic") == 4.0, "6 s x0.6 = 3.6 rounds up to 4")
	_check(Interactable.hold_seconds(&"round_up", &"rancher") == 3.0, "Rancher round-up 3 s")
	_check(Interactable.hold_seconds(&"repair_generator") == 6.0, "no role: 6 s")
	_check(Roles.noise_mult(&"night_owl", &"step_walk", true) == 0.7 and Roles.noise_mult(&"night_owl", &"step_walk", false) == 1.0, "Night Owl quieter at night only")
	_check(Roles.noise_mult(&"night_owl", &"whistle", true) == 1.0 and Roles.noise_mult(&"farmer", &"tool_plant", true) == 1.0, "whistle and other roles unchanged")
	var st := {"role": &"farmer"}
	var bonus := 0
	for i in 10:
		bonus += 1 if Roles.harvest_bonus(st) else 0
	_check(bonus == 2, "Farmer: 2 bonus crops in 10 harvests")
	_check(not Roles.harvest_bonus({"role": &"medic"}), "non-Farmer never gets the bonus")
	_check(Roles.cut_bill(100, 2, 1) == 88 and Roles.cut_bill(100, 2, 2) == 75 and Roles.cut_bill(100, 2, 0) == 100, "Medic cuts only near deaths' share")
	_check(Roles.build_cost(10, &"carpenter") == 8 and Roles.build_cost(10, &"medic") == 10, "Carpenter builds at x0.8")
	_check(Roles.refusal(&"medic", "a", {"b": &"medic"}) == &"role_taken", "taken role refused")
	_check(Roles.refusal(&"medic", "a", {"a": &"medic"}) == &"" and Roles.refusal(&"", "a", {"b": &"medic"}) == &"", "own role and no role are open")
	_check(Roles.refusal(&"bogus", "a", {}) == &"unknown_role", "unknown role refused")



func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 20:
		Interactable = load("res://game/interaction/interactable.gd")
		Roles = load("res://game/player/roles.gd")
		_pure()
		var Game := root.get_node("Game")
		var Net := root.get_node("Net")
		Net.profiles[1] = {"uid": "a".repeat(32), "name": "h"}
		Net.profiles[-2] = {"uid": "b".repeat(32), "name": "bot"}
		Game.players[-2] = {}
		Roles.on_request(1, &"medic")
		_check(Roles.of(1) == &"medic", "host picked Medic in the barn")
		Roles.on_request(-2, &"medic")
		_check(Roles.of(-2) == &"", "second player refused Medic")
		Roles.on_request(-2, &"warden")
		_check(Roles.of(-2) == &"warden", "second player takes Warden")
		Game.in_lobby = false  # the match started
		Roles.on_request(1, &"farmer")
		_check(Roles.of(1) == &"medic", "role locked once the match starts")
		Game.players[1] = {"rejoin": true}  # a rejoin rebuilds the dictionary
		Roles.sync()
		_check(Roles.of(1) == &"medic", "a rejoiner keeps their role")
		_medic()
		print("test_roles: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
		quit(0 if _fails == 0 else 1)
	return false


## Medic: pries someone else free at x0.6, not themselves; the bill cut counts deaths within 15 m of a living Medic.
func _medic() -> void:
	var Game := root.get_node("Game")
	var reg: Node = load("res://game/interaction/hold_registry.gd").new()
	var race: Node = load("res://game/traps_player/trap_race.gd").new()
	var tgt: Node = load("res://game/traps_player/trap_target.gd").new()
	tgt.id = "t1"
	tgt.race = race
	race.races = {"t1": {"victim": -2}}
	_check(reg._mults(1, {"verb": &"pry", "target": tgt}) == [0.6], "Medic pries a teammate free x0.6")
	_check(reg._mults(-2, {"verb": &"pry", "target": tgt}) == [], "a non-Medic pries at normal speed")
	race.races.t1.victim = 1
	_check(reg._mults(1, {"verb": &"pry", "target": tgt}) == [], "a pinned Medic frees themselves at normal speed")
	for n in [reg, race, tgt]:
		n.free()
	Game.players[1].pos = Vector3.ZERO
	_check(Roles.medic_near(Vector3(10, 0, 0), -2), "a death 10 m from the Medic is near")
	_check(not Roles.medic_near(Vector3(20, 0, 0), -2), "a death 20 m away is not")
	_check(not Roles.medic_near(Vector3.ZERO, 1), "the Medic's own death does not cut the bill")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
