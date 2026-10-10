extends SceneTree
## Harness fixture, not game code: a minimal ENet peer that writes a CONTRACTS section 10 log.
## Lets tools/qa/multi.py prove it can start 2 to 4 networked instances and collect their logs
## before the game has networking or logging. Run through multi.py, for example:
##   uv run tools/qa/multi.py -n 3 --headless --common "-s res://tests/qa/fake_peer.gd -- --qa-port=24567 --qa-peers=3" --args "-- --qa-role=host" --args "-- --qa-role=client" --args "-- --qa-role=client"
## User args (after --): --qa-role=host|client, --qa-port=<int>, --qa-peers=<total incl. host>,
## --qa-session=<id> (default qa_fake), --qa-timeout=<seconds> (default 20).
## Events are QA-only (qa_* names), so the log checker reports them as unknown events, not measures.

var _role: String = "client"
var _port: int = 24567
var _peers: int = 2
var _session: String = "qa_fake"
var _timeout_s: float = 20.0
var _elapsed: float = 0.0
var _log: FileAccess
var _connected: PackedInt32Array = PackedInt32Array()
var _done: bool = false
var _mp: MultiplayerAPI
var _peer_id: int = 0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"qa-role": _role = kv[1]
			"qa-port": _port = kv[1].to_int()
			"qa-peers": _peers = kv[1].to_int()
			"qa-session": _session = kv[1]
			"qa-timeout": _timeout_s = kv[1].to_float()
	_mp = get_multiplayer()
	var peer := ENetMultiplayerPeer.new()
	var err: Error
	if _role == "host":
		err = peer.create_server(_port, _peers - 1)
	else:
		err = peer.create_client("127.0.0.1", _port)
	if err != OK:
		push_error("fake_peer: ENet %s failed: %s" % [_role, error_string(err)])
		quit(1)
		return
	(_mp as SceneMultiplayer).server_relay = false  # star topology like net.gd `_use`: else the Net autoload pins clients it has no ENet peer for
	_mp.multiplayer_peer = peer
	_mp.peer_connected.connect(_on_peer_connected)
	_mp.server_disconnected.connect(_on_server_disconnected)
	if _role == "host":
		_open_log()


func _process(delta: float) -> bool:
	_elapsed += delta
	if _log == null and _role != "host" and _mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_open_log()
	if _role == "host" and not _done and _connected.size() >= _peers - 1:
		_done = true
		_write("qa_all_connected", {"peers": _connected.size() + 1})
		# Give clients a moment to log the host before closing the server.
		create_timer(1.0).timeout.connect(_finish.bind(0))
	if _elapsed > _timeout_s and not _done:
		_done = true
		push_error("fake_peer: %s timed out after %.0f s with %d peer(s) connected" % [_role, _timeout_s, _connected.size()])
		_finish(1)
	return false


func _open_log() -> void:
	var dir: String = "user://logs/%s" % _session
	DirAccess.make_dir_recursive_absolute(dir)
	var id: int = _mp.get_unique_id()
	_peer_id = id
	_log = FileAccess.open("%s/peer_%d.jsonl" % [dir, id], FileAccess.WRITE)
	_write("qa_session_start", {"role": _role, "port": _port})
	print("QA_FAKE_PEER role=%s id=%d log=%s" % [_role, id, ProjectSettings.globalize_path(dir)])


func _on_peer_connected(id: int) -> void:
	_connected.append(id)
	if _log == null:
		_open_log()
	_write("qa_peer_connected", {"other": id})


func _on_server_disconnected() -> void:
	_write("qa_server_disconnected", {})
	_finish(0)


func _write(event: String, data: Dictionary) -> void:
	if _log == null:
		return
	var record: Dictionary = {
		"t": snappedf(_elapsed, 0.01), "day": 1, "phase": "day",
		"peer": _peer_id, "event": event, "data": data,
	}
	_log.store_line(JSON.stringify(record))
	_log.flush()


func _finish(code: int) -> void:
	if _log != null:
		_write("qa_session_end", {"code": code})
		_log.close()
		_log = null
	quit(code)
