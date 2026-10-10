extends Node
## Doc 05 section 7 (host only): one ActiveHold per player at most. Validates `request_hold`, ticks
## progress, completes or cancels, answers with `apply_*`, logs `hold_refused` / `hold_cancelled` /
## `hold_completed`. The Farm creates this node on the host only.

const HoldMath := preload("res://game/interaction/hold_math.gd")
const Interactable := preload("res://game/interaction/interactable.gd")
const FlagSpot := preload("res://game/traps_player/flag_spot.gd")
const CANCEL_SLACK_M := 0.5  ## doc 05 section 7 step 4: range_m plus 0.5 (placeholder)

var farm: Node
var holds: Dictionary = {}  ## peer -> {verb, target, progress, hold_s, started}


func request(peer: int, verb: StringName, id: String) -> void:
	if holds.has(peer):  # a new request means the client dropped the old hold (a lost cancel must not wedge it)
		cancel(peer, &"replaced", false)
	var reason := _validate(peer, verb, id)
	if reason != &"":
		Log.event(&"hold_refused", {"player": peer, "verb": String(verb), "target": id, "reason": String(reason)})
		_reply(peer, &"refused", [verb, reason])
		return
	var target := _resolve(id)
	holds[peer] = {"verb": verb, "target": target, "progress": 0.0, "hold_s": Interactable.hold_seconds(verb, StringName(st_role(peer)), target),
			"started": Log.now()}
	target.on_start(verb, peer)
	var gone := _on_target_gone.bind(target)  # Q-345 (3): one guard for every reader of `holds`
	if not target.tree_exiting.is_connected(gone):
		target.tree_exiting.connect(gone)
	var pos: Vector3 = farm.pstate(peer).pos  # P5-23: everyone sees the farmer's `interact` animation (the emote channel, no sound)
	Net.to_peers(&"apply_emote", [peer, &"interact", pos])
	Net.apply_received.emit(&"emote", [peer, &"interact", pos])


## P4-08: `Game.players[peer].role` is set by roles (P4-09); empty until then.
func st_role(peer: int) -> String:
	return String(Game.players.get(peer, {}).get("role", ""))


## A scene target by id, or a throwaway FlagSpot for `flag:<x>,<z>` (freed when the hold ends).
func _resolve(id: String) -> Node:
	if id.begins_with("flag:"):
		return farm.get_tree().get_first_node_in_group(&"trap_sweep").flag_spot(id)
	return farm.targets[id]


func _release(h: Dictionary) -> void:
	if is_instance_valid(h.target) and h.target is FlagSpot:
		h.target.free()


## Q-345 (3): a hold target leaving the tree (a trap target freed when its trap goes) ends its holds before it
## is freed, so nothing reading `holds` (trap_race, sabotage, cart, scares) meets a freed target. FlagSpots are
## not in the tree; `_release` frees them.
func _on_target_gone(target: Node) -> void:
	for p in holds.keys():
		if holds[p].target == target:
			cancel(p, &"target_gone")


func cancel(peer: int, reason: StringName = &"released", notify: bool = true) -> void:
	if not holds.has(peer):
		return
	var h: Dictionary = holds[peer]
	holds.erase(peer)
	Log.event(&"hold_cancelled", {"player": peer, "verb": String(h.verb), "target": h.target.id if is_instance_valid(h.target) else "",
			"reason": String(reason), "progress": snappedf(h.progress, 0.01)})
	_release(h)
	if notify:  # false when the peer has already left
		_reply(peer, &"hold_cancelled", [h.verb, reason])


## P5-55: false when a world body (layer 1: walls, closed doors, ground) lies on the line from `from` to `to`, stopping `margin` m
## short of `to` so a target against a wall, or low on the ground, is not hidden by what it stands on. Shared with HoldController.pick.
static func line_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, margin: float, exclude: Array[RID] = []) -> bool:
	var d := to - from
	if d.length() <= margin:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to - d.normalized() * margin, 1)
	q.exclude = exclude
	return space.intersect_ray(q).is_empty()


## A door target's own DoorBlock and open leaves: the sight line ends inside them, so they never hide the door itself.
func _own_bodies(t: Node) -> Array[RID]:
	var doors = t.get(&"doors")
	return doors.own_bodies(t.id) if doors != null else ([] as Array[RID])


func _validate(peer: int, verb: StringName, id: String) -> StringName:
	var st: Dictionary = farm.pstate(peer)
	if Game.is_ghost(peer):
		return &"ghost"
	if not st.has("pos"):
		return &"no_body"
	if st.get("pinned", false) and verb != &"pry":
		return &"pinned"  # doc 03 section 7: a trapped player can only pry
	if st.get("held_prize", false) and not Interactable.base(verb) in [&"set_down_prize", &"load_cart", &"pry"]:
		return &"hands_full"  # D-084: the Prize Pumpkin takes both hands
	if holds.has(peer):
		return &"busy"
	if id.begins_with("flag:"):
		if FlagSpot.from_id(id) == Vector3.INF:
			return &"no_target"
	elif not farm.targets.has(id):
		return &"no_target"
	var t := _resolve(id)
	var reason := &"no_such_verb"
	if _flat_dist(st.pos, t.target_pos()) > t.range_m:
		reason = &"out_of_range"
	elif not line_clear(get_viewport().world_3d.direct_space_state, st.pos + Vector3.UP * 1.6, t.target_pos() + Vector3.UP, 0.5, _own_bodies(t)):
		reason = &"out_of_sight"  # P5-55: not through a wall (the client ray refuses it too, this is the host's word)
	elif Interactable.INSTANT_S.has(Interactable.base(verb)) or Interactable.fix_hold_s(verb) > 0.0 \
			or (Data.has_table(&"labor") and not Data.record(&"labor", Interactable.base(verb)).is_empty()):  # fix_hold_s: P3-06 sabotage
		reason = t.can_start(verb, st)
	_release({"target": t})
	return reason


func _physics_process(delta: float) -> void:
	for peer in holds.keys():
		if not holds.has(peer):
			continue  # cancelled by an earlier hold's completion this frame (P3-06 shared fixes)
		var h: Dictionary = holds[peer]
		var st: Dictionary = farm.pstate(peer)
		if Game.is_ghost(peer) or not Game.players.has(peer):
			cancel(peer, &"dead")
		elif not is_instance_valid(h.target) or _flat_dist(st.pos, h.target.target_pos()) > h.target.range_m + CANCEL_SLACK_M:
			cancel(peer, &"left_range")
		else:
			h.progress = HoldMath.advance(h.progress, delta, HoldMath.rate(_mults(peer, h)), h.hold_s)
			if h.progress >= 1.0:
				_complete(peer, h)


## Pry multipliers: the helper (doc 01 Day deaths, labor.json `helped_mult`): another living player prying
## the same trap within 3 m shortens the pry; Taint lengthens it (taint.json `pry_mult`, P3-07). Roles come
## with their task.
func _mults(peer: int, h: Dictionary) -> Array:
	if h.verb != &"pry":
		return []
	var out := []
	if Roles.of(peer) == &"medic":  # P4-09: a Medic frees someone else faster
		var race = h.target.get(&"race")
		if race != null and race.races.has(h.target.id) and race.races[h.target.id].victim != peer:
			out.append(float(Roles.perks(&"medic").pry_others_hold_mult))
	if bool(Game.players[peer].get("tainted", false)):
		out.append(float(Data.value(&"taint", &"taint", &"pry_mult")))
	for p in holds:
		var o: Dictionary = holds[p]
		if p != peer and o.verb == &"pry" and o.target == h.target and not Game.is_ghost(p) \
				and _flat_dist(farm.pstate(p).pos, farm.pstate(peer).pos) <= 3.0:
			out.append(float(Data.value(&"labor", &"pry", &"helped_mult")))
			break
	return out


func _complete(peer: int, h: Dictionary) -> void:
	var t = h.target
	var late: StringName = t.recheck(h.verb, farm.pstate(peer)) if t.has_method(&"recheck") else &""
	if late != &"":
		cancel(peer, late)
		return
	holds.erase(peer)
	var tid: String = t.id  # a flag spot is freed by _release below
	var elapsed := Log.now() - float(h.started)
	t.complete(h.verb, peer, farm.pstate(peer))
	Log.event(&"hold_completed", {"player": peer, "verb": String(h.verb), "target": t.id,
			"seconds": h.hold_s, "elapsed": snappedf(elapsed, 0.01)})
	farm.send_carry(peer)
	_release(h)
	_reply(peer, &"hold_done", [h.verb, tid])


func _reply(peer: int, what: StringName, args: Array) -> void:
	if peer == 1:
		Net.apply_received.emit(what, args)  # the host is its own client
	elif peer > 1:  # bots (negative ids, game/bots/) have no connection; they read `holds` instead
		Net.to_peers(StringName("apply_" + what), args, [peer])


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
