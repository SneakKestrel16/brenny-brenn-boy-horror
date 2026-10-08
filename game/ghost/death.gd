extends Node
## Doc 05 section 14, doc 03 section 8 (death rules): the host decides a death (`die`), every peer applies
## it the same way: the player becomes a ghost (`Game.players[peer].ghost`), a body is left where they fell
## (`bodies` group, for carrying later), and the Player node switches to spectating. A ghost comes back at
## dawn at the spawn point. Not built yet (Phase 3): ghost lantern flicker, crow possession, the body as a carried
## thing, the Dawn Report.

const RESPAWN_TEST_S := 10.0  ## `--creature-test` only: nights repeat without a real dawn, so QA respawns after 10 s

var _creature: Node
var _dead: Dictionary = {}  ## every peer: peer -> {cause, position, body}
var _test := OS.get_cmdline_user_args().has("--creature-test")
var _respawn_at: Dictionary = {}  ## host: peer -> msec


func _ready() -> void:
	add_to_group(&"death")
	Net.apply_received.connect(_on_apply)
	Game.player_left.connect(func(p: int) -> void: _dead.erase(p))
	if not Game.is_host():
		return
	_creature = get_parent().get_node("Creature")
	_creature.caught.connect(func(p: int) -> void:
		if not get_parent().get_node("TrapRace").victims.values().has(p):  # a pinned player dies by the race clock
			die(p, &"night_chase"))
	Clock.phase_changed.connect(func(ph: StringName) -> void:
		if ph == &"dawn":
			for p in _dead.keys():
				respawn(p))
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what == &"farm_state":  # a late joiner learns who is already dead
			for p in _dead:
				Net.to_peers(&"apply_death", [p, _dead[p].cause, _dead[p].position], [peer]))


## Host only. Idempotent.
func die(peer: int, cause: StringName) -> void:
	var st: Dictionary = Game.players.get(peer, {})
	if st.is_empty() or Game.is_ghost(peer):
		return
	st.pinned = false
	var pos: Vector3 = st.get("pos", Vector3.ZERO)
	get_parent().get_node("Farm").registry.cancel(peer, &"dead")
	Log.event(&"death", {"player": peer, "cause": String(cause), "position": [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)],
			"phase": String(Clock.phase), "body_id": "body_%d" % peer})
	Net.to_peers(&"apply_death", [peer, cause, pos])
	Net.apply_received.emit(&"death", [peer, cause, pos])
	if _test:
		_respawn_at[peer] = Time.get_ticks_msec() + int(RESPAWN_TEST_S * 1000.0)


func _physics_process(_delta: float) -> void:
	if _respawn_at.is_empty():
		return
	for p in _respawn_at.keys():
		if Time.get_ticks_msec() >= _respawn_at[p]:
			_respawn_at.erase(p)
			respawn(p)


## Host only: the ghost walks again at the spawn point.
func respawn(peer: int) -> void:
	if not _dead.has(peer) or not Game.players.has(peer):
		return
	var spawns := get_tree().get_nodes_in_group(&"player_spawns")
	var pos: Vector3 = (spawns[0] as Node3D).global_position if not spawns.is_empty() else Vector3.ZERO
	var st: Dictionary = Game.players[peer]
	st.freeze_until = Time.get_ticks_msec() + 300  # frames from before the teleport are dropped
	st.pos = pos
	Log.event(&"respawn", {"player": peer, "phase": String(Clock.phase)})
	Net.to_peers(&"apply_respawn", [peer, pos])
	Net.apply_received.emit(&"respawn", [peer, pos])


func _on_apply(what: StringName, args: Array) -> void:
	if what == &"death":
		_apply_death(args[0], args[1], args[2])
	elif what == &"respawn":
		_apply_respawn(args[0], args[1])


func _apply_death(peer: int, cause: StringName, pos: Vector3) -> void:
	if _dead.has(peer):
		return
	if Game.players.has(peer):
		Game.players[peer].ghost = true
	var body := MeshInstance3D.new()  # placeholder body: a lying capsule
	var m := CapsuleMesh.new()
	m.radius = 0.3
	m.height = 1.7
	body.mesh = m
	body.name = "body_%d" % peer
	body.add_to_group(&"bodies")
	get_parent().add_child(body)
	body.global_position = pos + Vector3(0, 0.3, 0)
	body.rotation.z = PI / 2.0
	_dead[peer] = {"cause": cause, "position": pos, "body": body}
	if not Game.is_host():
		Log.event(&"death_seen", {"player": peer, "cause": String(cause)})  # QA: the client also applied it
	var pl := _player(peer)
	if pl:
		pl.become_ghost()


func _apply_respawn(peer: int, pos: Vector3) -> void:
	if not _dead.has(peer):
		return
	if Game.players.has(peer):
		Game.players[peer].ghost = false
	if not Game.is_host():
		Log.event(&"respawn_seen", {"player": peer})
	_dead[peer].body.queue_free()
	_dead.erase(peer)
	var pl := _player(peer)
	if pl:
		pl.respawn(pos)


func _player(peer: int) -> Node:
	return get_parent().get_node("Players").player(peer)
