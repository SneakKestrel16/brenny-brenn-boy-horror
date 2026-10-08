extends Node3D
## Doc 05 sections 3 and 6: the `Players` node. One Player per peer, the `move`/`moves` stream (channel 1,
## doc 06 section 7), the host's speed check and footstep Noise. Clients own movement; the host only
## validates (CONTRACTS section 5).

const PlayerScript := preload("res://game/player/player.gd")
const SpeedCheck := preload("res://game/player/speed_check.gd")
const StillRing := preload("res://game/player/still_ring.gd")

const Frame := preload("res://game/player/move_frame.gd")
const SEND_HZ := 20.0  ## doc 06 section 6 (placeholder)
const STRIDE_M := 1.6  ## doc 05 section 6 `step_stride_m` (placeholder)

var _send_t := 0.0
var _players: Dictionary = {}  ## peer -> Player
var _log_moves := false


func _ready() -> void:
	_log_moves = OS.get_cmdline_user_args().has("--log-moves")
	for p in Game.players:
		_spawn(p)
	Game.player_joined.connect(_spawn)
	Game.player_left.connect(_despawn)
	Net.bytes_received.connect(_on_bytes)
	if Game.is_host() and OS.get_cmdline_user_args().has("--log-noise"):  # doc 05 section 8: debug runs only
		NoiseBus.noise_emitted.connect(func(p: Vector3, r: float, k: StringName, s: int) -> void:
			Log.event(&"noise_emitted", {"kind": String(k), "radius_m": r, "peer": s, "x": snappedf(p.x, 0.1), "z": snappedf(p.z, 0.1)}))


var _log_t := 0.0


func _physics_process(delta: float) -> void:
	if _log_moves:
		_log_t += delta
		if _log_t >= 1.0:
			_log_t = 0.0
			_log_positions()
	if not Game.is_host():
		return
	_send_t += delta
	if _send_t < 1.0 / SEND_HZ:
		return
	_send_t = 0.0
	var pkt := PackedByteArray([Frame.MOVES, 0])
	var n := 0
	for peer in Game.players:
		var st: Dictionary = Game.players[peer]
		if not st.has("pos"):
			continue
		var off := pkt.size()
		pkt.resize(off + 4 + Frame.FRAME_BYTES)
		pkt.encode_s32(off, peer)
		Frame.write(pkt, off + 4, st.seq, st.pos, st.yaw, st.pitch, st.crouch, st.sprint)
		n += 1
	pkt[1] = n
	if n > 0:
		Net.send_bytes(0, pkt)


## Local player calls this each send tick: the host ingests directly, a client sends to peer 1.
func submit_local(seq: int, pos: Vector3, yaw: float, pitch: float, crouch: bool, sprint: bool) -> void:
	if Game.is_host():
		submit(1, Frame.unpack(Frame.pack(seq, pos, yaw, pitch, crouch, sprint), 1))
	else:
		Net.send_bytes(1, Frame.pack(seq, pos, yaw, pitch, crouch, sprint))


func player(peer: int) -> Node:
	return _players.get(peer)


func _spawn(peer: int) -> void:
	if _players.has(peer):
		return
	var pl = PlayerScript.new()
	pl.name = str(peer)
	pl.peer = peer
	pl.is_local = peer == Game.local_peer()
	pl.players = self
	var spawns := get_tree().get_nodes_in_group(&"player_spawns")
	add_child(pl)
	if not spawns.is_empty():
		pl.global_position = (spawns[maxi(Game.players.keys().find(peer), 0) % spawns.size()] as Node3D).global_position
	_players[peer] = pl


func _despawn(peer: int) -> void:
	if _players.has(peer):
		_players[peer].queue_free()
		_players.erase(peer)


# --- Receive ------------------------------------------------------------------------------------

func _on_bytes(from: int, pkt: PackedByteArray) -> void:
	if pkt.is_empty():
		return
	if pkt[0] == Frame.MOVE and Game.is_host() and pkt.size() >= 1 + Frame.FRAME_BYTES:
		submit(from, Frame.unpack(pkt, 1))
	elif pkt[0] == Frame.MOVES and not Game.is_host() and pkt.size() >= 2:
		var off := 2
		for i in pkt[1]:
			if off + 4 + Frame.FRAME_BYTES > pkt.size():
				return
			var peer := pkt.decode_s32(off)
			var f := Frame.unpack(pkt, off + 4)
			off += 4 + Frame.FRAME_BYTES
			if _players.has(peer) and peer != Game.local_peer():
				_players[peer].set_target(f.pos, f.yaw, f.pitch, f.crouch)


## Host only. Validates one frame against the host's own state for the peer, keeps and relays the
## (possibly clamped) result, and emits footstep Noise once per stride from the same stream.
func submit(peer: int, f: Dictionary) -> void:
	var st: Dictionary = Game.players.get(peer, {})
	if not Game.players.has(peer):
		return
	var now := Time.get_ticks_msec()
	if now < int(st.get("freeze_until", 0)):
		return  # a respawn teleport is in flight: frames from the old spot are dropped
	if st.get("pinned", false) and st.has("pos"):
		f.pos = st.pos  # pinned in a trap (doc 03 section 7): the host keeps them put
	var ghost := Game.is_ghost(peer)
	var pos: Vector3 = f.pos
	if st.has("pos"):
		if f.seq <= st.seq:
			return  # stale or duplicate
		# dt: the larger of host receive time and nominal send interval, so bunched packets never
		# read as a speed spike (jitter must not rubber-band friends, doc 06 section 6).
		var dt := maxf((now - st.t_ms) / 1000.0, (f.seq - st.seq) / SEND_HZ)
		var mode := &"crouch" if f.crouch else (&"sprint" if f.sprint else &"walk")
		var max_speed := Data.speed(mode) * float(st.get("speed_mult", 1.0))
		if ghost:
			max_speed = 1000.0  # ponytail: ghosts fly free until Phase 3 gives them a ghost speed
		var r := SpeedCheck.check(st.pos, f.pos, dt, max_speed)
		if r.violation:
			Log.event(&"speed_violation", {"peer": peer, "speed": snappedf(st.pos.distance_to(f.pos) / dt, 0.1),
					"max": snappedf(max_speed, 0.1), "teleport": r.teleport})
			if r.teleport and peer > 1:
				Net.to_peers(&"apply_teleport", [r.pos], [peer])
		pos = r.pos
		st.stride = float(st.stride) + Vector2(pos.x - st.pos.x, pos.z - st.pos.z).length()
		if ghost:
			st.stride = 0.0  # ghosts make no sound
		while st.stride >= STRIDE_M:
			st.stride -= STRIDE_M
			NoiseBus.emit_kind(_step_kind(f, pos), pos, peer)
	else:
		st.stride = 0.0
	st.pos = pos
	st.yaw = f.yaw
	st.pitch = f.pitch
	st.crouch = f.crouch
	st.sprint = f.sprint
	st.seq = f.seq
	st.t_ms = now
	_update_still(peer, st, pos, now)
	Game.players[peer] = st
	if peer != Game.local_peer() and _players.has(peer):
		_players[peer].set_target(pos, f.yaw, f.pitch, f.crouch)


## Doc 05 section 6: `Game.players[peer].is_still` comes from the host's 1 s ring of received positions.
func _update_still(peer: int, st: Dictionary, pos: Vector3, now: int) -> void:
	if not st.has("ring"):
		st.ring = StillRing.new()
	st.ring.push(now, pos)
	var still: bool = st.ring.is_still()
	if still != bool(st.get("is_still", false)):
		Log.event(&"still_changed", {"player": peer, "still": still, "moved_m": snappedf(st.ring.moved_m(), 0.01)})
	st.is_still = still


func _step_kind(f: Dictionary, pos: Vector3) -> StringName:
	if f.crouch:
		return &"step_crouch"
	if not f.sprint:
		return &"step_walk"
	# ponytail: corn blockers keep players out of the corn in the gray box, so this is false until the
	# real corn ring is walkable (layer 5 point query, doc 05 section 6).
	var q := PhysicsPointQueryParameters3D.new()
	q.position = pos + Vector3.UP
	q.collision_mask = 16
	return &"step_sprint_corn" if not get_world_3d().direct_space_state.intersect_point(q, 1).is_empty() else &"step_sprint"



## Debug runs only (`-- --log-moves`): once a second, where this machine sees every player.
func _log_positions() -> void:
	var seen := {}
	for p in _players:
		var pos: Vector3 = _players[p].global_position
		seen[str(p)] = [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)]
	Log.event(&"player_positions", {"seen": seen})
