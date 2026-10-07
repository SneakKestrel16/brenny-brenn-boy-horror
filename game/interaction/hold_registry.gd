extends Node
## Doc 05 section 7 (host only): one ActiveHold per player at most. Validates `request_hold`, ticks
## progress, completes or cancels, answers with `apply_*`, logs `hold_refused` / `hold_cancelled` /
## `hold_completed`. The Farm creates this node on the host only.

const HoldMath := preload("res://game/interaction/hold_math.gd")
const CANCEL_SLACK_M := 0.5  ## doc 05 section 7 step 4: range_m plus 0.5 (placeholder)

var farm: Node
var holds: Dictionary = {}  ## peer -> {verb, target, progress, hold_s, started}


func request(peer: int, verb: StringName, id: String) -> void:
	var reason := _validate(peer, verb, id)
	if reason != &"":
		Log.event(&"hold_refused", {"player": peer, "verb": String(verb), "target": id, "reason": String(reason)})
		_reply(peer, &"refused", [verb, reason])
		return
	holds[peer] = {"verb": verb, "target": farm.targets[id], "progress": 0.0, "hold_s": Data.hold_s(verb),
			"started": Log.now()}


func cancel(peer: int, reason: StringName = &"released") -> void:
	if not holds.has(peer):
		return
	var h: Dictionary = holds[peer]
	holds.erase(peer)
	Log.event(&"hold_cancelled", {"player": peer, "verb": String(h.verb), "target": h.target.id,
			"reason": String(reason), "progress": snappedf(h.progress, 0.01)})
	_reply(peer, &"hold_cancelled", [h.verb, reason])


func _validate(peer: int, verb: StringName, id: String) -> StringName:
	var st: Dictionary = farm.pstate(peer)
	if Game.is_ghost(peer):
		return &"ghost"
	if not st.has("pos"):
		return &"no_body"
	if holds.has(peer):
		return &"busy"
	if not farm.targets.has(id):
		return &"no_target"
	var t = farm.targets[id]
	if _flat_dist(st.pos, t.target_pos()) > t.range_m:
		return &"out_of_range"
	if not Data.has_table(&"labor") or Data.record(&"labor", verb).is_empty():
		return &"no_such_verb"
	return t.can_start(verb, st)


func _physics_process(delta: float) -> void:
	for peer in holds.keys():
		var h: Dictionary = holds[peer]
		var st: Dictionary = farm.pstate(peer)
		if Game.is_ghost(peer) or not Game.players.has(peer):
			cancel(peer, &"dead")
		elif not is_instance_valid(h.target) or _flat_dist(st.pos, h.target.target_pos()) > h.target.range_m + CANCEL_SLACK_M:
			cancel(peer, &"left_range")
		else:
			h.progress = HoldMath.advance(h.progress, delta, HoldMath.rate(_mults(peer, h.verb)), h.hold_s)
			if h.progress >= 1.0:
				_complete(peer, h)


## Phase 1 has no multipliers (roles, Taint, helpers come with their tasks); the hook is here.
func _mults(_peer: int, _verb: StringName) -> Array:
	return []


func _complete(peer: int, h: Dictionary) -> void:
	holds.erase(peer)
	var t = h.target
	var elapsed := Log.now() - float(h.started)
	t.complete(h.verb, peer, farm.pstate(peer))
	Log.event(&"hold_completed", {"player": peer, "verb": String(h.verb), "target": t.id,
			"seconds": h.hold_s, "elapsed": snappedf(elapsed, 0.01)})
	_reply(peer, &"hold_done", [h.verb, t.id])


func _reply(peer: int, what: StringName, args: Array) -> void:
	if peer == 1:
		Net.apply_received.emit(what, args)  # the host is its own client
	else:
		Net.to_peers(StringName("apply_" + what), args, [peer])


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
