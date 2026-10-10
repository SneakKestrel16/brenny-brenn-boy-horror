extends Node
## Doc 05 section 3: session state, player registry, scene switching. The host is peer 1.
##
## Transport, the join handshake and the RPCs are in `Net` (game/net/net.gd, P1-15); `Net` calls
## `apply_session_state` and `apply_roster` here and edits `players` on connect and disconnect.

signal session_started
signal player_joined(peer: int)
signal player_left(peer: int)
signal voice_setting_changed(peer: int)
## P4-09: the role table changed (a pick, a match start, a rejoin).
signal roles_changed

const MAIN_SCENE := "res://game/core/main.tscn"
const MENU_SCENE := "res://game/ui/main_menu.tscn"
const LOBBY_SCENE := "res://game/ui/lobby.tscn"
const WORLD_PHASE1 := "res://game/world/farm_phase1.tscn"
const WORLD_FULL := "res://game/world/farm.tscn"  ## DD Phase 2 full farm (P2-02); default since P2-20; `--phase1-farm` opens the Phase 1 farm

var full_farm := not OS.get_cmdline_user_args().has("--phase1-farm")  ## P2-20: the full farm is the default; `--phase1-farm` opens the gray-box. `--full-farm` is still accepted (no-op)
var players: Dictionary = {}  ## peer id -> PlayerState (a Dictionary until P1-04)
var session_id := ""
var season_id := ""  ## P4-10: names the save folder; a new game uses its session id, a loaded save keeps its own (doc 05 s17)
var _leaving := false
## doc 01 "Difficulty and group settings": easy / normal / nightmare (difficulty.json); host picks in the lobby.
## P4-12: `short_season` is a difficulty.json record too; `--short-season` (or `--difficulty=short_season`) until a lobby picks it (Q-125)
var difficulty: StringName = &"short_season" if OS.get_cmdline_user_args().has("--short-season") else &"normal"
var streamer_safe := OS.get_cmdline_user_args().has("--streamer-safe")  ## group option: live clips are never replayed (P4-11, D-146)
var seed_value := 0
## P5-58 (dev): the body the host forces for the season, "body_<x>" or "" for the seed's pick. `--creature-body=<id>`, the
## lobby dev menu (DevGate) and the console's `creaturebody` set it; `Creature._pick_body` reads it. Clients follow the packets.
var dev_creature_body := ""
var debug_view := false
var bots := 0
var in_session := false
var in_lobby := false  ## the lobby screen before the match: the host's Clock has not started (P2-10, P4-23)
var lobby_ready: Dictionary = {}  ## P4-23: peer -> true for each player marked ready in the lobby (host decides, clients mirror)
var lobby_autostart := 0  ## QA: `--lobby-start=<n>` starts the match when n players are in the lobby, ready or not
var match_roster: Dictionary = {}  ## host: player_uid -> true for everyone in the barn at match start; only they may rejoin (D-048)
var season_uids: Array = []  ## host: a loaded save sets the season's player uids; the lobby admits only them (D-048). Empty = new game
var roles: Dictionary = {}  ## host: player_uid -> role id, kept for the season so a rejoiner keeps theirs (P4-09; the save is P4-10)
var quirks_on := OS.get_cmdline_user_args().has("--quirks")  ## group option (doc 01 Quirks, D-158): off by default, host picks in the lobby (`--quirks` for QA); saved with the season
var quirks: Dictionary = {}  ## host: player_uid -> quirk id, kept for the season so a rejoiner keeps theirs (P5-09)
var season_sting := false  ## P5-24: a next season came through the lobby; Main plays the season-start sting once
var season_no := 1 ## P5-04 (doc 01 "Next season"): which season of the campaign this is; every peer mirrors it, the save keeps it
var traits: Array = []  ## P5-04: creature trait ids gained so far (doc 03 s22), kept to the campaign's end; clients only print them in the Dawn Report
var carry: Dictionary = {}  ## host: what the finished season hands the next (Campaign.build_carry), applied once by Save.apply_pending
var season_lost := true  ## host: the finished season's result (SeasonAwards); only a won season can start the next
var trait_report_pending := false  ## host: the new season's first Dawn Report prints the trait's `report_line` once
var colours: Dictionary = {}  ## host: player key (uid, else "peer<id>") -> farmer colour slot, kept for the season so a rejoiner keeps theirs if it is free (P5-13, D-165)
var colour_slots: Dictionary = {}  ## peer -> colour slot (index into FarmerBody.COLOURS): the host's table, mirrored on clients by `Roles.apply`
var console_open := false  ## the dev console or a menu has the keyboard (D-031); Player and HoldController ignore game input
## Test runs never capture the mouse: `--free-mouse` (multi.py passes it) or the Dummy audio driver every
## test run uses (real play never does). `--grab` overrides both for a manual session.
var free_mouse := not OS.get_cmdline_user_args().has("--grab") and (OS.get_cmdline_user_args().has("--free-mouse") or AudioServer.get_driver_name() == "Dummy")


func _ready() -> void:
	get_tree().auto_accept_quit = false  # P4-10: closing the window goes through `quit()`, which tells the clients first


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


## Captures the mouse for play, never in a headless or test run (`free_mouse`).
func capture_mouse() -> void:
	if DisplayServer.get_name() != "headless" and not free_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## `--free-mouse`: undo any capture (Player, pause menu) so a test window never holds the mouse.
func _process(_delta: float) -> void:
	if free_mouse and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The level scene Main loads (the spawns lie in the barn).
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


## Real players only (bots have negative ids).
func humans() -> int:
	var n := 0
	for p in players:
		if p > 0:
			n += 1
	return n


## D-038: the game is built around 4; bots never fill past it. Real players may go up to `max_players()`.
const BASE_PLAYERS := 4


## The player cap, `player_scaling.json` `max_players` (D-038: 6; the roster, spawns and Net's refusal read it).
func max_players() -> int:
	return int(Data.record(&"player_scaling", &"headcount").get("max_players", BASE_PLAYERS))


## creature.json body ids (`kind` body), in file order.
func creature_body_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in Data.records(&"creature"):
		if r.get("kind") == "body":
			out.append(StringName(r.id))
	return out


## `gaunt` or `body_gaunt` -> `body_gaunt`; "" for random or an unknown name.
func creature_body_id(s: String) -> String:
	var id := s if s.begins_with("body_") else "body_" + s
	return id if s != "" and StringName(id) in creature_body_ids() else ""


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
	dev_creature_body = creature_body_id(str(args.get("creature-body", "")))
	debug_view = args.has("debug-view")
	bots = int(args.get("bots", 0))
	lobby_autostart = int(args.get("lobby-start", 0))
	if args.has("difficulty"):  # QA: `--difficulty=<id>` (host), the same as picking it in the lobby
		difficulty = StringName(args["difficulty"])
	var port := int(args.get("port", Net.DEFAULT_PORT))
	if args.has("load"):  # P4-10 debug: `--load=<season_id|path>` hosts that saved season in the barn
		var err := load_season(str(args["load"]), port)
		if err != OK:
			push_error("Game: could not load season '%s': %s" % [args["load"], error_string(err)])
	elif args.has("join"):
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
	if season_id == "":
		season_id = session_id
	Log.open(session_id, 1)
	players[1] = {"voice_setting": wire_voice_setting()}
	in_session = true
	in_lobby = lobby
	Log.event(&"net_hosting", {"port": Net.port})
	Log.event(&"session_start", {"session_id": session_id, "build_id": build_id(), "data_hash": Data.hash_value,
			"players": players.keys(), "season_id": season_id, "difficulty": String(difficulty),
			"phase1": Data.phase1, "bots": bots, "lobby": lobby, "loaded": not Save.pending.is_empty()})
	if not lobby:
		_start_clock()
	session_started.emit()
	_go_main()
	return OK


## Host: a new season starts at day 1; a loaded one resumes at the dawn it was saved in (P4-10).
func _start_clock() -> void:
	if Save.pending.is_empty():
		Clock.start()
	else:
		# a season-start save (P5-24) resumes at the start of its day, a dawn save at that dawn
		Clock.start(int(Save.pending.get("day", 1)), &"day" if bool(Save.pending.get("season_start", false)) else &"dawn")


## P4-10 (doc 05 s17): host a saved season. `ref` is a path to a save file or a season id under `<Net.user_dir()>/saves/`.
## The lobby then admits only that season's players (D-048); the host must be one of them (doc 06 s5: "any farmhand
## from this season can host it"). The old season id stays, the session id is new.
func load_season(ref: String, port: int = Net.DEFAULT_PORT) -> Error:
	var path := ref if ref.ends_with(".json") else Save.root() + ref + "/latest.json"
	var env := Save.read(path)
	if env.is_empty():
		return ERR_FILE_CORRUPT
	var s: Dictionary = env.state
	if bool(s.get("over", false)):
		return ERR_UNAVAILABLE
	if not Net.player_uid() in s.get("uids", []):
		return ERR_UNAUTHORIZED
	season_id = str(env.season_id)
	season_uids = s.uids.duplicate()
	roles = s.get("roles", {}).duplicate()
	quirks = s.get("quirks", {}).duplicate()
	difficulty = StringName(str(s.get("difficulty", "normal")))
	season_no = int(s.get("season_no", 1))  # P5-04: the campaign's season and gained traits come back with the save
	traits = s.get("traits", []).duplicate()
	trait_report_pending = bool(s.get("trait_report_pending", false))  # P5-28: a season-start save still owes the trait line
	Data.apply_traits(traits)
	Quirks.season_n = season_no  # P5-09: the quirk draw seed follows the loaded season
	for k in s.get("game", {}):  # group options (streamer-safe) before the lobby opens, so joiners get them at admit
		if get(k) != null:
			set(k, s.game[k])
	Save.pending = s
	Cosmetics.load_state(s.get("extras", {}).get("cosmetics", {}))  # P5-05: the lobby shows what each farmhand owns
	var err := start_host(port, true)
	if err != OK:
		Save.pending = {}
		season_id = ""
		season_uids = []
		trait_report_pending = false
		season_no = 1  # the load set them (and the overrides) before the host failed
		traits = []
		Data.clear_overrides()
	return err


func _go_main() -> void:
	get_tree().change_scene_to_file.call_deferred(LOBBY_SCENE if in_lobby else MAIN_SCENE)


## Host (P5-04, doc 01 "Next season"): the finished season was won and the campaign has another.
func can_start_next_season() -> bool:
	return is_host() and not in_lobby and Clock.season_over and not season_lost and season_no < Campaign.seasons_max()


## Host: starts the next season of the campaign. Upgrades, plots and savings carry (doc 02 s21); the creature gains a
## trait (doc 03 s22). P5-24: everyone goes back to the lobby; roles are picked again, `start_match` then redraws the
## quirks, rolls `Imposter.pick`, starts the clock, and Main applies the carry and writes the season-start save.
## The rest resets with the Main reload (doc 02 s21.3). Returns false if it may not start.
func start_next_season() -> bool:
	if not can_start_next_season():
		return false
	carry = Campaign.build_carry(get_tree())
	season_no += 1
	season_id = "%s_s%d" % [session_id, season_no]  # a new save folder: the won season's final save stays as it was
	var seed_n := seed_value if seed_value != 0 else hash(session_id)  # as the creature body (Creature._pick_body)
	var gained := Campaign.draw_trait(seed_n, season_no, traits)
	if gained != "" and season_no >= int(Campaign.rule(&"campaign").get("first_trait_season", 2)):
		traits.append(gained)
		Log.event(&"trait_gained", {"season": season_no, "trait": gained, "seed": seed_n})
		trait_report_pending = true
	Data.apply_traits(traits)
	Save.pending = {}
	Save.own_by_uid = {}
	Save.battery_by_uid = {}
	Save.tally_left = {}
	season_uids = []  # a loaded season's lock ends: the new roster is whoever starts it
	roles.clear()  # picked again in the lobby
	Imposter.clear_pick()  # host only; every peer drops `me` in apply_next_season
	apply_next_season(season_no, traits, true)
	Net.to_peers(&"apply_next_season", [season_no, traits, true])
	for p in players:
		players[p] = {"voice_setting": voice_setting_of(p)}
	Quirks.reroll(season_no)  # P5-09: clears the quirks; the draw is at start_match (Quirks.sync skips the lobby)
	return true


## Every peer, from the host (`Net.apply_next_season`): the season number and trait list; `reload` also starts the new
## season's Main. A joiner gets it without `reload` at admit. Clients keep the trait list only for the Dawn Report.
func apply_next_season(p_season: int, p_traits: Array, reload: bool) -> void:
	season_no = p_season
	traits = p_traits.duplicate()
	if not reload:
		return
	console_open = false
	Clock.season_over = false
	in_lobby = true  # P5-24: the next season starts from the lobby, on every peer
	season_sting = true  # Main plays `ui_season_start_sting` once the lobby is left
	lobby_ready.clear()
	match_roster.clear()
	Imposter.me = false
	Quirks.mine = &""
	if not is_host():
		for p in players:
			players[p] = {"voice_setting": voice_setting_of(p)}
	_go_main()


## Hook for P2-03 (doc 06 s12 step 5): true once every clip is pre-shared. Start waits for it.
func match_ready() -> bool:
	return Voice.clips.ready_to_start()


## Host (P5-13, D-165): give every player here a farmer colour slot. A stored slot is kept when no one else present
## holds it; the others take the lowest free one (max_players is 6, so there is always one; past that it wraps).
func assign_colours() -> void:
	var keys := {}
	var peers: Array = players.keys()
	peers.sort()
	for p in peers:
		var uid := str(Net.profiles.get(p, {}).get("uid", ""))
		keys[p] = uid if uid != "" else "peer%d" % p
	var used := {}
	colour_slots = {}
	for p in peers:
		var s := int(colours.get(keys[p], -1))
		if s >= 0 and not used.has(s):
			used[s] = true
			colour_slots[p] = s
	for p in peers:
		if colour_slots.has(p):
			continue
		var s := 0
		while used.has(s):
			s += 1
		used[s] = true
		colour_slots[p] = s
		colours[keys[p]] = s


## The farmer colour slot of `peer`, or -1 until the host's table arrives. The host assigns on demand.
func colour_of(peer: int) -> int:
	if is_host():
		assign_colours()
	return int(colour_slots.get(peer, -1))


## Host: a match with a roster is running (D-048). A host started straight into the farm (debug, QA) has no roster and stays open.
func match_started() -> bool:
	return not in_lobby and not match_roster.is_empty()


## Host: leaves the lobby for the match. Movement state from the lobby is dropped so the new Player
## nodes' sequence numbers are not rejected as stale.
func start_match() -> void:
	if not is_host() or not in_lobby or not match_ready():
		return
	in_lobby = false
	lobby_ready.clear()
	match_roster.clear()
	for p in players:
		if p > 0:
			match_roster[str(Net.profiles.get(p, {}).get("uid", ""))] = true
		players[p] = {"voice_setting": voice_setting_of(p)}
	for u in season_uids:  # a loaded season: its absent farmhands may still rejoin (they count by uid, not while away)
		match_roster[str(u)] = true
	_start_clock()
	Log.event(&"match_started", {"players": players.keys(), "difficulty": String(difficulty), "streamer_safe": streamer_safe})
	Net.to_peers(&"apply_match_start")
	Roles.sync()  # after the players were rebuilt above (P4-09)
	Imposter.pick()  # P5-11: after roles lock; the secret goes to one peer only
	_go_main()


## Host, lobby only (P4-11): change the group settings; every client gets them (and a late joiner at admit).
func set_group_settings(p_difficulty: StringName, p_streamer_safe: bool) -> void:
	if not is_host() or not in_lobby:
		return
	apply_group_settings(p_difficulty, p_streamer_safe)
	Net.to_peers(&"apply_group_settings", [difficulty, streamer_safe])


func apply_group_settings(p_difficulty: StringName, p_streamer_safe: bool) -> void:
	difficulty = p_difficulty
	streamer_safe = p_streamer_safe
	Log.event(&"group_settings", {"difficulty": String(difficulty), "streamer_safe": streamer_safe})  # every peer


## Host, lobby only (P4-23): `peer` marks itself ready or not; everyone gets the ready list. A client sends
## `false` when its lobby opens, which also brings it the current list.
const READY_GAP_MS := 250
var _ready_msec := {}


func on_lobby_ready_request(peer: int, on: bool) -> void:
	if not is_host() or not in_lobby or not players.has(peer):
		return
	var now := Time.get_ticks_msec()  # P5-29: a held key on the READY button sent ~30 ms toggles
	if now - int(_ready_msec.get(peer, -1000)) < READY_GAP_MS or bool(on) == lobby_ready.has(peer):
		if peer != 1:  # a joiner's opening `false` still gets the list; `apply_lobby_ready` is call_remote
			Net.to_peers(&"apply_lobby_ready", [lobby_ready.keys()], [peer])
		return
	_ready_msec[peer] = now
	if on:
		lobby_ready[peer] = true
	else:
		lobby_ready.erase(peer)
	Log.event(&"lobby_ready", {"player": peer, "on": on})
	apply_lobby_ready(lobby_ready.keys())
	Net.to_peers(&"apply_lobby_ready", [lobby_ready.keys()])


func apply_lobby_ready(peers: Array) -> void:
	lobby_ready.clear()
	for p in peers:
		lobby_ready[int(p)] = true


## Every human but the host is ready (the host's Start is its ready).
func all_ready() -> bool:
	for p in players:
		if p > 1 and not lobby_ready.has(p):
			return false
	return true


func apply_match_start() -> void:
	in_lobby = false
	lobby_ready.clear()
	Rejoin.save_session(Net.join_target(), session_id)  # D-049: where to come back to after a crash
	for p in players:
		players[p] = {"voice_setting": voice_setting_of(p)}
	_go_main()


## Back to the main menu (pause menu "Leave", host-left card).
func leave_session(reason: StringName = &"left") -> void:
	if _leaving:
		return
	_leaving = true
	await _farewell()
	Rejoin.clear_session()  # D-049: a clean Leave forgets the match
	Log.event(&"session_left", {})
	_log_session_end(reason)
	Log.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	Cosmetics.reset()
	in_session = false
	in_lobby = false
	lobby_ready.clear()
	console_open = false
	season_id = ""
	season_uids = []
	match_roster.clear()
	roles.clear()
	quirks.clear()
	quirks_on = false
	season_sting = false
	Quirks.mine = &""
	Quirks.season_n = 1
	season_no = 1
	traits = []
	carry = {}
	season_lost = true
	trait_report_pending = false
	Data.clear_overrides()
	colours.clear()
	colour_slots.clear()
	Imposter.reset()  # P5-11
	Save.pending = {}
	Save.own_by_uid = {}
	Save.battery_by_uid = {}
	Save.tally_left = {}
	Save.peer_uid = {}
	Clock.stop()
	_leaving = false
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)


## Quit the game (window close, pause menu, main menu). A host tells its clients first (doc 06 s5 "Host left").
func quit() -> void:
	if _leaving:
		return
	_leaving = true
	await _farewell()
	_log_session_end(&"quit")
	get_tree().quit()


## Host: `apply_host_leaving`; client: `request_leaving`. Audio stops and the sends get about 0.1 s to flush
## (doc 06 s5 "Host left" 6: otherwise Godot reports leaked playbacks at exit).
func _farewell() -> void:
	_stop_audio(get_tree().root)
	if in_session and multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		if is_host():
			Net.to_peers(&"apply_host_leaving")
		else:
			Net.to_host(&"request_leaving")
		await get_tree().create_timer(0.1).timeout


func _stop_audio(n: Node) -> void:
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D:
		n.call(&"stop")
	for c in n.get_children():
		_stop_audio(c)


func _log_session_end(reason: StringName) -> void:
	if in_session:
		Log.event(&"session_end", {"reason": String(reason), "day": Clock.day, "phase": String(Clock.phase), "players": players.size(),
				"season_id": season_id, "host": is_host()})


# --- Voice setting (doc 06 s11 "Setting IDs"; the owner's machine is the authority) --------------

## What goes on the wire: `live_clips` or `off` (D-146).
func wire_voice_setting() -> String:
	return "off" if str(Settings.get_value(&"voice_setting")) == "off" else "live_clips"


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


## Doc 06 s11 "Coverage" (D-146): `peer`'s live clips may be replayed here now. Every replay (a lure,
## the Dawn Report) asks at play time, so a switch to Off or streamer-safe mode stops the next one.
func replays_voice(peer: int) -> bool:
	return voice_setting_of(peer) == "live_clips" and not streamer_safe


## Host, from `Net.request_voice_setting`.
func on_voice_setting_request(peer: int, setting: String) -> void:
	if not is_host() or not players.has(peer):
		return
	if not setting in ["off", "live_clips"]:
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
	if not p_lobby:  # D-048: the host only lets a roster player into a running match, so this is a rejoin
		Rejoin.save_session(Net.join_target(), session_id)
		RejoinToast.show_line(Rejoin.line(), get_tree())
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
