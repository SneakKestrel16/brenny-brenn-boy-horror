extends Node
## Doc 06 sections 2, 5 and 7: ENet transport, host and join, the join handshake, roster, and every
## RPC (doc 05 section 22: no `rpc()` outside `game/net/`). Session state stays in `Game`; this node
## sends it. Join is by raw IP[:port] only (D-024: friends join over Tailscale); join codes and UPnP
## stay in spikes/voice/ until a task asks for them.
##
## Not built yet (doc 06): request_join / apply_join_accepted / apply_join_refused (build id, full
## farm), slots, player_uid, host-left card, peer timeouts, rtt_ms, the --net-sim-* queue. Add each
## with the task that first needs it.

const DEFAULT_PORT := 45120  ## doc 06 section 2; 45121..45124 if taken locally
const PORT_TRIES := 4
const MAX_CLIENTS := 4  ## one more than allowed, to say "the farm is full" (doc 06 section 2)
const CHANNELS := 4  ## CONTRACTS section 7
const CONNECT_TIMEOUT_S := 10.0  ## placeholder

## A `send_bytes` packet arrived (doc 06 section 2: byte 0 is the message type). Added in P1-04.
signal bytes_received(from_peer: int, packet: PackedByteArray)
## The host sent `apply_teleport` (doc 06 section 7). Added in P1-04.
signal teleport_received(position: Vector3)

var port := 0  ## the port actually opened (host) or dialled (client)
var _join_target := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	(multiplayer as SceneMultiplayer).peer_packet.connect(func(id: int, packet: PackedByteArray) -> void:
		bytes_received.emit(id, packet))


## Host only. Opens the ENet server, trying the next ports if one is taken (doc 06 section 2).
func host(p_port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	# max_channels stays 0: Godot 4.7.2 create_server shifts its arguments (doc 06 section 2, PP-02).
	var err := peer.create_server(p_port, MAX_CLIENTS)
	var tries := 0
	while err != OK and tries < PORT_TRIES:
		tries += 1
		p_port += 1
		err = peer.create_server(p_port, MAX_CLIENTS)
	if err != OK:
		push_error("Net: could not open UDP port %d: %s" % [p_port, error_string(err)])
		return err
	_use(peer)
	port = p_port
	return OK


## Client. `address` is `ip` or `ip:port` (IPv6 literals take the default port).
func join(address: String, default_port: int = DEFAULT_PORT) -> Error:
	var ip := address
	port = default_port
	if address.count(":") == 1:
		ip = address.get_slice(":", 0)
		port = int(address.get_slice(":", 1))
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, CHANNELS)
	if err != OK:
		push_error("Net: could not start connecting to %s:%d: %s" % [ip, port, error_string(err)])
		return err
	_use(peer)
	_join_target = "%s:%d" % [ip, port]
	get_tree().create_timer(CONNECT_TIMEOUT_S).timeout.connect(func() -> void:
		if not Game.in_session:
			push_error("Net: no session_state from %s within %d s" % [_join_target, int(CONNECT_TIMEOUT_S)]))
	return OK


## Host to clients: calls the `apply_*` RPC `method` on this node. `targets` empty means every peer.
## The one place channel-0 sends leave this machine (doc 06 section 14); a no-op with no peers.
func to_peers(method: StringName, args: Array = [], targets: Array = []) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	if targets.is_empty():
		callv(&"rpc", [method] + args)
		return
	for id in targets:
		callv(&"rpc_id", [id, method] + args)


## Raw packet on `channel` (doc 06 section 2: movement 1 unreliable ordered, voice 2 unreliable).
## `peer` 0 means every peer. A no-op with no peers, or when `peer` is mid-disconnect (PP-02: sending
## then prints "Unable to send packet"). Added in P1-04; the net-sim queue is still P1-later.
func send_bytes(peer: int, packet: PackedByteArray, channel: int = 1) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	if peer != 0 and not _connected(peer):
		return
	var mode := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE if channel == 2 else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	(multiplayer as SceneMultiplayer).send_bytes(packet, peer, mode, channel)


func _connected(peer: int) -> bool:
	var e := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var pp: ENetPacketPeer = e.get_peer(peer) if e else null
	return pp != null and pp.get_state() == ENetPacketPeer.STATE_CONNECTED


## Doc 06 section 2: both ends pin ENet's RTT throttle, or one slow round trip drops voice for seconds
## (PP-02: a forced 300 ms hitch lost 4 and 13 frames with the default, 0 and 0 pinned).
func _pin_throttle(peer: int) -> void:
	var e := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var pp: ENetPacketPeer = e.get_peer(peer) if e else null
	if pp:
		pp.throttle_configure(5000, 2, 0)  # ENet default (5000, 2, 2)


func _use(peer: ENetMultiplayerPeer) -> void:
	# Star topology: clients only talk to the host (doc 06 section 2, D-010).
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer


# --- Host side ----------------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	_pin_throttle(id)
	if not Game.is_host():
		return
	Game.players[id] = {}
	to_peers(&"apply_session_state", [Game.session_id, Log.now(), Data.phase1, Data.hash_value, Game.difficulty], [id])
	to_peers(&"apply_roster", [Game.players.keys()])
	to_peers(&"apply_clock", [Clock.day, Clock.phase, Clock.t_phase], [id])
	Log.event(&"player_joined", {"player": id})
	Game.player_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if not Game.is_host():
		return
	Game.players.erase(id)
	to_peers(&"apply_roster", [Game.players.keys()])
	Log.event(&"player_left", {"player": id})
	Game.player_left.emit(id)


# --- Client side --------------------------------------------------------------------------------

func _on_connected_to_server() -> void:
	_pin_throttle(1)
	Log.event(&"net_connected", {"target": _join_target})


func _on_connection_failed() -> void:
	push_error("Net: connection to %s failed" % _join_target)


func _on_server_disconnected() -> void:
	Log.event(&"net_server_disconnected")
	Game.in_session = false
	multiplayer.multiplayer_peer = null


# --- RPCs (doc 06 section 7); handlers live in the owning autoload -------------------------------

@rpc("authority", "call_remote", "reliable")
func apply_session_state(p_session_id: String, host_t: float, p_phase1: bool, data_hash: int, p_difficulty: StringName) -> void:
	Game.apply_session_state(p_session_id, host_t, p_phase1, data_hash, p_difficulty)


@rpc("authority", "call_remote", "reliable")
func apply_roster(peers: Array) -> void:
	Game.apply_roster(peers)


@rpc("authority", "call_remote", "reliable")
func apply_clock(p_day: int, p_phase: StringName, t: float) -> void:
	Clock.apply_clock(p_day, p_phase, t)


@rpc("authority", "call_remote", "reliable")
func apply_teleport(position: Vector3) -> void:
	teleport_received.emit(position)


# --- Holds and farming (doc 05 section 7, doc 06 section 7); added in P1-05 ----------------------
# Deviation from doc 06's per-verb `request_<verb>`: one `request_hold(verb, target)` carries every
# verb (inference: the table lists the same shape for each; settled when the Network & Voice
# Programmer wants per-verb names).

## Host-side requests: (`hold` | `hold_cancel` | `farm_state`, sender peer, args).
signal request_received(what: StringName, peer: int, args: Array)
## Client-side results: (`refused` | `hold_cancelled` | `hold_done` | `plot_changed` | `money_changed`, args).
signal apply_received(what: StringName, args: Array)


## Client to host; the host calls its own handler directly (sender 0 means the host itself).
func to_host(method: StringName, args: Array = []) -> void:
	if Game.is_host():
		callv(method, args)
	elif multiplayer.has_multiplayer_peer():
		callv(&"rpc_id", [1, method] + args)


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return 1 if s == 0 else s


@rpc("any_peer", "call_remote", "reliable")
func request_hold(verb: StringName, target: String) -> void:
	request_received.emit(&"hold", _sender(), [verb, target])


@rpc("any_peer", "call_remote", "reliable")
func request_hold_cancel() -> void:
	request_received.emit(&"hold_cancel", _sender(), [])


@rpc("any_peer", "call_remote", "reliable")
func request_farm_state() -> void:
	request_received.emit(&"farm_state", _sender(), [])


@rpc("authority", "call_remote", "reliable")
func apply_refused(verb: StringName, reason: StringName) -> void:
	apply_received.emit(&"refused", [verb, reason])


@rpc("authority", "call_remote", "reliable")
func apply_hold_cancelled(verb: StringName, reason: StringName) -> void:
	apply_received.emit(&"hold_cancelled", [verb, reason])


@rpc("authority", "call_remote", "reliable")
func apply_hold_done(verb: StringName, target: String) -> void:
	apply_received.emit(&"hold_done", [verb, target])


@rpc("authority", "call_remote", "reliable")
func apply_plot_changed(id: String, state: StringName, watered: bool, age: int) -> void:
	apply_received.emit(&"plot_changed", [id, state, watered, age])


@rpc("authority", "call_remote", "reliable")
func apply_money_changed(coins: int) -> void:
	apply_received.emit(&"money_changed", [coins])


## Host to all: what `peer` carries (watering can charges, turnips, fuel can). Players show it in hand.
@rpc("authority", "call_remote", "reliable")
func apply_carry(peer: int, can: int, bag: int, fuel_can: bool) -> void:
	apply_received.emit(&"carry", [peer, can, bag, fuel_can])


# --- Generator (doc 05 section 12); added in P1-07 ------------------------------------------------

## Host to clients: tank seconds left and whether the generator is damaged (lights follow both).
@rpc("authority", "call_remote", "reliable")
func apply_generator(fuel_s: float, damaged: bool) -> void:
	apply_received.emit(&"generator", [fuel_s, damaged])


# --- Creature (doc 03 section 4, doc 06 section 7); added in P1-08 -------------------------------

## Host to all on change: the creature's state (lurk, lure, stalk, chase, retreat) and body id.
@rpc("authority", "call_remote", "reliable")
func apply_creature_state(state: StringName, body: StringName) -> void:
	apply_received.emit(&"creature_state", [state, body])


## Host to the target (day) or all (night, target_slot -1): play a lure at `position` (doc 03 section 12).
@rpc("authority", "call_remote", "reliable")
func apply_lure(lure_id: String, source: String, position: Vector3, target_slot: int, tell: StringName, ghost: bool) -> void:
	apply_received.emit(&"lure", [lure_id, source, position, target_slot, tell, ghost])


# --- Traps, death and ghosts (doc 05 sections 11 and 14, doc 06 section 7); added in P1-09 -------------

## Host to all: a trap changed (`sprung`, `disarmed`). Set traps are never sent: they are hidden (doc 01 "Night Traps").
@rpc("authority", "call_remote", "reliable")
func apply_trap_changed(trap_id: String, kind: StringName, state: StringName, position: Vector3) -> void:
	apply_received.emit(&"trap_changed", [trap_id, kind, state, position])


## Host to all: `victim` is pinned in `trap_id` and has `deadline_s` seconds (doc 03 section 7).
@rpc("authority", "call_remote", "reliable")
func apply_trap_race(victim: int, trap_id: String, deadline_s: float, start_distance_m: float) -> void:
	apply_received.emit(&"trap_race", [victim, trap_id, deadline_s, start_distance_m])


## Host to the freed player: slow walk for `seconds` (doc 01 "Night Traps": 40% slower for 60 s).
@rpc("authority", "call_remote", "reliable")
func apply_shaken(seconds: float) -> void:
	apply_received.emit(&"shaken", [seconds])


@rpc("authority", "call_remote", "reliable")
func apply_death(peer: int, cause: StringName, position: Vector3) -> void:
	apply_received.emit(&"death", [peer, cause, position])


@rpc("authority", "call_remote", "reliable")
func apply_respawn(peer: int, position: Vector3) -> void:
	apply_received.emit(&"respawn", [peer, position])
