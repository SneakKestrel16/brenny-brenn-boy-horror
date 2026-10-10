class_name Doors
extends Node
## Doc 05 section 11 (P5-27, Q-307): the three building doors (barn, farmhouse, tool shed), host-owned open/closed state.
## A door is an Interactable on its `doors` group Marker3D: id `door_<building>`, verbs `open_door` / `close_door` (0.3 s holds,
## Interactable.INSTANT_S). The host validates, flips the state, makes a `door` noise (creature.json `noise_door`), logs `door`
## and sends `apply_door` to everyone; a late joiner gets every state with the `farm_state` pull. Every peer swings the leaves
## (`DoorArt/LeafL`, `LeafR`, pivots at the jambs) and a closed door has a thin blocker on layer 1 in the gap, so players cannot
## walk through. The Creature has a collision exception: it always bangs first, then comes in (doc 03 section 6). Every door
## starts open at each new day (inference: the Phase 1 farm had no doors; settled by a playtest).

const OPEN_YAW := PI / 2.0  ## leaf swing, left -OPEN_YAW and right +OPEN_YAW when open (doc 07 `prop_door_*`, build_farm.py)
const SWING_S := 0.25
const GAP_M := 3.0
const BLOCK_H := 4.0
const LEAF_W := 1.49  ## door leaf collision box, from the prop_door_* meshes (width from the pivot, height, thickness)
const LEAF_H := 2.6
const LEAF_T := 0.22

var open := {}  ## door id -> bool (every peer; authoritative on the host)
var _leaves := {}  ## door id -> [LeafL, LeafR]
var _blocks := {}  ## door id -> StaticBody3D
var _leaf_bodies := {}  ## door id -> [StaticBody3D] one per open leaf (P5-55), solid only while the door stands open
var _farm: Node
var _log_farm := OS.get_cmdline_user_args().has("--log-farm")


## The interactable on a door marker.
class Point extends "res://game/interaction/interactable.gd":
	var doors: Node

	func verbs_for(_st: Dictionary) -> Array[StringName]:
		return [&"close_door" if doors.open.get(id, true) else &"open_door"]

	func can_start(verb: StringName, _st: Dictionary) -> StringName:
		match verb:
			&"open_door": return &"already_open" if doors.open.get(id, true) else &""
			&"close_door": return &"" if doors.open.get(id, true) else &"already_closed"
		return &"no_such_verb"

	func complete(verb: StringName, peer: int, _st: Dictionary) -> void:
		if can_start(verb, _st) != &"":  # a second player moved it first
			return
		doors.host_set(id, verb == &"open_door", peer)


func _ready() -> void:
	_farm = get_tree().get_first_node_in_group(&"farm")
	for m: Node3D in get_tree().get_nodes_in_group(&"doors"):
		var id := "door_" + String(m.get_meta(&"building", ""))
		var p := Point.new()
		p.doors = self
		p.id = id
		p.farm = _farm
		p.range_m = 3.0
		m.add_child(p)
		p.add_pick_body(Vector3(GAP_M, 2.6, 1.0))
		_farm.targets[id] = p
		open[id] = true
		var art := m.get_parent().get_node_or_null(^"DoorArt")  # only the full farm has door models
		if art:
			_leaves[id] = [art.get_node_or_null(^"LeafL"), art.get_node_or_null(^"LeafR")]
			_leaf_bodies[id] = []
			for i in 2:  # P5-55: an open leaf sticks out 1.5 m from the jamb and is solid (layer 1, like DoorBlock)
				var leaf: Node3D = _leaves[id][i]
				if leaf == null:
					continue
				var lb := StaticBody3D.new()
				lb.name = "LeafBody"
				lb.collision_layer = 1
				lb.collision_mask = 0
				var lc := CollisionShape3D.new()
				var ls := BoxShape3D.new()
				ls.size = Vector3(LEAF_W, LEAF_H, LEAF_T)  # leaf meshes: 1.49 wide from the pivot, 0.22 thick (measured)
				lc.shape = ls
				lc.position = Vector3(LEAF_W / 2.0 * (1.0 if i == 0 else -1.0), LEAF_H / 2.0, 0.0)
				lc.disabled = false  # every door starts open
				lb.add_child(lc)
				leaf.add_child(lb)
				_leaf_bodies[id].append(lb)
		var b := StaticBody3D.new()
		b.name = "DoorBlock"  # not "Wall*": the creature measures buildings by those names
		b.collision_layer = 1
		b.collision_mask = 0
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(GAP_M, BLOCK_H, 0.3)
		c.shape = s
		c.position.y = BLOCK_H / 2.0
		c.disabled = true
		b.add_child(c)
		m.get_parent().add_child(b)
		_blocks[id] = b
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
			if what == &"farm_state":
				for id: String in open:
					Net.to_peers(&"apply_door", [id, open[id], 0], [peer]))
		Clock.day_changed.connect(func(_d: int) -> void:
			for id: String in open:
				if not open[id]:
					host_set(id, true, 0))
	_exempt_creature.call_deferred()
	if OS.get_cmdline_user_args().has("--autodoor"):
		_autodoor.call_deferred()


## Host only: the new state, to everyone, with the noise and the log line. `by` 0 is the system.
func host_set(id: String, is_open: bool, by: int) -> void:
	if open.get(id, true) == is_open:
		return
	var args := [id, is_open, by]
	Net.to_peers(&"apply_door", args)
	Net.apply_received.emit(&"door", args)  # the host is its own client
	var pos := ((_blocks[id] as Node3D).global_position if _blocks.has(id) else Vector3.ZERO)
	if by != 0:
		NoiseBus.emit_kind(&"door", pos, by)
	Log.event(&"door", {"door_id": id, "open": is_open, "by": by})


func _on_apply(what: StringName, args: Array) -> void:
	if what != &"door" or not _blocks.has(args[0]):
		return
	var id: String = args[0]
	var is_open: bool = args[1]
	var instant: bool = int(args[2]) == 0  # a sync or the day reset snaps; a person's door swings
	open[id] = is_open
	if _log_farm:
		Log.event(&"door_seen", {"door_id": id, "open": is_open, "by": int(args[2])})
	(_blocks[id].get_child(0) as CollisionShape3D).set_deferred(&"disabled", is_open)
	for lb: Node in _leaf_bodies.get(id, []):
		(lb.get_child(0) as CollisionShape3D).set_deferred(&"disabled", not is_open)
	var leaves: Array = _leaves.get(id, [])
	for i in leaves.size():
		var leaf: Node3D = leaves[i]
		if leaf == null:
			continue
		var yaw := (-OPEN_YAW if i == 0 else OPEN_YAW) if is_open else 0.0
		if instant or not is_inside_tree():
			leaf.rotation.y = yaw
		else:
			create_tween().tween_property(leaf, "rotation:y", yaw, SWING_S)


## P5-55: the physics bodies of one door (blocker and leaves), for sight-line rays that end at the door.
func own_bodies(id: String) -> Array[RID]:
	var out: Array[RID] = []
	if _blocks.has(id):
		out.append((_blocks[id] as CollisionObject3D).get_rid())
	for lb: CollisionObject3D in _leaf_bodies.get(id, []):
		out.append(lb.get_rid())
	return out


func _exempt_creature() -> void:
	var cr := get_tree().get_first_node_in_group(&"creature") as PhysicsBody3D
	if cr:
		for b: PhysicsBody3D in _blocks.values():
			cr.add_collision_exception_with(b)
		for id: String in _leaf_bodies:
			for lb: PhysicsBody3D in _leaf_bodies[id]:
				cr.add_collision_exception_with(lb)


# --- QA script (`-- --autodoor`) --------------------------------------------------------------------------
# The client (non-host) walks to the barn door, closes it at 6 s, opens it again at 32 s; the host closes it again at 40 s. With
# `--log-farm` every peer logs `door_seen` for each state it applies.

func _autodoor() -> void:
	var players := get_parent().get_node(^"Players")
	var steps: Array = [[6.0, "door_barn", &"close_door"], [32.0, "door_barn", &"open_door"]] if not Game.is_host() \
			else [[40.0, "door_barn", &"close_door"]]
	var t0 := Time.get_ticks_msec() / 1000.0
	for s: Array in steps:
		await get_tree().create_timer(maxf(float(s[0]) - (Time.get_ticks_msec() / 1000.0 - t0), 0.0)).timeout
		var me = players.player(Game.local_peer())
		me.nav_path = [(_farm.targets[s[1]] as Node).target_pos() + Vector3(0.0, 0.0, 1.2)]  # outside the door, the way the autochores walk
		var limit := get_tree().create_timer(25.0)
		while not me.nav_path.is_empty() and limit.time_left > 0.0:
			await get_tree().physics_frame
		await get_tree().create_timer(0.5).timeout
		Net.to_host(&"request_hold", [s[2], s[1]])
