extends Node
## Doc 05 section 3: session state, player registry, scene switching. The host is peer 1.
##
## Stopgap: `Net` (game/net/net.gd, Network & Voice) does not exist yet, so the minimal ENet host and
## join, the roster and the session_state handshake live here. P1-02 handoff lists what moves to
## `Net`. Join is by raw IP[:port] only (join codes are Network & Voice's, doc 06 section 4).

signal session_started
signal player_joined(peer: int)
signal player_left(peer: int)

const DEFAULT_PORT := 45120  ## doc 06 section 2; 45121..45124 if taken locally
const MAX_CLIENTS := 4  ## one more than allowed, to say "the farm is full" (doc 06 section 2)
const CHANNELS := 4  ## CONTRACTS section 7
const CONNECT_TIMEOUT_S := 10.0
const MAIN_SCENE := "res://game/core/main.tscn"

var players: Dictionary = {}  ## peer id -> PlayerState (a Dictionary until P1-04)
var session_id := ""
var difficulty: StringName = &"normal"
var seed_value := 0
var debug_view := false
var bots := 0
var in_session := false
var _join_target := ""


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func local_peer() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


func is_ghost(peer: int) -> bool:
	return bool(players.get(peer, {}).get("ghost", false))


## Living and ghost players; farmhands that do not count are P1-later.
func player_count() -> int:
	return maxi(players.size(), 1)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Command line (doc 05 section 3), called by Boot. Accepts `--key=value` and `--key value`.
func parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			if key.contains("="):
				out[key.get_slice("=", 0)] = key.substr(key.find("=") + 1)
			elif i + 1 < args.size() and not args[i + 1].begins_with("--") and key in ["join", "seed", "bots", "port"]:
				out[key] = args[i + 1]
				i += 1
			else:
				out[key] = ""
		i += 1
	return out


func begin(args: Dictionary) -> void:
	if not Data.ok:
		push_error("Game: data failed to load, refusing to start (%d errors)" % Data.errors.size())
		return
	seed_value = int(args.get("seed", 0))
	debug_view = args.has("debug-view")
	bots = int(args.get("bots", 0))
	var port := int(args.get("port", DEFAULT_PORT))
	if args.has("join"):
		join(str(args["join"]), port)
	else:
		start_host(port)  # no menu yet (game/ui/): no arguments hosts a solo session


func start_host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	# max_channels stays 0: Godot 4.7.2 create_server shifts its arguments (spike README, PP-02).
	var err := peer.create_server(port, MAX_CLIENTS)
	var tries := 0
	while err != OK and tries < 4:
		tries += 1
		port += 1
		err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Game: could not open UDP port %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	session_id = "%s_%04x" % [Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_"),
			randi() & 0xFFFF]
	Log.open(session_id, 1)
	players[1] = {}
	in_session = true
	Log.event(&"net_hosting", {"port": port})
	Log.event(&"session_start", {"session_id": session_id, "build_id": str(Data.hash_value),
			"players": players.keys(), "season_id": "season", "difficulty": String(difficulty),
			"phase1": Data.phase1, "bots": bots})
	Clock.start()
	session_started.emit()
	_go_main()
	return OK


func join(address: String, default_port: int = DEFAULT_PORT) -> Error:
	var host := address
	var port := default_port
	if address.count(":") == 1:
		host = address.get_slice(":", 0)
		port = int(address.get_slice(":", 1))
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port, CHANNELS)
	if err != OK:
		push_error("Game: could not start connecting to %s:%d: %s" % [host, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_join_target = "%s:%d" % [host, port]
	get_tree().create_timer(CONNECT_TIMEOUT_S).timeout.connect(func() -> void:
		if not in_session:
			push_error("Game: no session_state from %s within %d s" % [_join_target, int(CONNECT_TIMEOUT_S)]))
	return OK


func _go_main() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


# --- Host side ----------------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	players[id] = {}
	apply_session_state.rpc_id(id, session_id, Log.now(), Data.phase1, Data.hash_value, difficulty)
	apply_roster.rpc(players.keys())
	Clock.apply_clock.rpc_id(id, Clock.day, Clock.phase, Clock.t_phase)
	Log.event(&"player_joined", {"player": id})
	player_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	players.erase(id)
	apply_roster.rpc(players.keys())
	Log.event(&"player_left", {"player": id})
	player_left.emit(id)


# --- Client side --------------------------------------------------------------------------------

func _on_connected_to_server() -> void:
	Log.event(&"net_connected", {"target": _join_target})


func _on_connection_failed() -> void:
	push_error("Game: connection to %s failed" % _join_target)


func _on_server_disconnected() -> void:
	Log.event(&"net_server_disconnected")
	in_session = false
	multiplayer.multiplayer_peer = null


@rpc("authority", "call_remote", "reliable")
func apply_session_state(p_session_id: String, host_t: float, p_phase1: bool, data_hash: int, p_difficulty: StringName) -> void:
	session_id = p_session_id
	difficulty = p_difficulty
	Log.open(session_id, multiplayer.get_unique_id(), host_t)
	if p_phase1 != Data.phase1 or data_hash != Data.hash_value:
		Log.event(&"data_mismatch", {"peer": local_peer(), "table": "*"})
	in_session = true
	session_started.emit()
	_go_main()


@rpc("authority", "call_remote", "reliable")
func apply_roster(peers: Array) -> void:
	var old := players.keys()
	players.clear()
	for p in peers:
		players[int(p)] = {}
	for p in players:
		if not p in old:
			player_joined.emit(p)
	for p in old:
		if not players.has(p):
			player_left.emit(p)
