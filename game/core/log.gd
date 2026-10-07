extends Node
## CONTRACTS section 10 JSON Lines: user://logs/<session_id>/peer_<id>.jsonl, one file per peer.
## Doc 05 section 18. The host picks the session id; a client buffers its records until the host
## sends it, so every peer of one session writes into the same folder. `t` is seconds since the
## host started the session (a client offsets its clock by the host's `t` at join). `day` and
## `phase` come from Clock, read lazily (null until Clock loads). Players are named by ENet peer
## id, never by voice slot (D-012). Never throws; flushes every line.

var peer_id := 0
var session_id := ""
var _file: FileAccess
var _pending: Array[Dictionary] = []
var _t0_msec := Time.get_ticks_msec()
var _t_offset := 0.0


func now() -> float:
	return (Time.get_ticks_msec() - _t0_msec) / 1000.0 + _t_offset


## Host: once, when the session starts. Client: when the host's session id arrives (host_t >= 0).
func open(p_session_id: String, p_peer_id: int, host_t: float = -1.0) -> void:
	if _file:
		close()
	session_id = p_session_id
	peer_id = p_peer_id
	if host_t >= 0.0:
		_t_offset = host_t - (Time.get_ticks_msec() - _t0_msec) / 1000.0
	var dir := "user://logs/%s" % session_id
	DirAccess.make_dir_recursive_absolute(dir)
	_file = FileAccess.open("%s/peer_%d.jsonl" % [dir, peer_id], FileAccess.WRITE)
	if _file == null:
		push_warning("Log: cannot open %s" % dir)
		return
	for r in _pending:
		r["peer"] = peer_id
		r["t"] = snappedf(float(r["t"]) + _t_offset, 0.001)
		_write(r)
	_pending.clear()


func event(name: StringName, data: Dictionary = {}) -> void:
	var clock := get_node_or_null("/root/Clock")
	var r := {"t": snappedf(now(), 0.001), "day": clock.day if clock else 0,
			"phase": String(clock.phase) if clock else "day", "peer": peer_id,
			"event": String(name), "data": data}
	print("[log] ", name, " ", JSON.stringify(data))
	if _file == null:
		_pending.append(r)
	else:
		_write(r)


func close() -> void:
	if _file:
		_file.close()
		_file = null


func _write(r: Dictionary) -> void:
	_file.store_line(JSON.stringify(r))
	_file.flush()


func _exit_tree() -> void:
	close()
