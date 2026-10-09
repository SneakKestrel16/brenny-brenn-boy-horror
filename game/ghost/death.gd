extends Node
## Doc 05 section 14, doc 03 section 8 (death rules): the host decides a death (`die`), every peer applies
## it the same way: the player becomes a ghost (`Game.players[peer].ghost`), a body is left where they fell
## (`bodies` group, for carrying later), and the Player node switches to spectating. A ghost comes back at
## dawn at the spawn point. Ghost powers (lights, crow, rustle, ghost vision) are the GhostPowers child (P3-09).
## Not built yet: the body as a carried thing.

const GhostPowersScript := preload("res://game/ghost/ghost_powers.gd")
const Crops := preload("res://game/farming/crops.gd")
const RESPAWN_TEST_S := 10.0  ## `--creature-test` only: nights repeat without a real dawn, so QA respawns after 10 s

var _creature: Node
var _dead: Dictionary = {}  ## every peer: peer -> {cause, position, body}
var _test := OS.get_cmdline_user_args().has("--creature-test")
var _respawn_at: Dictionary = {}  ## host: peer -> msec
var _bill_deaths := 0  ## host: deaths since the last dawn bill


func _ready() -> void:
	add_to_group(&"death")
	var powers := GhostPowersScript.new()  # P3-09: what a ghost can do
	powers.name = "GhostPowers"
	add_child(powers)
	Net.apply_received.connect(_on_apply)
	Game.player_left.connect(func(p: int) -> void: _dead.erase(p))
	if Game.is_host():  # D-048: a roster player back in a running match is a ghost until dawn
		Game.player_joined.connect(func(p: int) -> void:
			if Game.players.get(p, {}).get("rejoin", false):
				die(p, &"reconnect"))
	if not Game.is_host():
		return
	_creature = get_parent().get_node("Creature")
	_creature.caught.connect(func(p: int) -> void:
		if not get_parent().get_node("TrapRace").victims.values().has(p):  # a pinned player dies by the race clock
			die(p, &"night_chase"))
	Clock.phase_changed.connect(func(ph: StringName) -> void:
		if ph == &"dawn":
			dawn())
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what == &"farm_state":  # a late joiner learns who is already dead
			for p in _dead:
				Net.to_peers(&"apply_death", [p, _dead[p].cause, _dead[p].position], [peer]))


## Host only. Idempotent.
func die(peer: int, cause: StringName) -> void:
	var st: Dictionary = Game.players.get(peer, {})
	if st.is_empty() or Game.is_ghost(peer):
		return
	st.pinned = false
	var rejoin := cause == &"reconnect"  # D-048: not a death: no medical bill, and the body waits at the barn spawn
	if not rejoin:
		_bill_deaths += 1  # day deaths count toward the next dawn (doc 02 s8)
	var pos: Vector3 = _spawn_pos(peer) if rejoin else st.get("pos", Vector3.ZERO)
	get_parent().get_node("Farm").registry.cancel(peer, &"dead")
	Log.event(&"death", {"player": peer, "cause": String(cause), "position": [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)],
			"phase": String(Clock.phase), "body_id": "body_%d" % peer})
	Net.to_peers(&"apply_death", [peer, cause, pos])
	Net.apply_received.emit(&"death", [peer, cause, pos])
	if _test:
		_respawn_at[peer] = Time.get_ticks_msec() + int(RESPAWN_TEST_S * 1000.0)


func _physics_process(_delta: float) -> void:
	if _respawn_at.is_empty():
		return
	for p in _respawn_at.keys():
		if Time.get_ticks_msec() >= _respawn_at[p]:
			_respawn_at.erase(p)
			respawn(p)


## Doc 02 s8: `first_4p` for the first death, `later_4p` for each other, capped at `cap_4p`; all three scaled
## to the headcount at the billing dawn (ceil, `player_scaling`).
func bill_for(deaths: int) -> int:
	if deaths <= 0:
		return 0
	var first := Data.scaled(int(Data.value(&"medical_bill", &"bill", &"first_4p")), &"bill")
	var later := Data.scaled(int(Data.value(&"medical_bill", &"bill", &"later_4p")), &"bill")
	var cap := Data.scaled(int(Data.value(&"medical_bill", &"bill", &"cap_4p")), &"bill")
	return mini(first + later * (deaths - 1), cap)


## Doc 02 s9, the dawn order. Each name runs `step_<name>(farm)` and logs `dawn_step` first. P4-07 fills
## `payment`, P4-10 fills `save`; they slot in without reordering. tests/gameplay/test_season.gd checks it.
const DAWN_STEPS: Array[StringName] = [&"cash_in", &"final_sale", &"medical_bill", &"payment", &"farm_damage", &"save", &"free_scrap"]

var _dawn := {}  ## host: this dawn's numbers, gathered by the steps and read by `dawn_summary`


## Host only. Runs the steps in order, then the respawn at the barn, then `dawn_summary`.
func dawn() -> void:
	var farm: Node = get_parent().get_node("Farm")
	var final := Clock.day >= int(Data.value(&"season", &"season_days"))
	_dawn = {"deaths": _bill_deaths, "bill": 0, "wilted": 0}
	_bill_deaths = 0
	for s in DAWN_STEPS:
		Log.event(&"dawn_step", {"step": String(s), "day": Clock.day})
		call(StringName("step_" + s), farm, final)
	for p in _dead.keys():
		respawn(p)
	var ripe := 0
	for t in farm.targets.values():
		if t.get("state") == &"ripe":
			ripe += 1
	var sab := get_tree().get_first_node_in_group(&"sabotage")  # P3-06: crops trampled this dawn, in coins
	Log.event(&"dawn_summary", {"day": Clock.day, "coins": farm.coins, "debt": 0, "plots_ripe": ripe,  # debt: P4-07
			"plots_wilted": _dawn.wilted, "farm_damage": sab.farm_damage if sab else 0, "deaths": _dawn.deaths,
			"medical_bill": _dawn.bill, "final_extra": farm.final_extra, "final": final})


## Step 1: the living sell what they carry at full price, the dead lose it.
func step_cash_in(farm: Node, _final: bool) -> void:
	for p in Game.players.keys():
		var st: Dictionary = farm.pstate(p)
		var bag := int(st.bag)
		var value := Crops.bag_value(st)
		Crops.bag_clear(st)
		if Game.is_ghost(p):
			if bag > 0 or st.get("fuel_can", false):
				Log.event(&"carried_lost", {"player": p, "bag": bag})
			st.fuel_can = false
		elif bag > 0:
			farm.add_coins(value, &"dawn_cash_in", p)
		farm.send_carry(p)


## Step 2, final dawn only: crops in the ground sell at `end_season_sale_pct` (a crop that wilts at dawn is
## worth nothing). The festival payout is P4-09's (the cart), added here when it lands.
func step_final_sale(farm: Node, final: bool) -> void:
	if not final:
		return
	if farm.targets.has("prize_pumpkin"):
		farm.targets["prize_pumpkin"].judge(farm)  # P4-05: size sets the payout; P4-12 moves this to the cart
	var total := 0
	var plots := 0
	for t in farm.targets.values():
		if t.has_method(&"sell_value") and t.sell_value() > 0 and not bool(Crops.rec(t.crop).get("wilts_at_dawn", false)):
			var v: int = t.sell_value()
			if v > 0:
				total += v
				plots += 1
	total = Data.scale_pct(total, int(Data.value(&"season", &"end_season_sale_pct")), true)  # nearest coin
	Log.event(&"end_of_season_sale", {"plots": plots, "coins": total})
	if total > 0:
		farm.add_coins(total, &"end_of_season_sale", 0)


## Step 3: the medical bill (doc 02 s8).
func step_medical_bill(farm: Node, _final: bool) -> void:
	var deaths: int = _dawn.deaths
	var bill := bill_for(deaths)
	var paid := clampi(farm.coins - int(Data.value(&"season", &"bank_floor")), 0, bill)  # the bank never drops below the floor
	if paid > 0:
		farm.add_coins(-paid, &"medical_bill", 0)
	farm.final_extra += bill - paid
	_dawn.bill = bill
	if bill > 0:
		Log.event(&"medical_bill", {"deaths": deaths, "bill": bill, "paid": paid, "to_final": bill - paid, "players": Game.player_count()})
	var animals := get_tree().get_first_node_in_group(&"animals")  # P4-08: animals out at dusk, billed after the medical bill (doc 02 s10.1)
	if animals:
		animals.bill_dusk(farm)


## Step 4: payment due and early payment (doc 02 s7). P4-07.
func step_payment(_farm: Node, _final: bool) -> void:
	pass


## Step 5: farm damage. Night crops wilt first (doc 01 Crops); then the creature's trample. The AI Director's
## Sabotage still tramples on its own dawn hook, before step 1 (Q-086); once it exposes `dawn_trample()` this
## step calls it and the order is doc 02 s9's.
func step_farm_damage(farm: Node, _final: bool) -> void:
	for t in farm.targets.values():
		if t.has_method(&"dawn_wilt") and t.dawn_wilt():
			_dawn.wilted += 1
	var sab := get_tree().get_first_node_in_group(&"sabotage")
	if sab and sab.has_method(&"dawn_trample"):
		sab.dawn_trample()


## Step 6: save (doc 01 Saving). P4-10.
func step_save(_farm: Node, _final: bool) -> void:
	pass


## Step 7: the free scrap each dawn (doc 02 s10): it does not stack unless `free_scrap_stacks`. The store (P4-05)
## spends it; the flare gun refill (P4-09) joins here.
func step_free_scrap(farm: Node, _final: bool) -> void:
	var n := int(Data.value(&"season", &"free_scrap_per_dawn"))
	farm.free_scrap = farm.free_scrap + n if bool(Data.value(&"season", &"free_scrap_stacks")) else maxi(farm.free_scrap, n)
	Log.event(&"free_scrap", {"scrap": farm.free_scrap})


## Host only: the ghost walks again at its barn spawn (the same slot as at the start).
func respawn(peer: int) -> void:
	if not _dead.has(peer) or not Game.players.has(peer):
		return
	var pos := _spawn_pos(peer)
	var st: Dictionary = Game.players[peer]
	st.freeze_until = Time.get_ticks_msec() + 300  # frames from before the teleport are dropped
	st.pos = pos
	Log.event(&"respawn", {"player": peer, "phase": String(Clock.phase)})
	Net.to_peers(&"apply_respawn", [peer, pos])
	Net.apply_received.emit(&"respawn", [peer, pos])


func _on_apply(what: StringName, args: Array) -> void:
	if what == &"death":
		_apply_death(args[0], args[1], args[2])
	elif what == &"respawn":
		_apply_respawn(args[0], args[1])


func _apply_death(peer: int, cause: StringName, pos: Vector3) -> void:
	if _dead.has(peer):
		return
	if Game.players.has(peer):
		Game.players[peer].ghost = true
	var body := MeshInstance3D.new()  # placeholder body: a lying capsule
	var m := CapsuleMesh.new()
	m.radius = 0.3
	m.height = 1.7
	body.mesh = m
	body.name = "body_%d" % peer
	body.add_to_group(&"bodies")
	get_parent().add_child(body)
	body.global_position = pos + Vector3(0, 0.3, 0)
	body.rotation.z = PI / 2.0
	_dead[peer] = {"cause": cause, "position": pos, "body": body}
	if not Game.is_host():
		Log.event(&"death_seen", {"player": peer, "cause": String(cause)})  # QA: the client also applied it
	var pl := _player(peer)
	if pl:
		pl.become_ghost()


## The barn spawn marker for `peer`'s slot (the same one as at the start).
func _spawn_pos(peer: int) -> Vector3:
	var spawns := get_tree().get_nodes_in_group(&"player_spawns")
	if spawns.is_empty():
		return Vector3.ZERO
	return (spawns[maxi(Game.players.keys().find(peer), 0) % spawns.size()] as Node3D).global_position


func _apply_respawn(peer: int, pos: Vector3) -> void:
	if not _dead.has(peer):
		return
	if Game.players.has(peer):
		Game.players[peer].ghost = false
	if not Game.is_host():
		Log.event(&"respawn_seen", {"player": peer})
	_dead[peer].body.queue_free()
	_dead.erase(peer)
	var pl := _player(peer)
	if pl:
		pl.respawn(pos)


func _player(peer: int) -> Node:
	return get_parent().get_node("Players").player(peer)
