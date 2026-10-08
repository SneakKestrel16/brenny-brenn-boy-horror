extends Node
## Doc 05 section 12 / doc 02 section 14: the one generator and the fuel drum. Host-owned: fuel burns
## only at dusk and night (a full tank lasts `generator_tank_s`), `refuel` (4 s) and
## `repair_generator` (6 s) are holds, the drum is free (`fill_fuel`, 3 s, doc 01 "Nights"). A dead
## generator emits `generator_dead` once and every building goes dark (game/core/lights.gd); below the
## dim threshold the lights dim smoothly. Clients get `apply_generator` and drive their own lights.
## One run per night: the tank is full again at each new day (inference, doc 05 section 12 "one
## generator run"; settled by DD Phase 1 feel). Scrap for repairs is not in Phase 1 (no scrap items yet).

const Lights := preload("res://game/core/lights.gd")
const SYNC_EVERY_S := 1.0  ## while burning; changes are sent at once (placeholder)

var fuel_s := 0.0  ## authoritative on the host; mirrored on clients
var damaged := false
var tank_s := 210.0
var _farm: Node
var _since_sync := 0.0
var _dead_sent := false
var _log_gen := OS.get_cmdline_user_args().has("--log-farm")


## An Interactable on the generator body or the drum.
class Point extends "res://game/interaction/interactable.gd":
	var gen: Node
	var drum := false

	## `st` empty means unknown: offer the default verb. The drum hides while a can is in hand, and the
	## generator offers `refuel` only to someone carrying one (the prompt is the instruction).
	func verbs_for(st: Dictionary) -> Array[StringName]:
		var has_can := bool(st.get("fuel_can", false))
		var out: Array[StringName] = []
		if drum:
			if not has_can:
				out.append(&"fill_fuel")
		elif gen.damaged:
			out.append(&"repair_generator")
		elif has_can or st.is_empty():
			out.append(&"refuel")
		return out

	func can_start(verb: StringName, st: Dictionary) -> StringName:
		match verb:
			&"fill_fuel": return &"" if drum and not bool(st.get("fuel_can", false)) else &"has_fuel_can"
			&"refuel":
				if drum: return &"no_such_verb"
				if gen.damaged: return &"generator_damaged"
				if not bool(st.get("fuel_can", false)): return &"no_fuel_can"
				return &"" if gen.fuel_s < gen.tank_s else &"tank_full"
			&"repair_generator": return &"" if not drum and gen.damaged else &"not_damaged"
		return &"no_such_verb"

	func complete(verb: StringName, peer: int, st: Dictionary) -> void:
		match verb:
			&"fill_fuel": st.fuel_can = true
			&"refuel":
				st.fuel_can = false
				gen.add_fuel(gen.tank_s * float(Data.value(&"season", &"fuel_can_pct")) / 100.0)
			&"repair_generator":
				gen.repair()
				NoiseBus.emit_kind(&"tool_repair", target_pos(), peer)


func _ready() -> void:
	tank_s = float(Data.value(&"season", &"generator_tank_s"))
	fuel_s = tank_s
	_farm = get_tree().get_first_node_in_group(&"farm")
	for g in [[&"generator", "generator", false], [&"fuel_drum", "fuel_drum", true]]:
		for n in get_tree().get_nodes_in_group(g[0]):
			var p := Point.new()
			p.gen = self
			p.drum = g[2]
			p.id = g[1]
			p.farm = _farm
			n.add_child(p)
			p.add_pick_body(Vector3(2.0, 1.2, 2.0))
			_farm.targets[g[1]] = p
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
			if what == &"farm_state":
				Net.to_peers(&"apply_generator", [fuel_s, damaged], [peer]))
		Clock.day_changed.connect(func(_d: int) -> void:
			fuel_s = tank_s
			_dead_sent = false
			_changed())
	_apply_lights.call_deferred()
	if OS.get_cmdline_user_args().has("--autogen"):
		_autogen.call_deferred()


func powered() -> bool:
	return fuel_s > 0.0 and not damaged


func _physics_process(delta: float) -> void:
	if not Game.is_host():
		return
	if Clock.phase in [&"dusk", &"night"] and powered():
		fuel_s = maxf(fuel_s - delta, 0.0)
		if fuel_s <= 0.0:
			_went_dead(&"empty")
			return
		_since_sync += delta
		if _since_sync >= SYNC_EVERY_S:
			_changed()


## Host only.
func add_fuel(s: float) -> void:
	fuel_s = minf(fuel_s + s, tank_s)
	_dead_sent = false
	_changed()


## Host only: the creature (doc 03 "generator_kill") will call this; `--autogen` uses it today.
func damage() -> void:
	damaged = true
	_went_dead(&"damaged")


## Host only.
func repair() -> void:
	damaged = false
	_dead_sent = false
	_changed()


func _went_dead(why: StringName) -> void:
	if not _dead_sent:
		_dead_sent = true
		NoiseBus.emit_kind(&"generator_dead", (get_tree().get_first_node_in_group(&"generator") as Node3D).global_position, 0)
		Log.event(&"generator_dead", {"why": String(why)})
	_changed()


func _changed() -> void:
	_since_sync = 0.0
	Net.to_peers(&"apply_generator", [fuel_s, damaged])
	_on_apply(&"generator", [fuel_s, damaged])  # the host applies to itself


func _on_apply(what: StringName, args: Array) -> void:
	if what != &"generator":
		return
	fuel_s = float(args[0])
	damaged = bool(args[1])
	_apply_lights()
	if _log_gen:
		Log.event(&"generator_seen", {"fuel_s": snappedf(fuel_s, 1.0), "damaged": damaged, "powered": powered()})


func _apply_lights() -> void:
	Lights.apply(get_tree(), powered(), fuel_s / tank_s)


# --- QA script (`-- --autogen`) -----------------------------------------------------------------------
# Host: forces night with 12 s of fuel, waits for the client to refuel, then damages the generator.
# Client: fetches a can at the drum, refuels, then repairs once damaged. Needs a client (host alone ends).

func _autogen() -> void:
	if Game.is_host():
		Clock.phase = &"night"
		Clock.t_phase = 0.0
		fuel_s = 12.0
		_changed()
		var t := get_tree().create_timer(60.0)
		while t.time_left > 0.0 and not (fuel_s > 30.0):
			await get_tree().physics_frame
		await get_tree().create_timer(2.0).timeout
		damage()
		while t.time_left > 0.0 and damaged:
			await get_tree().physics_frame
		Log.event(&"autogen_done", {"fuel_s": snappedf(fuel_s, 1.0), "damaged": damaged})
		return
	var hc: Node = get_tree().current_scene.get_node("Players").player(Game.local_peer()).get_node("HoldController")
	await get_tree().create_timer(2.0).timeout
	await hc._do(&"fill_fuel", "fuel_drum", Vector3(-1.5, 0, 0), [Vector3(0, 0, -4), Vector3(0, 0, 4), Vector3(-14, 0, 4), Vector3(-14, 0, 24)])
	await hc._do(&"refuel", "generator", Vector3(-1.5, 0, 0), [Vector3(-14, 0, 24), Vector3(-14, 0, 4), Vector3(-14, 0, -6)])
	var t := get_tree().create_timer(60.0)
	while t.time_left > 0.0 and not damaged:
		await get_tree().physics_frame
	await hc._do(&"repair_generator", "generator", Vector3(-1.5, 0, 0))
	Log.event(&"autogen_done", {"fuel_s": snappedf(fuel_s, 1.0), "damaged": damaged})
