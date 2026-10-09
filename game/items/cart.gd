extends "res://game/interaction/interactable.gd"
## P4-12 (doc 01 "Harvest Moon", doc 03 s14, doc 02 s9, doc 05 s13): the festival cart on `World/CartRoute`
## (R0 at the barn to the farm gate, doc 04 s6.1). Host-owned; every peer moves the body along the curve.
## Acts: 1 loading (the Harvest Moon starts), 2 push (the pumpkin is loaded: the generator fails), 3 gate run
## (the last `gate_run_m` of the route), then done. Pushing is a hold (`push_cart`) that never completes: the
## host counts the living players holding it, and the count sets the speed (`profile_harvest_moon`).
## The creature knocks a pusher off (`knock`, one per `knock_cooldown_s`); each stall lets it bite the pumpkin
## once (`bite`, the pumpkin caps it at 2). The route's end is the gate: `cart_out` when a living player is
## left (Q-130), the pumpkin is judged there and the Harvest Moon ends. At the cap (dawn) `settle` counts the
## cart out only past the fields (x > 78, doc 03 s14). SeasonAwards (P4-15) reads `cart_out` via group `cart`.

const Lights := preload("res://game/core/lights.gd")

signal left_gate  ## the cart went out of the gate with a living player (Q-130); every peer

const SYNC_EVERY_S := 1.0  ## placeholder: position resync while moving (Q-128)
const SQUEAK_EVERY_S := 1.0  ## placeholder: one squeak Noise per second while moving
const SQUEAK_M := 25.0  ## placeholder: no creature.json `noise_cart_squeak` row yet (Q-127)
const OUT_X := 78.0  ## doc 03 s14, doc 04 s6: past the fields
const BED_Y := 0.9  ## inference from prop_cart.glb (1.72 m tall with the lantern post); settle by eye
const KNOCK_CAMERA_S := 2.0  ## placeholder: the knocked pusher's knockdown camera
const LANTERN := Vector3(0.0, 1.86, -1.3)  ## front of the cart (it faces -Z along the route)

enum { PARKED, LOADING, PUSH, GATE_RUN, DONE }

var act := PARKED
var offset := 0.0  ## metres along the route
var length := 0.0
var loaded := false
var cart_out := false  ## Q-130: host-decided, replicated; win needs it (P4-15)
var pushers: Array = []  ## sorted peers pushing now
var stall_s := 0.0
var body: Node3D
var _path: Path3D
var _pr: Dictionary
var _t := 0.0
var _last_knock := -INF
var _bit := false  ## this stall's bite is taken
var _since_sync := 0.0
var _since_squeak := 0.0
var _spot: Node3D
var _squeak: AudioStreamPlayer3D
var _slot: Node3D
var _slot_bitten: Node3D


## The cart body under World and its interactable; `farm` attaches it. Null without a CartRoute (Phase 1 farm).
static func build(world: Node) -> Node3D:
	if world.get_node_or_null(^"CartRoute") == null:
		return null
	var b := Node3D.new()
	b.name = "Cart"
	var m: Node3D = load("res://assets/models/prop_cart.glb").instantiate()
	m.position.y = 0.86  # the glb is centred on its 1.72 m height
	b.add_child(m)
	var spot := Node3D.new()
	spot.name = "Lantern"
	spot.position = LANTERN
	spot.add_to_group(&"lightrig_spots")  # world_look puts the LightRig here; the ghost light system reaches it (doc 03 s14)
	spot.set_meta(&"radius_m", 7.0)  # doc 07 s5 cart lantern: #FFB45A, 7 m, 1.2 (LightRig defaults)
	spot.set_meta(&"own_power", true)  # oil, not the generator (lights.gd)
	var lamp: Node3D = load("res://assets/models/prop_cart_lantern.glb").instantiate()
	lamp.position.y = -0.14  # base origin; centre the glass on the rig's lamp
	spot.add_child(lamp)
	b.add_child(spot)
	world.add_child(b)
	return b


func _ready() -> void:
	add_to_group(&"cart")
	body = get_parent() as Node3D
	_path = body.get_parent().get_node(^"CartRoute") as Path3D
	length = _path.curve.get_baked_length()
	_pr = Data.record(&"ai_director", &"profile_harvest_moon")
	_spot = body.get_node(^"Lantern")
	range_m = 3.0  # the cart is 3 m long; pushers stand at its back (placeholder)
	for f in ["prop_cart_pumpkin_slot", "prop_cart_pumpkin_slot_bitten"]:
		var s: Node3D = load("res://assets/models/%s.glb" % f).instantiate()
		s.position.y = BED_Y
		s.visible = false
		body.add_child(s)
		if _slot == null:
			_slot = s
		else:
			_slot_bitten = s
	_squeak = AudioStreamPlayer3D.new()
	var c: Dictionary = Soundscape.CATALOG[&"sfx_cart_squeak_loop"]
	_squeak.stream = Soundscape._stream("sfx_cart_squeak_loop", true)
	_squeak.bus = c.bus
	_squeak.unit_size = c.unit
	_squeak.max_distance = c.max
	_squeak.volume_db = c.db
	body.add_child(_squeak)
	Net.apply_received.connect(_on_apply)
	_place()


static func speed_for(n: int, pr: Dictionary) -> float:
	return 0.0 if n <= 0 else float(pr["cart_speed_%dp_mps" % mini(n, 4)])


func pos_at(off: float) -> Vector3:
	return _path.to_global(_path.curve.sample_baked(clampf(off, 0.0, length)))


func moving() -> bool:
	return act in [PUSH, GATE_RUN] and stall_s <= 0.0 and not pushers.is_empty()


# ---- interaction ----

func _pumpkin() -> Node:
	return farm.targets.get("prize_pumpkin") if farm else null


func _carrying(st: Dictionary) -> bool:
	var pk := _pumpkin()
	return pk != null and pk.carrier != 0 and pk.carrier == int(st.get("peer", Game.local_peer()))


func verbs_for(st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if Clock.phase == &"harvest_moon" and act != DONE:
		out.append(&"load_cart" if not loaded and _carrying(st) else &"push_cart")
	return out


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if not verb in [&"load_cart", &"push_cart"]:
		return &"no_such_verb"
	if Clock.phase != &"harvest_moon":
		return &"not_harvest_moon"
	if act == DONE:
		return &"cart_done"
	if verb == &"load_cart":
		return &"loaded" if loaded else (&"" if _carrying(st) else &"not_holding")
	if stall_s > 0.0:
		return &"stalled"
	var pk := _pumpkin()
	return &"not_loaded" if not loaded and pk != null and pk.planted else &""


func on_start(verb: StringName, _peer: int) -> void:
	if verb == &"push_cart" and act == LOADING:
		_begin_push()  # no pumpkin was planted: the first push starts act 2


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	if verb != &"load_cart":
		return
	var pk := _pumpkin()
	pk.carrier = 0
	st.erase("held_prize")
	loaded = true
	Log.event(&"cart_loaded", {"player": peer, "size": String(pk.size_name())})
	pk._send()
	_begin_push()


## Host: act 2. Doc 01 "Harvest Moon": once the cart is loaded the generator fails and the barn goes dark.
func _begin_push() -> void:
	act = PUSH
	var gen := farm.get_parent().get_node_or_null(^"Generator")
	if gen:
		gen.damage()
	Log.event(&"cart_act", {"act": 2})
	_send()


# ---- host ----

func on_phase(ph: StringName) -> void:
	if ph == &"harvest_moon" and act == PARKED:
		act = LOADING
		Log.event(&"cart_act", {"act": 1})
		_send()
	elif ph == &"dawn":
		settle()


## Host, at the cap or the final dawn (idempotent): out only past the fields.
func settle() -> void:
	if act in [LOADING, PUSH, GATE_RUN]:
		finish(body.global_position.x > OUT_X, &"cap")


func finish(out: bool, reason: StringName) -> void:
	if act == DONE:
		return
	act = DONE
	stall_s = 0.0
	pushers.clear()
	cart_out = out and _alive() > 0
	var pk := _pumpkin()
	Log.event(&"cart_finished", {"reason": String(reason), "x": snappedf(body.global_position.x, 0.1),
			"offset_m": snappedf(offset, 0.1), "loaded": loaded, "cart_out": cart_out, "bites": pk.bites if pk else 0})
	if cart_out:
		Log.event(&"cart_out", {"alive": _alive(), "loaded": loaded})
		left_gate.emit()
	if loaded and cart_out:
		pk.judge(farm)  # D-084: judging moves from the final sale to the cart's finish
	for p in farm.registry.holds.keys():
		if farm.registry.holds[p].target == self:
			farm.registry.cancel(p, &"cart_done")
	_send()
	if reason != &"cap":
		Clock.end_harvest_moon.call_deferred()


func _alive() -> int:
	var n := 0
	for p in Game.players:
		n += int(not Game.is_ghost(p))
	return n


## Host: the creature hit pusher `peer` (doc 03 s14). False when it may not (act, cooldown, stall).
func knock(peer: int) -> bool:
	if not knock_ready() or not pushers.has(peer):
		return false
	_last_knock = _t
	stall_s = float(_pr.knock_stall_s)
	_bit = false
	farm.registry.cancel(peer, &"knocked")
	pushers.erase(peer)
	Log.event(&"cart_knock", {"player": peer, "x": snappedf(body.global_position.x, 0.1), "stall_s": stall_s})
	_send(peer)
	return true


## Host: act 2, not stalled, and `harvest_knock_cooldown_s` since the last knock-off (doc 03 s14).
func knock_ready() -> bool:
	return act == PUSH and stall_s <= 0.0 and _t - _last_knock >= float(_pr.knock_cooldown_s)


## Host: one bite per stall; the pumpkin caps the escort at `max_escort_bites`.
func bite() -> bool:
	if stall_s <= 0.0 or _bit or not loaded:
		return false
	_bit = true
	return _pumpkin().bite()


func _physics_process(delta: float) -> void:
	if not Game.is_host():
		return
	_t += delta
	if act in [PARKED, DONE]:
		return
	if _alive() == 0:
		finish(false, &"all_dead")
		return
	if act == LOADING:
		return
	var now: Array = []
	for p in farm.registry.holds:
		var h: Dictionary = farm.registry.holds[p]
		if h.target == self and h.verb == &"push_cart" and not Game.is_ghost(p):
			now.append(p)
	now.sort()
	var dirty := now != pushers
	pushers = now
	if stall_s > 0.0:
		stall_s = maxf(stall_s - delta, 0.0)
		dirty = dirty or stall_s == 0.0
	elif not pushers.is_empty():
		offset = minf(offset + speed_for(pushers.size(), _pr) * delta, length)
		_since_squeak += delta
		if _since_squeak >= SQUEAK_EVERY_S:
			_since_squeak = 0.0
			NoiseBus.emit(body.global_position, SQUEAK_M, &"cart_squeak", 0)
	if act == PUSH and offset >= length - float(_pr.gate_run_m):
		act = GATE_RUN
		Log.event(&"cart_act", {"act": 3})
		dirty = true
	if offset >= length:
		finish(true, &"gate")
		return
	_since_sync += delta
	if dirty or (moving() and _since_sync >= SYNC_EVERY_S):
		_send()


# ---- every peer: look ----

func _process(delta: float) -> void:
	if not Game.is_host() and moving():
		offset = minf(offset + speed_for(pushers.size(), _pr) * delta, length)  # predicted; the host's value snaps it
	if not Game.is_host() and stall_s > 0.0:
		stall_s = maxf(stall_s - delta, 0.0)
	_place()
	var rig := _rig()
	if rig:
		Lights.set_own(rig, act in [LOADING, PUSH, GATE_RUN])
	var go := moving()
	_spot.rotation.x = sin(Time.get_ticks_msec() / 300.0) * (0.12 if go else 0.0)  # doc 07 s5: swings with the cart
	if go != _squeak.playing and _squeak.stream:
		if go:
			_squeak.play()
		else:
			_squeak.stop()
	_squeak.pitch_scale = 0.85 + 0.1 * mini(pushers.size(), 4)
	var pk := _pumpkin()
	_slot.visible = loaded and (pk == null or pk.bites == 0)
	_slot_bitten.visible = loaded and pk != null and pk.bites > 0



func _rig() -> Node:
	for c in _spot.get_children():
		if c is LightRig:
			return c
	return null


func _place() -> void:
	var p := pos_at(offset)
	var ahead := pos_at(offset + 0.5) if offset + 0.5 <= length else p + (p - pos_at(offset - 0.5))
	body.global_position = p
	if ahead.distance_to(p) > 0.01:
		body.look_at(Vector3(ahead.x, p.y, ahead.z), Vector3.UP)


# ---- replication ----

func _args(knocked: int = 0) -> Array:
	return [offset, act, loaded, pushers, stall_s, cart_out, knocked]


func _send(knocked: int = 0) -> void:
	_since_sync = 0.0
	farm._broadcast(&"cart", _args(knocked))


func snapshot_to(peer: int) -> void:
	Net.to_peers(&"apply_cart", _args(), [peer])


func _on_apply(what: StringName, args: Array) -> void:
	if what != &"cart":
		return
	var was_out := cart_out
	var was_act := act
	if not Game.is_host():
		offset = float(args[0])
		act = int(args[1])
		loaded = bool(args[2])
		pushers = args[3]
		stall_s = float(args[4])
		cart_out = bool(args[5])
		if cart_out and not was_out:
			left_gate.emit()
		if act != was_act or cart_out != was_out:
			Log.event(&"cart_seen", {"act": act, "offset_m": snappedf(offset, 0.1), "pushers": pushers.size(), "cart_out": cart_out})
	var knocked := int(args[6])
	if knocked != 0 and knocked == Game.local_peer():
		var pl: Node = farm.get_parent().get_node_or_null(^"Players")
		if pl and pl.player(knocked):
			pl.player(knocked).knockdown_camera(KNOCK_CAMERA_S)
