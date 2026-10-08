extends Node
## Doc 05 section 3: session state, player registry, scene switching. The host is peer 1.
##
## Transport, the join handshake and the RPCs are in `Net` (game/net/net.gd, P1-15); `Net` calls
## `apply_session_state` and `apply_roster` here and edits `players` on connect and disconnect.

signal session_started
signal player_joined(peer: int)
signal player_left(peer: int)
signal voice_setting_changed(peer: int)
## The player pressed "Record lines" / "Re-record" (doc 06 s11). The recording screen is P2-03's: connect here.
signal recording_requested

const MAIN_SCENE := "res://game/core/main.tscn"
const MENU_SCENE := "res://game/ui/main_menu.tscn"
const LOBBY_SCENE := "res://game/ui/lobby.tscn"
const WORLD_PHASE1 := "res://game/world/farm_phase1.tscn"
const WORLD_FULL := "res://game/world/farm.tscn"  ## DD Phase 2 full farm (P2-02); chosen by `--full-farm` (Q-053)

var full_farm := OS.get_cmdline_user_args().has("--full-farm")  ## host and joiners both pass it: the session handshake does not carry it
var players: Dictionary = {}  ## peer id -> PlayerState (a Dictionary until P1-04)
var session_id := ""
var difficulty: StringName = &"normal"
var seed_value := 0
var debug_view := false
var bots := 0
var in_session := false
var in_lobby := false  ## the barn before the match: the host's Clock has not started (P2-10)
var lobby_autostart := 0  ## QA: `--lobby-start=<n>` starts the match when n players are in the barn
var console_open := false  ## the dev console or a menu has the keyboard (D-031); Player and HoldController ignore game input
var free_mouse := OS.get_cmdline_user_args().has("--free-mouse")  ## test runs never capture the mouse (multi.py passes it)


## `--free-mouse`: undo any capture (Player, pause menu, recording screen) so a test window never holds the mouse.
func _process(_delta: float) -> void:
	if free_mouse and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The level scene Main and the lobby load (the lobby barn is the same scene; spawns lie in the barn).
func world_path() -> String:
	return WORLD_FULL if full_farm else WORLD_PHASE1


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func local_peer() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


func is_ghost(peer: int) -> bool:
	return bool(players.get(peer, {}).get("ghost", false))


## Living and ghost players; farmhands that do not count are P1-later.
func player_count() -> int:
	return maxi(players.size(), 1)


## D-038: the game is built around 4; bots never fill past it. Real players may go up to `max_players()`.
const BASE_PLAYERS := 4


## The player cap, `player_scaling.json` `max_players` (D-038: 6; the roster, spawns and Net's refusal read it).
func max_players() -> int:
	return int(Data.record(&"player_scaling", &"headcount").get("max_players", BASE_PLAYERS))


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
	lobby_autostart = int(args.get("lobby-start", 0))
	var port := int(args.get("port", Net.DEFAULT_PORT))
	if args.has("join"):
		Net.join(str(args["join"]), port)
	else:
		start_host(port, args.has("lobby"))  # Boot shows the main menu instead when launched with no flags


## Doc 05 s3 "Build id" (Q-047): `build_id.txt` written by the packager, else the project version, else `dev`.
func build_id() -> String:
	if FileAccess.file_exists("res://build_id.txt"):
		return FileAccess.get_file_as_string("res://build_id.txt").strip_edges()
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


func start_host(port: int = Net.DEFAULT_PORT, lobby: bool = false) -> Error:
	var err := Net.host(port)
	if err != OK:
		return err
	session_id = "%s_%04x" % [Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_"),
			randi() & 0xFFFF]
	Log.open(session_id, 1)
	players[1] = {"voice_setting": wire_voice_setting()}
	in_session = true
	in_lobby = lobby
	Log.event(&"net_hosting", {"port": Net.port})
	Log.event(&"session_start", {"session_id": session_id, "build_id": build_id(), "data_hash": Data.hash_value,
			"players": players.keys(), "season_id": "season", "difficulty": String(difficulty),
			"phase1": Data.phase1, "bots": bots, "lobby": lobby})
	if not lobby:
		Clock.start()
	session_started.emit()
	_go_main()
	return OK


func _go_main() -> void:
	get_tree().change_scene_to_file.call_deferred(LOBBY_SCENE if in_lobby else MAIN_SCENE)


## Hook for P2-03 (doc 06 s12 step 5): true once every clip is pre-shared. Start waits for it.
func match_ready() -> bool:
	return Voice.clips.ready_to_start()


## Host: leaves the lobby for the match. Movement state from the lobby is dropped so the new Player
## nodes' sequence numbers are not rejected as stale.
func start_match() -> void:
	if not is_host() or not in_lobby or not match_ready():
		return
	in_lobby = false
	for p in players:
		players[p] = {"voice_setting": voice_setting_of(p)}
	Clock.start()
	Log.event(&"match_started", {"players": players.keys()})
	Net.to_peers(&"apply_match_start")
	_go_main()


func apply_match_start() -> void:
	in_lobby = false
	for p in players:
		players[p] = {"voice_setting": voice_setting_of(p)}
	_go_main()


## Back to the main menu (pause menu "Leave", host-left card).
func leave_session() -> void:
	Log.event(&"session_left", {})
	Log.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	in_session = false
	in_lobby = false
	console_open = false
	Clock.stop()
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


# --- Voice setting (doc 06 s11 "Setting IDs"; the owner's machine is the authority) --------------

## What goes on the wire: `unchosen` has nothing recorded, so it is sent as `off`.
func wire_voice_setting() -> String:
	return "lobby_lines" if str(Settings.get_value(&"voice_setting")) == "lobby_lines" else "off"


func set_voice_setting(setting: String) -> void:
	Settings.set_value(&"voice_setting", setting)
	Settings.save()
	send_voice_setting()


func send_voice_setting() -> void:
	if in_session:
		if is_host():
			on_voice_setting_request(1, wire_voice_setting())
		else:
			Net.to_host(&"request_voice_setting", [wire_voice_setting()])


func voice_setting_of(peer: int) -> String:
	return str(players.get(peer, {}).get("voice_setting", "off"))


## Host, from `Net.request_voice_setting`: `live_clips` is Phase 5 and refused.
func on_voice_setting_request(peer: int, setting: String) -> void:
	if not is_host() or not players.has(peer):
		return
	if not setting in ["off", "lobby_lines"]:
		Log.event(&"hold_refused", {"verb": "voice_setting", "reason": "unsupported", "peer": peer})
		return
	apply_voice_setting(peer, setting)
	Net.to_peers(&"apply_voice_setting", [peer, setting])
	Log.event(&"voice_setting", {"player": peer, "setting": setting})


func apply_voice_setting(peer: int, setting: String) -> void:
	if not players.has(peer):
		players[peer] = {}
	players[peer].voice_setting = setting
	voice_setting_changed.emit(peer)


# --- Called by Net (client side) ---------------------------------------------------------------

func apply_session_state(p_session_id: String, host_t: float, p_phase1: bool, data_hash: int, p_difficulty: StringName, p_lobby: bool = false) -> void:
	session_id = p_session_id
	difficulty = p_difficulty
	in_lobby = p_lobby
	Log.open(session_id, multiplayer.get_unique_id(), host_t)
	if p_phase1 != Data.phase1 or data_hash != Data.hash_value:
		Log.event(&"data_mismatch", {"peer": local_peer(), "table": "*"})
	in_session = true
	send_voice_setting()
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
