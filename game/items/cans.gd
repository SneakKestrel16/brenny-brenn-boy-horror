extends Node
## D-054 / P2-27 (doc 05 section 9): the watering cans and the fuel can are physical objects. They start at
## the well and the fuel drum, a player picks one up (`take_can`), carries it (one can at a time, placeholder)
## and drops it (`drop_can`) where they stand; anyone can pick up a dropped can. Host-owned; every peer
## builds the same cans from code (ids `can_<n>`) and the host sends a snapshot (`apply_cans`) on every change.
## Water charges and the fuel can's "full" flag live in the can; the host mirrors the held can into the
## carrier's `pstate` (`can`, `fuel_can`, `held_can`, `held_kind`) so the chore verbs read it as before.

const WATER_CANS := 2  ## placeholder: not by headcount; the Game Designer settles counts in data (D-054)
const FUEL_CANS := 1  ## placeholder, same
const HOME_AWAY_M := 4.0  ## a can left farther than this from its home is fair game for the creature at nightfall (placeholder)

var cans: Dictionary = {}  ## id -> {kind, home, pos, holder, charge, node, body, mesh}
var farm: Node


## One interactable per can, a child of the can's own node.
class CanTarget extends "res://game/interaction/interactable.gd":
	var cans: Node
	var cid := 0

	func target_pos() -> Vector3:
		return cans.world_pos(cid)

	func verbs_for(st: Dictionary) -> Array[StringName]:
		var out: Array[StringName] = []
		var holder: int = cans.cans[cid].holder
		if holder == 0 and int(st.get("held_can", -1)) < 0:
			out.append(&"take_can")
		elif holder != 0 and int(st.get("held_can", -1)) == cid:
			out.append(&"drop_can")
		return out

	func can_start(verb: StringName, st: Dictionary) -> StringName:
		var c: Dictionary = cans.cans[cid]
		match verb:
			&"take_can":
				if c.holder != 0:
					return &"can_taken"
				return &"hands_full" if int(st.get("held_can", -1)) >= 0 else &""
			&"drop_can":
				return &"" if int(st.get("held_can", -1)) == cid else &"not_holding"
		return &"no_such_verb"

	func complete(verb: StringName, peer: int, _st: Dictionary) -> void:
		if verb == &"take_can":
			cans.take(peer, cid)
		else:
			cans.drop(peer)


func _ready() -> void:
	add_to_group(&"cans")
	name = "Cans"
	var n := 0
	for spec in [[&"well", &"water", WATER_CANS, Vector3(1.6, 0, -0.6)], [&"fuel_drum", &"fuel", FUEL_CANS, Vector3(0.9, 0, 0.5)]]:
		for node in get_tree().get_nodes_in_group(spec[0]):
			for i in spec[2]:
				_make(n, spec[1], (node as Node3D).global_position + spec[3] + Vector3(0, 0, 1.2 * i))
				n += 1
	if Game.is_host():
		Game.player_left.connect(func(p: int) -> void: drop(p))


func _make(id: int, kind: StringName, pos: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Can%d" % id
	add_child(node)
	node.global_position = pos
	# P5-22: the P5-13/P5-15 models; a faint overlay tint keeps charged/empty readable (the model keeps its own look)
	var tint := StandardMaterial3D.new()
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := (load("res://assets/models/%s.glb" % ("tool_watering_can" if kind == &"water" else "tool_fuel_can")) as PackedScene).instantiate()
	for m in mi.find_children("*", "MeshInstance3D"):
		(m as MeshInstance3D).material_overlay = tint
	node.add_child(mi)
	var t := CanTarget.new()
	t.cans = self
	t.cid = id
	t.farm = farm
	t.id = "can_%d" % id
	node.add_child(t)
	t.add_pick_body(Vector3(0.8, 0.6, 0.8))
	var body: StaticBody3D = null
	for c in node.get_children():
		if c is StaticBody3D:
			body = c
	farm.targets[t.id] = t
	cans[id] = {"kind": kind, "home": pos, "pos": pos, "holder": 0, "node": node, "body": body, "tint": tint,
			"charge": int(Data.value(&"labor", &"can", &"capacity")) if kind == &"water" else 0}
	_look(id)


## Where the can is now: the carrier's position while held (host), else where it lies.
func world_pos(id: int) -> Vector3:
	var c: Dictionary = cans[id]
	if c.holder != 0 and Game.players.has(c.holder) and Game.players[c.holder].has("pos"):
		return Game.players[c.holder].pos
	return c.pos


func held_by(peer: int) -> int:
	for id in cans:
		if cans[id].holder == peer:
			return id
	return -1


func _look(id: int) -> void:
	var c: Dictionary = cans[id]
	c.node.global_position = c.pos
	c.node.visible = c.holder == 0
	if c.body:
		c.body.collision_layer = 8 if c.holder == 0 else 0
	var col := Color(0.15, 0.4, 0.95) if c.charge > 0 else Color(0.5, 0.58, 0.64)
	if c.kind == &"fuel":
		col = Color(0.85, 0.15, 0.1) if c.charge > 0 else Color(0.4, 0.15, 0.12)
	col.a = 0.3
	(c.tint as StandardMaterial3D).albedo_color = col


## Colour a held can shows in the hand (used by player.gd).
func color_of(id: int) -> Color:
	return (cans[id].tint as StandardMaterial3D).albedo_color


# --- host ---------------------------------------------------------------------------------------------

## Writes the carrier's chore state back into the can it holds.
func store(peer: int) -> void:
	var id := held_by(peer)
	if id < 0:
		return
	var st: Dictionary = farm.pstate(peer)
	cans[id].charge = int(st.can) if cans[id].kind == &"water" else int(bool(st.get("fuel_can", false)))


func take(peer: int, id: int) -> void:
	var c: Dictionary = cans[id]
	var st: Dictionary = farm.pstate(peer)
	c.holder = peer
	st.held_can = id
	st.held_kind = c.kind
	st.can = c.charge if c.kind == &"water" else 0
	st.fuel_can = c.kind == &"fuel" and c.charge > 0
	Log.event(&"can_taken", {"player": peer, "can": id, "kind": String(c.kind), "charge": c.charge})
	_changed()
	farm.send_carry(peer)
	if c.get("taint_cause", &"") != &"":  # P3-07: a Tainted can Taints whoever picks it up, and is clean after
		get_tree().get_first_node_in_group(&"taint").set_taint(peer, true, c.taint_cause)
		c.taint_cause = &""


## Host (P3-07, P3-06 sabotage may call it): the can Taints the next player who picks it up. `cause` is a
## taint.json cause (`stolen_tool`, `field_item_at_dusk`).
func taint_can(id: int, cause: StringName) -> void:
	cans[id].taint_cause = cause
	Log.event(&"can_tainted", {"can": id, "cause": String(cause)})


## Host, dusk (taint.gd): doc 01 "The Taint": an item left in the field at dusk turns Tainted until picked up.
## "In the field" is a can farther than HOME_AWAY_M from its home (inference: the same rule as the creature's).
func taint_loose_cans() -> void:
	for id in cans:
		var c: Dictionary = cans[id]
		if c.holder == 0 and Vector2(c.pos.x - c.home.x, c.pos.z - c.home.z).length() > HOME_AWAY_M:
			taint_can(id, &"field_item_at_dusk")


## Host: `peer` puts down what they carry, where they stand (also used on death and leaving).
func drop(peer: int) -> void:
	var id := held_by(peer)
	if id < 0:
		return
	store(peer)
	var c: Dictionary = cans[id]
	var st: Dictionary = farm.pstate(peer)
	c.holder = 0
	c.pos = Vector3(st.pos.x, 0.0, st.pos.z) if st.has("pos") else c.home
	st.held_can = -1
	st.held_kind = &""
	st.can = 0
	st.fuel_can = false
	Log.event(&"can_dropped", {"player": peer, "can": id, "kind": String(c.kind), "charge": c.charge, "pos": [snappedf(c.pos.x, 0.1), snappedf(c.pos.z, 0.1)]})
	_changed()
	farm.send_carry(peer)


## Host, nightfall (called from creature.gd, P2-27): the creature moves a can left away from its home; here it
## goes back home (placeholder for "moves it"). Held cans are not touched. A stolen can Taints whoever picks
## it up next (doc 01 "The Taint": picking up a stolen tool, P3-07).
func creature_move_cans() -> void:
	if not Game.is_host():
		return
	for id in cans:
		var c: Dictionary = cans[id]
		if c.holder == 0 and Vector2(c.pos.x - c.home.x, c.pos.z - c.home.z).length() > HOME_AWAY_M:
			Log.event(&"can_stolen", {"can": id, "kind": String(c.kind), "from": [snappedf(c.pos.x, 0.1), snappedf(c.pos.z, 0.1)]})
			c.pos = c.home
			taint_can(id, &"stolen_tool")
	_changed()


func _changed() -> void:
	for p in Game.players:
		store(p)
	snapshot_to(0)


func snapshot() -> Array:
	var out: Array = []
	for id in cans:
		var c: Dictionary = cans[id]
		out.append([id, c.holder, c.pos.x, c.pos.z, c.charge])
	return out


## Host: send the table to everyone (`peer` 0) or one late joiner.
func snapshot_to(peer: int) -> void:
	var data := snapshot()
	if peer == 0:
		Net.to_peers(&"apply_cans", [data])
		apply(data)
	else:
		Net.to_peers(&"apply_cans", [data], [peer])


## Every peer: take the table. Also keeps `farm.carry[peer].held_can/held_kind` for prompts.
func apply(data: Array) -> void:
	for p in farm.carry:
		farm.carry[p].held_can = -1
		farm.carry[p].held_kind = &""
	for e in data:
		var c: Dictionary = cans[int(e[0])]
		if not Game.is_host() and (c.holder != int(e[1]) or c.pos.x != float(e[2]) or c.pos.z != float(e[3])):
			Log.event(&"can_seen", {"can": int(e[0]), "holder": int(e[1]), "pos": [snappedf(float(e[2]), 0.1), snappedf(float(e[3]), 0.1)]})  # QA: what this peer sees
		c.holder = int(e[1])
		c.pos = Vector3(float(e[2]), 0.0, float(e[3]))
		c.charge = int(e[4])
		_look(int(e[0]))
		if c.holder != 0:
			var cs: Dictionary = farm.carry.get(c.holder, {"can": 0, "bag": 0, "fuel_can": false})
			cs.held_can = int(e[0])
			cs.held_kind = c.kind
			farm.carry[c.holder] = cs
	Net.apply_received.emit(&"cans_applied", [])
