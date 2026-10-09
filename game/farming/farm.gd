extends Node
## Doc 05 sections 7 and 9: Phase 1 farm gameplay. Finds the plots, sell box and well in the world,
## attaches Interactables, owns coins (host) and replicates plot state and coins to every peer.
## Host: also runs the HoldRegistry. Client: pulls the full state once on load (`farm_state`), so a
## late joiner sees the same plots; later changes arrive as `plot_changed` / `money_changed`.

const Plot := preload("res://game/farming/plot.gd")
const Station := preload("res://game/farming/station.gd")
const Registry := preload("res://game/interaction/hold_registry.gd")
const Cans := preload("res://game/items/cans.gd")
const Crops := preload("res://game/farming/crops.gd")
const PrizePumpkin := preload("res://game/farming/prize_pumpkin.gd")
const Store := preload("res://game/items/store.gd")
const Cart := preload("res://game/items/cart.gd")

var targets: Dictionary = {}  ## id -> Interactable
var carry: Dictionary = {}  ## every peer: peer -> {can, bag, fuel_can}, replicated by `apply_carry`
var coins := 0 ## authoritative on the host; mirrored elsewhere
var final_extra := 0  ## host: medical bill the bank floor could not cover, added to the final payment (doc 02 s8)
var seed_pick: StringName = &""  ## this machine's chosen seed for field plots (`cycle_seed`); empty means the default seed
var free_scrap := 0  ## host: scrap handed out at the last dawn, spent by the store (P4-05; doc 02 s9 step 7)
var registry: Node
var cans: Cans  ## D-054: the physical watering and fuel cans
var store: Store  ## P4-06: the shipping crate's store
var cart: Cart  ## P4-12: the festival cart (full farm only, else null)
var _log_farm := OS.get_cmdline_user_args().has("--log-farm")
var headcount := 0  ## players at match start: fixes which `extra` plots are open (P2-14, D-039); host decides, clients are told
var _headcount_arg := _int_arg("--headcount=")  ## QA: host-only override for a no-lobby run (joiners arrive after the farm loads)


func _ready() -> void:
	add_to_group(&"farm")
	for m in get_tree().get_nodes_in_group(&"plot_spots"):
		var p := Plot.new()
		# Phase 1: all plots open (the upgrade row was unplantable at the playtest). The full farm
		# (--full-farm) keeps the `upgrade` plots locked until the shop sells them (P2-06).
		p.locked = Game.full_farm and (bool(m.get_meta(&"upgrade", false)) or bool(m.get_meta(&"extra", false)))
		_attach(m, p, String(m.name), Vector3(2.8, 0.3, 2.8))
	for g in [[&"sell_box", &"sell", "sell_box"], [&"well", &"well", "well"]]:
		for n in get_tree().get_nodes_in_group(g[0]):
			var s := Station.new()
			s.kind = g[1]
			_attach(n, s, g[2], Vector3(2.0, 1.0, 2.0))
	for n in get_tree().get_nodes_in_group(&"pumpkin_patch"):  # P4-05: the Prize Pumpkin
		_attach(n, PrizePumpkin.new(), "prize_pumpkin", Vector3(3.0, 2.0, 3.0))
	var world := get_node_or_null(^"../World")
	var cart_body := Cart.build(world) if world else null
	if cart_body:
		cart = Cart.new()
		_attach(cart_body, cart, "cart", Vector3(1.8, 1.5, 3.0))
	cans = Cans.new()
	cans.farm = self
	add_child(cans)
	store = Store.new()
	store.farm = self
	add_child(store)
	Net.request_received.connect(_on_request)
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		registry = Registry.new()
		registry.farm = self
		registry.name = "HoldRegistry"
		add_child(registry)
		var loaded := not Save.pending.is_empty()  # P4-10: a saved season keeps its match-start headcount and its coins
		_set_headcount(int(Save.pending.headcount) if loaded else (_headcount_arg if _headcount_arg > 0 else Game.player_count()))
		if not loaded:
			add_coins(int(Data.value(&"season", &"start_coins")), &"start_coins", 0)  # doc 01 Season and Numbers; seeds cost coins (P4-04)
		Clock.day_changed.connect(func(_d: int) -> void: advance_day())
		Clock.phase_changed.connect(func(ph: StringName) -> void:
			for t in targets.values():
				if t.has_method(&"on_phase"):
					t.on_phase(ph))
		Game.player_left.connect(func(p: int) -> void: registry.cancel(p, &"left", false))
	else:
		Net.to_host(&"request_farm_state")


func _int_arg(prefix: String) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return int(a.trim_prefix(prefix))
	return 0


## D-039: `extra` plots open when the match-start headcount reaches their `min_players`, in `_extra_key` order,
## up to player_scaling.json `field_plots_start_by_players` minus the 4-player start (QA-check-2026-10-09: 5p opens
## 2 of the 8, 6p opens 4). The bought-plot ceiling for the store is `plot_ceiling()`
## (player_scaling.json, not season.json); the store's `plot_pair` reads it (P4-06).
func _set_headcount(n: int) -> void:
	headcount = n
	var starts: Dictionary = Data.record(&"player_scaling", &"headcount").get("field_plots_start_by_players", {})
	var allowed := int(starts.get(str(clampi(n, 2, Game.max_players())), 16)) - int(starts.get("4", 16))
	var extras: Array = []
	for m in get_tree().get_nodes_in_group(&"plot_spots"):
		if targets.get(String(m.name)) is Plot and bool(m.get_meta(&"extra", false)) and Game.full_farm:
			extras.append(m)
	extras.sort_custom(func(a, b): return _extra_key(a) < _extra_key(b))
	var open := 0
	for m in extras:
		var t: Plot = targets[String(m.name)]
		t.locked = n < int(m.get_meta(&"min_players", 99)) or open >= allowed
		t._refresh()
		open += int(not t.locked)
	Log.event(&"plots_open", {"headcount": n, "extras_open": open, "ceiling": plot_ceiling()})


## Opening order: lowest `min_players`, then `extra_order` (inner plots first), then name, so fields A and B alternate.
func _extra_key(m: Node) -> Array:
	return [int(m.get_meta(&"min_players", 99)), int(m.get_meta(&"extra_order", 0)), String(m.name)]


func plot_ceiling() -> int:
	var t: Dictionary = Data.record(&"player_scaling", &"headcount").get("field_plots_max_by_players", {})
	return int(t.get(str(clampi(headcount, 2, Game.max_players())), 24))


func _attach(world_node: Node, it: Node, id: String, pick: Vector3) -> void:
	it.id = id
	it.farm = self
	world_node.add_child(it)
	it.add_pick_body(pick)
	targets[id] = it


## Host: the per-player chore state lives next to the move state in `Game.players[peer]`.
func pstate(peer: int) -> Dictionary:
	var st: Dictionary = Game.players.get(peer, {})
	if not st.has("can"):
		st.can = 0  # D-054: nobody starts with a can; they pick one up (cans.gd)
		st.held_can = -1
		st.held_kind = &""
		st.bag = 0
		Game.players[peer] = st
	st.peer = peer  # P4-06: a verb's `can_start` may need to know whose state it is
	return st


## Client: `cycle_seed` picks the next day crop on sale today for field plots. Local only; the pick travels
## inside the `plant:<crop>` hold request and the host re-checks it (plot.gd `can_start`).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"cycle_seed") or Game.console_open:
		return
	var seeds := Crops.seeds(Clock.day)
	if seeds.is_empty():
		return
	seed_pick = seeds[(seeds.find(seed_pick if seed_pick != &"" else Crops.default_seed()) + 1) % seeds.size()]
	Log.event(&"seed_picked", {"crop": String(seed_pick)})


func advance_day() -> void:
	for t in targets.values():
		if t.has_method(&"advance_day"):
			t.advance_day()


func add_coins(n: int, reason: StringName, peer: int) -> void:  # peer 0: the team (bill), logged as null
	coins += n
	Log.event(&"money_changed", {"coins": coins, "balance": coins, "delta": n, "reason": String(reason), "player": peer if peer != 0 else null})  # bots are negative (P4-18)
	_broadcast(&"money_changed", [coins])


## Host: the shovel and bear trap in `peer`'s hands (P2-11); the cans and bag go out as `carry`.
func set_hands(peer: int, shovel: bool, trap: bool) -> void:
	var st := pstate(peer)
	st.shovel = shovel
	st.trap = trap
	_broadcast(&"hands", [peer, shovel, trap])


## Host: tell every peer what `peer` now carries.
func send_carry(peer: int) -> void:
	cans.store(peer)
	var st := pstate(peer)
	_broadcast(&"carry", [peer, int(st.can), int(st.bag), bool(st.get("fuel_can", false))])


func plot_changed(p: Node) -> void:
	_broadcast(&"plot_changed", [p.id, p.wire_state(), p.watered, p.age])


func _broadcast(what: StringName, args: Array) -> void:
	Net.to_peers(StringName("apply_" + what), args)
	Net.apply_received.emit(what, args)  # host applies to itself


func _on_request(what: StringName, peer: int, args: Array) -> void:
	if not Game.is_host():
		return
	match what:
		&"hold": registry.request(peer, args[0], args[1])
		&"hold_cancel": registry.cancel(peer, &"released", false)  # the client already ended it: no stale reply
		&"farm_state":
			Net.to_peers(&"apply_money_changed", [coins], [peer])
			Net.to_peers(&"apply_headcount", [headcount], [peer])
			cans.snapshot_to(peer)
			if targets.has("prize_pumpkin"):
				targets["prize_pumpkin"].snapshot_to(peer)
			if cart:
				cart.snapshot_to(peer)
			for p in Game.players:
				var cs := pstate(p)
				Net.to_peers(&"apply_carry", [p, int(cs.can), int(cs.bag), bool(cs.get("fuel_can", false))], [peer])
			for p in Game.players:
				var hs := pstate(p)
				Net.to_peers(&"apply_hands", [p, bool(hs.get("shovel", false)), bool(hs.get("trap", false))], [peer])
			for t in targets.values():
				if t is Plot:
					Net.to_peers(&"apply_plot_changed", [t.id, t.wire_state(), t.watered, t.age], [peer])


func _on_apply(what: StringName, args: Array) -> void:
	if _log_farm and what in [&"plot_changed", &"money_changed"]:  # QA: what this machine sees
		Log.event(&"farm_seen", {"what": String(what), "args": args.map(func(a: Variant) -> Variant: return str(a) if a is StringName else a)})
	match what:
		&"carry":
			var old: Dictionary = carry.get(args[0], {})
			carry[args[0]] = {"can": args[1], "bag": args[2], "fuel_can": args[3],
					"shovel": old.get("shovel", false), "trap": old.get("trap", false),
					"held_can": old.get("held_can", -1), "held_kind": old.get("held_kind", &"")}
		&"hands":
			var c: Dictionary = carry.get(args[0], {"can": 0, "bag": 0, "fuel_can": false})
			c.shovel = args[1]
			c.trap = args[2]
			carry[args[0]] = c
		&"cans": cans.apply(args[0])
		&"death":
			if Game.is_host():
				cans.drop.call_deferred(args[0])  # the dead put the can down where they fell (D-054)
			if Game.is_host() and Game.players.has(args[0]):  # the dead drop the shovel and trap (placeholder: they vanish)
				var ds := pstate(args[0])
				if ds.get("shovel", false) or ds.get("trap", false):
					set_hands.call_deferred(args[0], false, false)
		&"money_changed": coins = int(args[0])
		&"headcount": _set_headcount(int(args[0]))
		&"plot_changed":
			if not Game.is_host() and targets.has(args[0]):
				targets[args[0]].apply_state(args[1], args[2], args[3])
			elif targets.has(args[0]):
				targets[args[0]]._refresh()
