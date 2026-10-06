extends RefCounted
## CONTRACTS section 10 JSON Lines: user://logs/<session_id>/peer_<id>.jsonl, one per peer.
##
## The host picks the session id; a client buffers its records until the host sends it, so every
## peer of one session writes into the same folder (QA's check_logs.py groups by folder). `t` is
## seconds since the host started the session; a client offsets its clock by the host's `t` at
## join (error about half the round-trip time). The spike has no day or phase yet, so every record
## carries day 0 and phase "day" (placeholders until the game has a clock). Players are named by
## ENet peer id, never by voice slot (DECISIONS D-012).

var peer_id := 0
var session_id := ""
var _file: FileAccess
var _pending: Array[Dictionary] = []
var _t0_msec := Time.get_ticks_msec()
var _t_offset := 0.0


func now() -> float:
	return (Time.get_ticks_msec() - _t0_msec) / 1000.0 + _t_offset


## Host: call once when the server starts. Client: call when the host's session id arrives.
func open(p_session_id: String, p_peer_id: int, host_t: float = -1.0) -> void:
	session_id = p_session_id
	peer_id = p_peer_id
	if host_t >= 0.0:
		_t_offset = host_t - (Time.get_ticks_msec() - _t0_msec) / 1000.0
	var dir := "user://logs/%s" % session_id
	DirAccess.make_dir_recursive_absolute(dir)
	_file = FileAccess.open("%s/peer_%d.jsonl" % [dir, peer_id], FileAccess.WRITE)
	if _file == null:
		push_warning("voice spike: cannot open log in %s" % dir)
		return
	for r in _pending:
		r["peer"] = peer_id
		r["t"] = snappedf(float(r["t"]) + _t_offset, 0.001)
		_write(r)
	_pending.clear()


## A client that never reached a host still leaves its records behind.
func open_unjoined(p_peer_id: int) -> void:
	if _file == null:
		open("%s_unjoined" % Time.get_datetime_string_from_system().replace(":", "").replace("-", ""),
				p_peer_id)


func event(name: String, data: Dictionary) -> void:
	var r := {"t": snappedf(now(), 0.001), "day": 0, "phase": "day", "peer": peer_id,
			"event": name, "data": data}
	print("[log] ", name, " ", JSON.stringify(data))
	if _file == null:
		_pending.append(r)
	else:
		_write(r)


func _write(r: Dictionary) -> void:
	_file.store_line(JSON.stringify(r))
	_file.flush()


func close() -> void:
	if _file:
		_file.close()
		_file = null
