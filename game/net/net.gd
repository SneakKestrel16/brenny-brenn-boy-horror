extends Node
## Doc 06 sections 2, 5 and 7: ENet transport, host and join, the join handshake, roster, and every
## RPC (doc 05 section 22: no `rpc()` outside `game/net/`). Session state stays in `Game`; this node
## sends it. Join is by IP[:port] or a join code (`JoinCode`, D-049; friends join over Tailscale,
## D-024); UPnP stays in spikes/voice/ until a task asks for it.
##
## Identity (P2-03): `player_uid()` and `request_join`; the host keeps `profiles` (peer -> uid, name)
## and sends them with `apply_roster`. Debug user arg `--profile=<name>` keeps the uid and the voice
## clips under `user://profiles/<name>/`, so two local copies don't share them.
##
## Not built yet (doc 06): apply_join_accepted, slots,
## peer timeouts, the --net-sim-* queue. Add each with the task that first needs it.

const DEFAULT_PORT := 45120  ## doc 06 section 2; 45121..45124 if taken locally
const PORT_TRIES := 4
const CHANNELS := 4  ## CONTRACTS section 7
const CONNECT_TIMEOUT_S := 10.0  ## placeholder

## A `send_bytes` packet arrived (doc 06 section 2: byte 0 is the message type). Added in P1-04.
signal bytes_received(from_peer: int, packet: PackedByteArray)
## The host sent `apply_teleport` (doc 06 section 7). Added in P1-04.
signal teleport_received(position: Vector3)

const PROTOCOL_VERSION := 1  ## doc 06 section 5 `request_join`; a joiner with another one (or another build id) is refused
const BANDWIDTH_S := 10.0  ## doc 06 s14: `net_bandwidth` interval
const NAME_MAX := 24  ## display name characters kept (placeholder)

var port := 0  ## the port actually opened (host) or dialled (client)
var profiles := {}  ## peer id -> {"uid": 32 hex, "name": display name}; the host's copy is the truth
var _join_target := ""
var _uid := ""
var _bw_t := 0.0
var _refused := {}  ## host: peers sent away because the farm was full; their disconnect is not a player leaving
var _code := ""  ## join_code() cache; the lobby asks twice a second
var _pending := {}  ## host, match running: peers connected but not yet identified; admitted or refused by `request_join` (D-048)
var refusal := ""  ## client: why the last join was refused (`full`, `match_in_progress`, ...); the main menu shows it


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	(multiplayer as SceneMultiplayer).peer_packet.connect(func(id: int, packet: PackedByteArray) -> void:
		bytes_received.emit(id, packet))


## Doc 06 s14 `net_bandwidth` and `net_rtt` every 10 s (P2-07, Gameplay edit; P2-21): ENet's host counters plus 28 B of UDP/IPv4
## header per datagram, the PP-02 spike's method, so doc 06 s13's table applies.
func _process(delta: float) -> void:
	_bw_t += delta
	if _bw_t < BANDWIDTH_S:
		return
	var s := _bw_t
	_bw_t = 0.0
	var e := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if e == null or e.host == null:
		return
	var sent := e.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var recv := e.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	var sent_p := e.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
	var recv_p := e.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)
	Log.event(&"net_bandwidth", {"seconds": snappedf(s, 0.01), "players": Game.players.size(),
			"up_kbps": snappedf((sent + 28 * sent_p) * 8.0 / s / 1000.0, 0.1),
			"down_kbps": snappedf((recv + 28 * recv_p) * 8.0 / s / 1000.0, 0.1),
			"up_datagrams_per_s": snappedf(sent_p / s, 0.1)})
	# P2-21, doc 06 s14 `net_rtt`: one per ENet peer (a client's only peer is the host), the PP-02 spike's fields.
	for id in multiplayer.get_peers():
		var pp := e.get_peer(id)
		if pp:
			Log.event(&"net_rtt", {"to": id, "rtt_ms": int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)),
					"enet_loss": snappedf(pp.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE), 0.0001)})


## Host only. Opens the ENet server, trying the next ports if one is taken (doc 06 section 2).
func host(p_port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	# max_channels stays 0: Godot 4.7.2 create_server shifts its arguments (doc 06 section 2, PP-02).
	# P2-07: connections = the player cap (D-038), one more than the clients allowed, so a peer past the cap
	# connects long enough to be told "the farm is full" (doc 06 section 2).
	var err := peer.create_server(p_port, Game.max_players())
	var tries := 0
	while err != OK and tries < PORT_TRIES:
		tries += 1
		p_port += 1
		err = peer.create_server(p_port, Game.max_players())
	if err != OK:
		push_error("Net: could not open UDP port %d: %s" % [p_port, error_string(err)])
		return err
	_use(peer)
	port = p_port
	profiles = {1: {"uid": player_uid(), "name": _clean_name(str(Settings.get_value(&"player_name")))}}
	return OK


## This install's folder in `user://` (doc 06 section 5); `--profile=<name>` gives each local copy its own.
static func user_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile=") and a.substr(10).is_valid_ascii_identifier():
			return "user://profiles/%s/" % a.substr(10)
	return "user://"


## Doc 06 section 5: a random 128-bit id made once per install, as 32 hex digits.
func player_uid() -> String:
	if _uid.is_empty():
		var path := user_dir() + "player_uid.txt"
		if FileAccess.file_exists(path):
			_uid = FileAccess.get_file_as_string(path).strip_edges()
		if not _valid_uid(_uid):
			_uid = Crypto.new().generate_random_bytes(16).hex_encode()
			DirAccess.make_dir_recursive_absolute(user_dir())
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(_uid)
	return _uid


static func _valid_uid(uid: String) -> bool:
	return uid.length() == 32 and uid.is_valid_hex_number()


static func _clean_name(n: String) -> String:
	n = n.strip_edges().substr(0, NAME_MAX)
	return n if not n.is_empty() else "Farmer"


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
	_code = ""
	# P2-17: only this attempt, still connecting. A refusal, a leave or a host quit (peer gone or replaced) is not an error.
	get_tree().create_timer(CONNECT_TIMEOUT_S).timeout.connect(func() -> void:
		if multiplayer.multiplayer_peer == peer and not Game.in_session \
				and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			push_error("Net: no session_state from %s within %d s" % [_join_target, int(CONNECT_TIMEOUT_S)]))
	return OK


## Host to clients: calls the `apply_*` RPC `method` on this node. `targets` empty means every peer.
## The one place channel-0 sends leave this machine (doc 06 section 14); a no-op with no peers.
func to_peers(method: StringName, args: Array = [], targets: Array = []) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	if targets.is_empty() and _refused.is_empty():
		callv(&"rpc", [method] + args)
		return
	if targets.is_empty():  # P2-07: a refused peer waiting to be dropped gets nothing but its refusal
		targets = multiplayer.get_peers()
	for id in targets:
		if not _refused.has(id) or method == &"apply_join_refused":
			callv(&"rpc_id", [id, method] + args)


## Raw packet on `channel` (doc 06 section 2: movement 1 unreliable ordered, voice 2 unreliable).
## `peer` 0 means every peer. A no-op with no peers, or when `peer` is mid-disconnect (PP-02: sending
## then prints "Unable to send packet"). Added in P1-04; the net-sim queue is still P1-later.
func send_bytes(peer: int, packet: PackedByteArray, channel: int = 1) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	var mode := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE if channel == 2 else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	if peer == 0 and _refused.is_empty() and _pending.is_empty():
		(multiplayer as SceneMultiplayer).send_bytes(packet, 0, mode, channel)
		return
	# P2-18: a refused or not-yet-identified peer gets nothing (a broadcast to a refused peer printed
	# "Unable to send packet ... max channels: 0" until its disconnect 0.5 s later).
	for id in ([peer] if peer != 0 else multiplayer.get_peers()):
		if not _refused.has(id) and not _pending.has(id) and _connected(id):
			(multiplayer as SceneMultiplayer).send_bytes(packet, id, mode, channel)


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
	if Game.humans() >= Game.max_players():  # P2-07, doc 06 s2: the farm is full (bots do not count: D-038 drops one for a human)
		_refuse(id, &"full")
		return
	if Game.match_started():  # D-048: a running match admits only a roster player, and the uid arrives with `request_join`
		_pending[id] = true
		get_tree().create_timer(CONNECT_TIMEOUT_S).timeout.connect(func() -> void:
			if _pending.has(id):
				_refuse(id, &"no_identity"))
		return
	_admit(id)


## Host: sends the refusal and drops the peer 0.5 s later (an immediate disconnect reached the joiner before the RPC, tested).
func _refuse(id: int, reason: StringName) -> void:
	_pending.erase(id)
	var admitted := Game.players.has(id)  # a lobby joiner is admitted before its uid is known
	if admitted:
		Game.players.erase(id)
		profiles.erase(id)
	_refused[id] = true
	Log.event(&"join_refused", {"peer": id, "reason": String(reason), "players": Game.players.size()})
	to_peers(&"apply_join_refused", [reason], [id])
	if admitted:
		to_peers(&"apply_roster", [Game.players.keys(), profiles])
		Game.player_left.emit(id)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		var e := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if e and id in multiplayer.get_peers():
			e.disconnect_peer(id))


## Host: `id` is in. `rejoin` marks a roster player coming back to a running match (Death makes them a ghost until dawn).
func _admit(id: int, rejoin: bool = false) -> void:
	_pending.erase(id)
	Game.players[id] = {"rejoin": true} if rejoin else {}
	to_peers(&"apply_session_state", [Game.session_id, Log.now(), Data.phase1, Data.hash_value, Game.difficulty, Game.in_lobby], [id])
	to_peers(&"apply_roster", [Game.players.keys(), profiles])
	for p in Game.players:  # the newcomer learns everyone's voice setting (P2-10)
		if p != id:
			to_peers(&"apply_voice_setting", [p, Game.voice_setting_of(p)], [id])
	to_peers(&"apply_clock", [Clock.day, Clock.phase, Clock.t_phase], [id])
	Roles.sync()  # P4-09: a rejoiner gets their role back
	Log.event(&"player_joined", {"player": id})
	Game.player_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if _pending.erase(id):
		return
	if not Game.is_host() or _refused.erase(id):
		return
	Game.players.erase(id)
	profiles.erase(id)
	to_peers(&"apply_roster", [Game.players.keys(), profiles])
	Log.event(&"player_left", {"player": id})
	Game.player_left.emit(id)


# --- Client side --------------------------------------------------------------------------------

## The address this client dialled (`ip:port`), for the rejoin file and the join code the pause menu shows.
func join_target() -> String:
	return _join_target


## A join code for the host (doc 06 s4; D-049 fallback). The host names its own best IPv4 (a Tailscale 100.64/10 address first, then a
## private one); a client uses the address it dialled. Empty when there is none. Inference: UPnP is not built, so a public address
## is not known here; the Tailscale or LAN address covers D-024's case.
func join_code() -> String:
	if not Game.in_session:
		return ""
	if _code.is_empty():
		_code = _make_join_code()
	return _code


func _make_join_code() -> String:
	if not Game.is_host():
		return JoinCode.encode(_join_target.get_slice(":", 0), port)
	var best := ""
	for a in IP.get_local_addresses():
		if JoinCode.classify(a) == "cgnat":
			return JoinCode.encode(a, port)
		if best.is_empty() and JoinCode.classify(a) == "private":
			best = a
	return JoinCode.encode(best, port) if not best.is_empty() else ""


func _on_connected_to_server() -> void:
	_pin_throttle(1)
	Log.event(&"net_connected", {"target": _join_target})
	# Doc 06 section 5. The voice setting also follows from Game.send_voice_setting once in session.
	var version := PROTOCOL_VERSION
	for a in OS.get_cmdline_user_args():  # QA (P2-18): `--protocol-version=<n>` poses as another version
		if a.begins_with("--protocol-version="):
			version = int(a.get_slice("=", 1))
	rpc_id(1, &"request_join", version, Game.build_id(), player_uid(),
			_clean_name(str(Settings.get_value(&"player_name"))), Game.wire_voice_setting())


func _on_connection_failed() -> void:
	push_error("Net: connection to %s failed" % _join_target)


func _on_server_disconnected() -> void:
	Log.event(&"net_server_disconnected")
	Game.in_session = false
	multiplayer.multiplayer_peer = null


# --- RPCs (doc 06 section 7); handlers live in the owning autoload -------------------------------

## P2-07 (doc 06 s2): the host refused this join (doc 06 s7 lists the reasons). The main menu shows
## `refusal` as a line of text; a headless copy quits.
@rpc("authority", "call_remote", "reliable")
func apply_join_refused(reason: StringName) -> void:
	print("Net: join refused by the host: %s" % reason)
	refusal = String(reason)
	if reason == &"match_in_progress":
		Rejoin.clear_session()  # the match is not ours to rejoin
	multiplayer.multiplayer_peer = null
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
	elif Game.in_session:  # P2-17: `not_in_season` comes after the lobby let us in; close that session (it opens the menu)
		Game.leave_session()
	else:
		get_tree().change_scene_to_file.call_deferred(Game.MENU_SCENE)


@rpc("authority", "call_remote", "reliable")
func apply_session_state(p_session_id: String, host_t: float, p_phase1: bool, data_hash: int, p_difficulty: StringName, p_lobby: bool = false) -> void:
	Game.apply_session_state(p_session_id, host_t, p_phase1, data_hash, p_difficulty, p_lobby)


## P2-10 (doc 06 s7, s11): the host left the barn lobby for the match.
@rpc("authority", "call_remote", "reliable")
func apply_match_start() -> void:
	Game.apply_match_start()


## P4-09: pick a role (empty string = none); the host validates and answers with `apply_roles`.
@rpc("any_peer", "call_remote", "reliable")
func request_role(role: String) -> void:
	Roles.on_request(_sender(), StringName(role))


@rpc("authority", "call_remote", "reliable")
func apply_roles(table: Dictionary) -> void:
	Roles.apply(table)


## Doc 06 s11: the owner's voice setting (`off` / `lobby_lines`). Slots are not built, so this names the peer id.
@rpc("any_peer", "call_remote", "reliable")
func request_voice_setting(setting: String) -> void:
	Game.on_voice_setting_request(_sender(), setting)


@rpc("authority", "call_remote", "reliable")
func apply_voice_setting(peer: int, setting: String) -> void:
	Game.apply_voice_setting(peer, setting)


## Host to all (P4-14, doc 06 s10): whether `peer` holds a walkie and its battery in whole seconds. Peer id, not slot (D-076).
@rpc("authority", "call_remote", "reliable")
func apply_walkie(peer: int, has_walkie: bool, battery: int) -> void:
	Voice.walkie.apply(peer, has_walkie, battery)


# --- Recording light and clip pre-share (doc 06 sections 11 and 12); added in P2-03 ---------------
# Every clip message, `request_clips_ready` included, rides reliable channel 3 so they stay in order: a
# manifest before its chunks, and a client's ready report after the clips it sent.

## Owner to host to all: capture is live on the owner's machine (doc 06 s11 "The recording light").
@rpc("any_peer", "call_remote", "reliable")
func request_recording_light(on: bool) -> void:
	Voice.on_recording_light_request(_sender(), on)


@rpc("authority", "call_remote", "reliable")
func apply_recording_light(peer: int, on: bool) -> void:
	Voice.apply_recording_light(peer, on)


## Owner to host: the owner's whole clip set (an empty one deletes them all). It replaces the last.
@rpc("any_peer", "call_remote", "reliable", 3)
func request_clip_manifest(manifest: Array) -> void:
	Voice.clips.on_manifest_request(_sender(), manifest)


@rpc("authority", "call_remote", "reliable", 3)
func apply_clip_manifest(owner_peer: int, manifest: Array) -> void:
	Voice.clips.apply_manifest(owner_peer, manifest)


@rpc("any_peer", "call_remote", "reliable", 3)
func request_clip_chunk(clip_id: String, index: int, count: int, bytes: PackedByteArray) -> void:
	Voice.clips.on_chunk_request(_sender(), clip_id, index, count, bytes)


@rpc("authority", "call_remote", "reliable", 3)
func apply_clip_chunk(owner_peer: int, clip_id: String, index: int, count: int, bytes: PackedByteArray) -> void:
	Voice.clips.apply_chunk(owner_peer, clip_id, index, count, bytes)


## Client to host: a digest of the complete clips it holds ("" while its recording screen is open).
@rpc("any_peer", "call_remote", "reliable", 3)
func request_clips_ready(digest: String) -> void:
	Voice.clips.on_ready_request(_sender(), digest)


## Doc 06 section 5 (P2-03): who the joiner is. Only uid and name are kept.
@rpc("any_peer", "call_remote", "reliable")
func request_join(protocol_version: int, build_id: String, uid: String, display_name: String, _voice_setting: String) -> void:
	var peer := _sender()
	var waiting := _pending.has(peer)
	if not Game.is_host() or not (waiting or Game.players.has(peer)) or not _valid_uid(uid):
		return
	# D-048: who may be in. A running match takes only its roster; a loaded save's lobby only that season's players.
	var in_barn := Game.in_lobby
	var reason: StringName = &""
	if protocol_version != PROTOCOL_VERSION or build_id != Game.build_id():  # P2-18, doc 06 s5 step 3
		Log.event(&"net_join_version", {"peer": peer, "protocol_version": protocol_version, "build_id": build_id})
		reason = &"version_mismatch"
	elif Game.match_started() and not Game.match_roster.has(uid):
		reason = &"match_in_progress"
	elif in_barn and not Game.season_uids.is_empty() and not uid in Game.season_uids:
		reason = &"not_in_season"
	if reason != &"":
		_refuse(peer, reason)
		return
	if waiting:  # the same player back before the host saw the old connection die (a crash): the old one goes, the new one is in
		for old in profiles.keys():
			if profiles[old].get("uid") == uid:
				_on_peer_disconnected(old)
				_refused[old] = true  # swallows the old peer's own disconnect signal
				multiplayer.multiplayer_peer.disconnect_peer(old)
	profiles[peer] = {"uid": uid, "name": _clean_name(display_name)}
	if waiting:  # a roster player back in a running match: in as a ghost until dawn (Death reads the flag)
		_admit(peer, true)
		return
	to_peers(&"apply_roster", [Game.players.keys(), profiles])
	Roles.sync()  # P4-09: the joiner learns the picks


## `p_profiles`: peer -> {uid, name} (P2-03). The names are for the recording screen's lines and lists.
@rpc("authority", "call_remote", "reliable")
func apply_roster(peers: Array, p_profiles: Dictionary) -> void:
	profiles = p_profiles
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


## Client to host (P4-06): a store action, `buy` (item id), `flare` or `scarecrow`. The host validates and answers `apply_store`.
@rpc("any_peer", "call_remote", "reliable")
func request_store(op: StringName, arg: StringName) -> void:
	request_received.emit(&"store", _sender(), [op, arg])


## Host to all (P4-06): the store's whole state (bought items, scrap, placed scarecrows, flare shots, opened plots).
@rpc("authority", "call_remote", "reliable")
func apply_store(state: Dictionary) -> void:
	apply_received.emit(&"store", [state])


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


## P4-05: the Prize Pumpkin's counters, carrier and position (prize_pumpkin.gd).
@rpc("authority", "call_remote", "reliable")
func apply_prize(planted: bool, watered_days: int, guarded: int, drops: int, carrier: int, watered: bool, judged: bool, x: float, z: float) -> void:
	apply_received.emit(&"prize", [planted, watered_days, guarded, drops, carrier, watered, judged, x, z])


@rpc("authority", "call_remote", "reliable")
func apply_money_changed(coins: int) -> void:
	apply_received.emit(&"money_changed", [coins])


## Host to all (P4-07): debt flags and what is still owed.
@rpc("authority", "call_remote", "reliable")
func apply_debt(first_made: bool, foreclosed: bool, lost: bool, owed: int, paid: int) -> void:
	apply_received.emit(&"debt", [first_made, foreclosed, lost, owed, paid])


## Host to all at dawn (P3-12, doc 06 section 12): the Dawn Report, lure references only, never audio.
@rpc("authority", "call_remote", "reliable")
func apply_dawn_report(report: Dictionary) -> void:
	apply_received.emit(&"dawn_report", [report])


## Host to a peer pulling `farm_state`: the headcount that fixed the open field plots at match start (P2-14).
@rpc("authority", "call_remote", "reliable")
func apply_headcount(n: int) -> void:
	apply_received.emit(&"headcount", [n])


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

## Host to all: a trap changed (`set`, `moved`, `sprung`, `disarmed`). Set traps are sent so every
## peer can draw the close-range clue (doc 03 s9); they stay hidden beyond it (doc 01 "Night Traps").
@rpc("authority", "call_remote", "reliable")
func apply_trap_changed(trap_id: String, kind: StringName, state: StringName, position: Vector3) -> void:
	apply_received.emit(&"trap_changed", [trap_id, kind, state, position])


## Host to all: `victim` is pinned in `trap_id` and has `deadline_s` seconds (doc 03 section 7).
@rpc("authority", "call_remote", "reliable")
func apply_trap_race(victim: int, trap_id: String, deadline_s: float, start_distance_m: float) -> void:
	apply_received.emit(&"trap_race", [victim, trap_id, deadline_s, start_distance_m])


## Host to one player: Shaken for `seconds`, sprint time x0.6 (doc 01 "The Taint", P3-07).
@rpc("authority", "call_remote", "reliable")
func apply_shaken(seconds: float) -> void:
	apply_received.emit(&"shaken", [seconds])


## Host to the freed player: slow walk for `seconds` (doc 01 "Night Traps": 40% slower for 60 s).
@rpc("authority", "call_remote", "reliable")
func apply_slowed(seconds: float) -> void:
	apply_received.emit(&"slowed", [seconds])


## Host to all (P3-07): `peer` is Tainted or clean; `cause` is a taint.json cause, `well` or `dawn`.
@rpc("authority", "call_remote", "reliable")
func apply_taint_changed(peer: int, on: bool, cause: StringName) -> void:
	apply_received.emit(&"taint_changed", [peer, on, cause])


## Host to all (P3-07): a Taint source (leavings, dead crow, strange seeds) appears or goes.
@rpc("authority", "call_remote", "reliable")
func apply_taint_source(id: int, kind: StringName, position: Vector3, on: bool) -> void:
	apply_received.emit(&"taint_source", [id, kind, position, on])


## Host to all (P3-06, AI Programmer): a sabotage disturbance's mark appears or goes (`id` > 0), or a
## scarecrow moves (`id` < 0: scarecrow -id, with its `yaw`). sabotage.gd applies it.
@rpc("authority", "call_remote", "reliable")
func apply_disturbance(id: int, kind: StringName, position: Vector3, yaw: float, on: bool) -> void:
	apply_received.emit(&"disturbance", [id, kind, position, yaw, on])


## Host to all (P4-08): the pen animals (`state`: [state, x, z, yaw] each), the open fence sections (`fence`: indices),
## or an animal sound (`sound`: [animal, panic]). game/farming/animals.gd applies it.
@rpc("authority", "call_remote", "reliable")
func apply_animals(kind: StringName, data: Array) -> void:
	apply_received.emit(&"animals", [kind, data])


@rpc("authority", "call_remote", "reliable")
func apply_death(peer: int, cause: StringName, position: Vector3) -> void:
	apply_received.emit(&"death", [peer, cause, position])


@rpc("authority", "call_remote", "reliable")
func apply_respawn(peer: int, position: Vector3) -> void:
	apply_received.emit(&"respawn", [peer, position])


# Ghost powers (doc 05 section 14, P3-09): the host checks the sender is a ghost (game/ghost/ghost_powers.gd).

@rpc("any_peer", "call_remote", "reliable")
func request_flicker(light_id: String) -> void:
	request_received.emit(&"ghost_light", _sender(), [light_id])


@rpc("any_peer", "call_remote", "reliable")
func request_possess_crow(crow_id: String) -> void:
	request_received.emit(&"possess_crow", _sender(), [crow_id])


@rpc("any_peer", "call_remote", "reliable")
func request_crow_caw() -> void:
	request_received.emit(&"crow_caw", _sender(), [])


@rpc("any_peer", "call_remote", "reliable")
func request_rustle() -> void:
	request_received.emit(&"rustle", _sender(), [])


## Host to all: the ghost light pattern on the light at marker path `light_id` (doc 07 section 4.3).
@rpc("authority", "call_remote", "reliable")
func apply_flicker(light_id: String) -> void:
	apply_received.emit(&"ghost_light", [light_id])


## Host to the ghost: it now sees from crow perch `crow_id` ("" = the crow let go).
@rpc("authority", "call_remote", "reliable")
func apply_crow_possessed(peer: int, crow_id: String) -> void:
	apply_received.emit(&"crow_possessed", [peer, crow_id])


## Host to all: a ghost sound (`rustle` or `caw`) at `position`; a sound only, never creature Noise.
@rpc("authority", "call_remote", "reliable")
func apply_ghost_sound(kind: StringName, position: Vector3) -> void:
	apply_received.emit(&"ghost_sound", [kind, position])


# --- Trap sweeps (doc 05 section 11); added in P2-11 ----------------------------------------------

## Host to the target (private, `target_slot` the peer) or all (public, -1): a scare (doc 03 section 13,
## doc 06 section 7). `extra` is the voice source (`clip:<owner>:<clip_id>`) for the whisper and own voice.
@rpc("authority", "call_remote", "reliable")
func apply_scare(scare_id: StringName, target_slot: int, position: Vector3, extra: String) -> void:
	apply_received.emit(&"scare", [scare_id, target_slot, position, extra])


## Host to all: every flag position (doc 01 "Night Traps > Flags").
@rpc("authority", "call_remote", "reliable")
func apply_flags(positions: Array) -> void:
	apply_received.emit(&"flags", [positions])


## Host to all: which pegboard slots hold a bear trap (one bool per `pegboard_slots` marker, in order).
@rpc("authority", "call_remote", "reliable")
func apply_pegboard_changed(filled: Array) -> void:
	apply_received.emit(&"pegboard_changed", [filled])


## Host to all: whether `peer` has the shovel and a disarmed bear trap in hand (doc 05 section 9).
@rpc("authority", "call_remote", "reliable")
func apply_hands(peer: int, shovel: bool, trap: bool) -> void:
	apply_received.emit(&"hands", [peer, shovel, trap])


## Host to all (P2-27, D-054): the table of physical cans, `[id, holder, x, z, charge]` each (game/items/cans.gd).
@rpc("authority", "call_remote", "reliable")
func apply_cans(data: Array) -> void:
	apply_received.emit(&"cans", [data])


# --- Whistle and emotes (doc 05 section 14); added in P3-11 ---------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_whistle() -> void:
	request_received.emit(&"whistle", _sender(), [])


@rpc("any_peer", "call_remote", "reliable")
func request_emote(emote_id: StringName) -> void:
	request_received.emit(&"emote", _sender(), [emote_id])


## Host to all: `peer` whistled at the host-stamped `position` (doc 06 names a slot; slots are not built).
@rpc("authority", "call_remote", "reliable")
func apply_whistle(peer: int, position: Vector3) -> void:
	apply_received.emit(&"whistle", [peer, position])


@rpc("authority", "call_remote", "reliable")
func apply_emote(peer: int, emote_id: StringName, position: Vector3) -> void:
	apply_received.emit(&"emote", [peer, emote_id, position])
