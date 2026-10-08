extends Node
## Doc 05 sections 7 and 9: Phase 1 farm gameplay. Finds the plots, sell box and well in the world,
## attaches Interactables, owns coins (host) and replicates plot state and coins to every peer.
## Host: also runs the HoldRegistry. Client: pulls the full state once on load (`farm_state`), so a
## late joiner sees the same plots; later changes arrive as `plot_changed` / `money_changed`.

const Plot := preload("res://game/farming/plot.gd")
const Station := preload("res://game/farming/station.gd")
const Registry := preload("res://game/interaction/hold_registry.gd")

var targets: Dictionary = {}  ## id -> Interactable
var carry: Dictionary = {}  ## every peer: peer -> {can, bag, fuel_can}, replicated by `apply_carry`
var coins := 0 ## authoritative on the host; mirrored elsewhere
var registry: Node
var _log_farm := OS.get_cmdline_user_args().has("--log-farm")


func _ready() -> void:
	add_to_group(&"farm")
	for m in get_tree().get_nodes_in_group(&"plot_spots"):
		var p := Plot.new()
		p.locked = false  # Phase 1: all 12 plots open (doc 04 section 4 "switched on"); the upgrade row was unplantable at the playtest
		_attach(m, p, String(m.name), Vector3(2.8, 0.3, 2.8))
	for g in [[&"sell_box", &"sell", "sell_box"], [&"well", &"well", "well"]]:
		for n in get_tree().get_nodes_in_group(g[0]):
			var s := Station.new()
			s.kind = g[1]
			_attach(n, s, g[2], Vector3(2.0, 1.0, 2.0))
	Net.request_received.connect(_on_request)
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		registry = Registry.new()
		registry.farm = self
		registry.name = "HoldRegistry"
		add_child(registry)
		Clock.day_changed.connect(func(_d: int) -> void: advance_day())
		Game.player_left.connect(func(p: int) -> void: registry.cancel(p, &"left", false))
	else:
		Net.to_host(&"request_farm_state")


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
		st.can = int(Data.value(&"labor", &"can", &"capacity"))  # starts full (Phase 1)
		st.bag = 0
		Game.players[peer] = st
	return st


func advance_day() -> void:
	for t in targets.values():
		if t.has_method(&"advance_day"):
			t.advance_day()


func add_coins(n: int, reason: StringName, peer: int) -> void:
	coins += n
	Log.event(&"money_changed", {"coins": coins, "delta": n, "reason": String(reason), "player": peer})
	_broadcast(&"money_changed", [coins])


## Host: tell every peer what `peer` now carries.
func send_carry(peer: int) -> void:
	var st := pstate(peer)
	_broadcast(&"carry", [peer, int(st.can), int(st.bag), bool(st.get("fuel_can", false))])


func plot_changed(p: Node) -> void:
	_broadcast(&"plot_changed", [p.id, p.state, p.watered, p.age])


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
			for p in Game.players:
				var cs := pstate(p)
				Net.to_peers(&"apply_carry", [p, int(cs.can), int(cs.bag), bool(cs.get("fuel_can", false))], [peer])
			for t in targets.values():
				if t is Plot:
					Net.to_peers(&"apply_plot_changed", [t.id, t.state, t.watered, t.age], [peer])


func _on_apply(what: StringName, args: Array) -> void:
	if _log_farm and what in [&"plot_changed", &"money_changed"]:  # QA: what this machine sees
		Log.event(&"farm_seen", {"what": String(what), "args": args.map(func(a: Variant) -> Variant: return str(a) if a is StringName else a)})
	match what:
		&"carry": carry[args[0]] = {"can": args[1], "bag": args[2], "fuel_can": args[3]}
		&"money_changed": coins = int(args[0])
		&"plot_changed":
			if not Game.is_host() and targets.has(args[0]):
				targets[args[0]].apply_state(args[1], args[2], args[3])
			elif targets.has(args[0]):
				targets[args[0]]._refresh()
