extends Node
## Doc 05 section 3: session state, player registry, scene switching. The host is peer 1.
##
## Transport, the join handshake and the RPCs are in `Net` (game/net/net.gd, P1-15); `Net` calls
## `apply_session_state` and `apply_roster` here and edits `players` on connect and disconnect.

signal session_started
signal player_joined(peer: int)
signal player_left(peer: int)

const MAIN_SCENE := "res://game/core/main.tscn"

var players: Dictionary = {}  ## peer id -> PlayerState (a Dictionary until P1-04)
var session_id := ""
var difficulty: StringName = &"normal"
var seed_value := 0
var debug_view := false
var bots := 0
var in_session := false


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func local_peer() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


func is_ghost(peer: int) -> bool:
	return bool(players.get(peer, {}).get("ghost", false))


## Living and ghost players; farmhands that do not count are P1-later.
func player_count() -> int:
	return maxi(players.size(), 1)


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
	var port := int(args.get("port", Net.DEFAULT_PORT))
	if args.has("join"):
		Net.join(str(args["join"]), port)
	else:
		start_host(port)  # no menu yet (game/ui/): no arguments hosts a solo session


func start_host(port: int = Net.DEFAULT_PORT) -> Error:
	var err := Net.host(port)
	if err != OK:
		return err
	session_id = "%s_%04x" % [Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_"),
			randi() & 0xFFFF]
	Log.open(session_id, 1)
	players[1] = {}
	in_session = true
	Log.event(&"net_hosting", {"port": Net.port})
	Log.event(&"session_start", {"session_id": session_id, "build_id": str(Data.hash_value),
			"players": players.keys(), "season_id": "season", "difficulty": String(difficulty),
			"phase1": Data.phase1, "bots": bots})
	Clock.start()
	session_started.emit()
	_go_main()
	return OK


func _go_main() -> void:
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


# --- Called by Net (client side) ---------------------------------------------------------------

func apply_session_state(p_session_id: String, host_t: float, p_phase1: bool, data_hash: int, p_difficulty: StringName) -> void:
	session_id = p_session_id
	difficulty = p_difficulty
	Log.open(session_id, multiplayer.get_unique_id(), host_t)
	if p_phase1 != Data.phase1 or data_hash != Data.hash_value:
		Log.event(&"data_mismatch", {"peer": local_peer(), "table": "*"})
	in_session = true
	session_started.emit()
	_go_main()


func apply_roster(peers: Array) -> void:
	var old := players.keys()
	var _old := players.duplicate()
	players.clear()
	for p in peers:
		players[int(p)] = _old.get(int(p), {})
	for p in players:
		if not p in old:
			player_joined.emit(p)
	for p in old:
		if not players.has(p):
			player_left.emit(p)
