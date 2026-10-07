extends Node
## Doc 06 sections 2, 5 and 7: ENet transport, host and join, the join handshake, roster, and every
## RPC (doc 05 section 22: no `rpc()` outside `game/net/`). Session state stays in `Game`; this node
## sends it. Join is by raw IP[:port] only (D-024: friends join over Tailscale); join codes and UPnP
## stay in spikes/voice/ until a task asks for them.
##
## Not built yet (doc 06): request_join / apply_join_accepted / apply_join_refused (build id, full
## farm), slots, player_uid, host-left card, throttle pin, peer timeouts, rtt_ms, to_host, send_bytes,
## the --net-sim-* queue. Add each with the task that first needs it.

const DEFAULT_PORT := 45120  ## doc 06 section 2; 45121..45124 if taken locally
const PORT_TRIES := 4
const MAX_CLIENTS := 4  ## one more than allowed, to say "the farm is full" (doc 06 section 2)
const CHANNELS := 4  ## CONTRACTS section 7
const CONNECT_TIMEOUT_S := 10.0  ## placeholder

var port := 0  ## the port actually opened (host) or dialled (client)
var _join_target := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


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


func _use(peer: ENetMultiplayerPeer) -> void:
	# Star topology: clients only talk to the host (doc 06 section 2, D-010).
	(multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer


# --- Host side ----------------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
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
