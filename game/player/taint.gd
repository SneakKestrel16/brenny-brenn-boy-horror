extends Node
## P3-07, doc 01 "The Taint", doc 02 section 13, doc 03 sections 3.3 and 8: who is Tainted and the Taint
## sources on the ground. Host-owned: `set_taint` sets `Game.players[peer].tainted` (and `taint_cause`), logs
## `taint_changed` and broadcasts `apply_taint_changed`; every peer mirrors the flag (NoiseBus, the HUD, the
## sprint bar and the stained hands, TaintLook, read it). Taint ends with `wash` at the well (station.gd) or at
## dawn.
##
## Sources (`add_source` / `remove_source`, host): creature leavings (creature.gd, one per `leavings_every_m`
## of lurk and stalk walking), and the dead crows and strange seeds P3-06 sabotage will place. A living player
## within TOUCH_M of one is Tainted with the source's kind as the cause. Every peer shows the stain (TaintLook)
## (`apply_taint_source`). Item causes (stolen tool, item left in the field at dusk) are on the cans
## (items/cans.gd). Moonflowers are not built yet.

const TOUCH_M := 0.8  ## placeholder: no doc number for "touching" a source
const CHECK_S := 0.2  ## host touch check interval (placeholder)

var sources: Dictionary = {}  ## every peer: id -> {kind, position, node}
var _next_id := 1
var _check_t := 0.0


func _ready() -> void:
	add_to_group(&"taint")
	Net.apply_received.connect(_on_apply)
	if not Game.is_host():
		return
	Clock.phase_changed.connect(func(p: StringName) -> void:
		if p == &"dawn":
			for peer in Game.players:
				set_taint(peer, false, &"dawn")
			for id in sources.keys():
				if sources[id].kind == &"leavings":
					remove_source(id)  # inference: the stains go with the night (doc 01 says nothing)
		elif p == &"dusk":
			get_tree().call_group(&"cans", &"taint_loose_cans"))
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what != &"farm_state":
			return  # a late joiner sees who is Tainted and the sources
		for p in Game.players:
			if bool(Game.players[p].get("tainted", false)):
				Net.to_peers(&"apply_taint_changed", [p, true, Game.players[p].get("taint_cause", &"")], [peer])
		for id in sources:
			Net.to_peers(&"apply_taint_source", [id, sources[id].kind, sources[id].position, true], [peer]))


## Doc 02 section 13: the sprint time multiplier. Taint and Shaken multiply (`stacking` `multiply`: x0.36
## with taint.json's 0.6 and 0.6).
static func sprint_mult(tainted: bool, shaken: bool, taint_mult: float, shaken_mult: float) -> float:
	return (taint_mult if tainted else 1.0) * (shaken_mult if shaken else 1.0)


# --- host ----------------------------------------------------------------------------------------

## Host: Taint `peer` on or off. No change, no line: being Tainted twice changes nothing (doc 01). Ghosts are
## never Tainted.
func set_taint(peer: int, on: bool, cause: StringName) -> void:
	if not Game.is_host() or not Game.players.has(peer):
		return
	var st: Dictionary = Game.players[peer]
	if bool(st.get("tainted", false)) == on or (on and Game.is_ghost(peer)):
		return
	Log.event(&"taint_changed", {"player": peer, "on": on, "cause": String(cause)})
	Net.to_peers(&"apply_taint_changed", [peer, on, cause])
	Net.apply_received.emit(&"taint_changed", [peer, on, cause])  # the host is its own client


func add_source(kind: StringName, pos: Vector3) -> int:
	var id := _next_id
	_next_id += 1
	pos.y = 0.0
	Log.event(&"taint_source", {"id": id, "kind": String(kind), "on": true, "pos": [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)]})
	Net.to_peers(&"apply_taint_source", [id, kind, pos, true])
	Net.apply_received.emit(&"taint_source", [id, kind, pos, true])
	return id


func remove_source(id: int) -> void:
	if not sources.has(id):
		return
	var s: Dictionary = sources[id]
	Log.event(&"taint_source", {"id": id, "kind": String(s.kind), "on": false, "pos": [snappedf(s.position.x, 0.1), snappedf(s.position.z, 0.1)]})
	Net.to_peers(&"apply_taint_source", [id, s.kind, s.position, false])
	Net.apply_received.emit(&"taint_source", [id, s.kind, s.position, false])


func _physics_process(delta: float) -> void:
	if not Game.is_host():
		return
	_check_t += delta
	if _check_t < CHECK_S:
		return
	_check_t = 0.0
	for p in Game.players:
		var st: Dictionary = Game.players[p]
		if Game.is_ghost(p) and bool(st.get("tainted", false)):
			set_taint(p, false, &"death")  # a ghost is never Tainted (inference: doc 01 lists wash and dawn only)
		if not st.has("pos") or Game.is_ghost(p) or bool(st.get("tainted", false)):
			continue
		for s in sources.values():
			if Vector2(st.pos.x - s.position.x, st.pos.z - s.position.z).length() <= TOUCH_M:
				set_taint(p, true, s.kind)
				break


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	match what:
		&"taint_changed":
			var peer: int = args[0]
			if Game.players.has(peer):
				Game.players[peer].tainted = args[1]
				Game.players[peer].taint_cause = args[2] if args[1] else &""
			_hands(peer, args[1])
			if not Game.is_host() and peer == Game.local_peer():  # the host's line is written in set_taint
				Log.event(&"taint_changed", {"player": peer, "on": args[1], "cause": String(args[2])})
		&"taint_source":
			var id: int = args[0]
			if args[3]:
				if not sources.has(id):
					sources[id] = {"kind": args[1], "position": args[2], "node": _mark(args[1], args[2], id)}
			elif sources.has(id):
				sources[id].node.queue_free()
				sources.erase(id)


## Doc 01's "black, oily stains up the hands and sleeves, visible to all": the look is the Technical Artist's
## (game/render/taint_look.gd, P3-08). The heartbeat is Audio's (Q-060).
func _hands(peer: int, on: bool) -> void:
	var players := get_parent().get_node_or_null(^"Players")
	var pl: Node = players.player(peer) if players else null
	if pl:
		TaintLook.show_on(pl, on)


## The source's look on the ground (TaintLook, P3-08), seen by every peer.
func _mark(kind: StringName, pos: Vector3, id: int) -> Node3D:
	var mi: Node3D = TaintLook.mark(kind, id)
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.02, 0)
	return mi
