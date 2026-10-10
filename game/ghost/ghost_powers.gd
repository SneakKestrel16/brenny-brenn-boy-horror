extends Node
## P3-09, doc 01 "Ghosts", doc 05 section 14, doc 03 section 13: what a ghost can do. Added by Death.
## Host: validates every request (ghost only, per-ghost cooldowns, one crow a night), logs `ghost_action`
## or `ghost_action_refused`, and sends the result. Every peer: plays the light pattern (LightFlicker) and
## the ghost sounds. Local ghost only: the input, the crow view and ghost vision (the creature a smeared
## silhouette within 20 m, traps never shown).
## Keys while a ghost (no new actions): use_tool = the nearest lit light (or caw while in a crow),
## alt_use = rustle the corn you are in, lantern = take the nearest crow.
## P5-66: a possessed crow FLIES. The ghost sends its steer (a world direction from move + look: forward, turn, climb and
## dive follow the camera pitch) at 20 Hz; the host moves the crow (speed, altitude clamp, wall/roof blocking by a ray on
## layer 1) and broadcasts its position at 20 Hz; every peer draws one `animal_crow` flying (clip `fly`), the perch crow
## hidden. When the 20 s end the crow flies back to its perch on every peer, then lands (the perch crow shows again).
## Not built: the creature attacking a possessed crow (`dead_crow`).

const LightFlicker := preload("res://game/ghost/light_flicker.gd")

const COOLDOWN_S := {&"flicker": 8.0, &"rustle": 8.0, &"caw": 3.0}  ## placeholder: doc 01 says "short", no number
const REACH_M := 20.0  ## placeholder: how close a ghost must be to the light or perch it uses
const NEAR_LIVING_M := 15.0  ## placeholder: doc 01 "any light near a living teammate", no distance given
const CROW_S := 20.0  ## doc 01 "Ghosts": one crow a night for 20 s
const CROW_SIGHT_M := 30.0  ## placeholder (inference): beyond the 20 m ghost sight, or the crow adds nothing
const CROW_SPEED_MPS := 7.0  ## placeholder (inference): doc 01 gives no speed; about a sprint, so a scout can cross the farm in 20 s
const CROW_MIN_Y := 1.0  ## placeholder: stays off the ground
const CROW_MAX_Y := 8.0  ## placeholder: under the 10 m boundary walls (build_farm.py Bounds), so they still stop it
const CROW_RADIUS_M := 0.4  ## ray look-ahead: the crow stops this short of a wall or roof
const CROW_SEND_S := 0.05  ## 20 Hz steer up, 20 Hz position down
const CROW_STEER_STALE_MS := 400  ## no steer packet this long = the crow hovers (lost packets never run it away)
const CROW_RETURN_MPS := 8.0  ## flying back to the perch when the possession ends
const WORLD_MASK := 1  ## layer 1 world: buildings and the boundary walls
const SEE_CREATURE_M := 20.0  ## doc 01 "Ghosts > Vision", doc 04 section 8.4
const SMEAR := 0.6  ## creature silhouette transparency for a ghost (placeholder look until doc 07 gives one)
const CORN_MASK := 16  ## layer 5 corn

var _next: Dictionary = {}  ## host: peer -> {kind: msec when allowed again}
var _crow_day: Dictionary = {}  ## host: peer -> Clock.day of its crow
var _crows: Dictionary = {}  ## host: peer -> {id, until}
var _my_crow := ""  ## local: perch id while this ghost is in a crow
var _steer: Dictionary = {}  ## host: peer -> {dir, at (msec)}
var _flyers: Dictionary = {}  ## every peer: ghost peer -> {node, to, yaw, home, back, perch}
var _qa_shot_dir := ""  ## QA `--crow-shot=<dir>`: each peer saves one picture of a flying crow from 4 m behind
var _t := 0.0  ## send timer (host: positions down, local ghost: steer up)
var _vision := false  ## local: ghost vision applied


func _ready() -> void:
	add_to_group(&"ghost_powers")
	process_physics_priority = 100  # after the Player, so the crow view holds the camera at the perch
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--crow-shot="):
			_qa_shot_dir = a.substr("--crow-shot=".length())
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		Net.request_received.connect(_on_request)


func _on_request(what: StringName, peer: int, args: Array) -> void:
	match what:
		&"ghost_light":
			act(peer, &"flicker", String(args[0]))
		&"possess_crow":
			act(peer, &"crow", String(args[0]))
		&"crow_caw":
			act(peer, &"caw")
		&"crow_steer":
			if _crows.has(peer) and (args[0] as Vector3).is_finite():  # only the crow's own ghost; NaN would poison the crow
				_steer[peer] = {"dir": (args[0] as Vector3).limit_length(1.0), "at": Time.get_ticks_msec()}
		&"rustle":
			act(peer, &"rustle")


## Host only. Runs one ghost action for `peer`; `id` is the light or perch (empty: the nearest one).
## Returns "" when done, else the refusal reason (also logged).
func act(peer: int, kind: StringName, id := "") -> String:
	if kind == &"light":
		kind = &"flicker"  # the dev console's word (the other word stays in game/ghost/, doc 09 s9)
	var why := _try(peer, kind, id)
	if why != "":
		Log.event(&"ghost_action_refused", {"kind": String(kind), "peer": peer, "reason": why})
	return why


func _try(peer: int, kind: StringName, id: String) -> String:
	if not Game.is_ghost(peer):
		return "not_ghost"
	var now := Time.get_ticks_msec()
	var next: Dictionary = _next.get_or_add(peer, {})
	if now < int(next.get(kind, 0)):
		return "cooldown"
	var me: Vector3 = Game.players[peer].get("pos", Vector3.ZERO)
	var fields := {"kind": String(kind), "peer": peer}
	match kind:
		&"flicker":
			var rig := _light(id) if id != "" else _nearest_light(me)
			if rig == null:
				return "no_light"
			if rig.current_level() <= LightFlicker.LIT:
				return "unlit"  # off or blown out: never flickers (doc 03 s20)
			if rig.global_position.distance_to(me) > REACH_M:
				return "too_far"
			if not _living_near(rig.global_position):
				return "no_living_near"
			id = _light_id(rig)
			fields.light_id = id
			Net.to_peers(&"apply_flicker", [id])
			_on_apply(&"ghost_light", [id])
		&"rustle":
			if not _in_corn(me):
				return "not_in_corn"
			fields.position = [snappedf(me.x, 0.1), snappedf(me.z, 0.1)]
			_sound(&"rustle", Vector3(me.x, 0.0, me.z))
		&"crow":
			if _crow_day.get(peer, -1) == Clock.day:
				return "used_tonight"
			var perch := _perch(id) if id != "" else _nearest_perch(me)
			if perch == null:
				return "no_perch"
			if perch.global_position.distance_to(me) > REACH_M:
				return "too_far"
			for c in _crows.values():
				if c.id == perch.name:
					return "taken"
			_crow_day[peer] = Clock.day
			_crows[peer] = {"id": String(perch.name), "until": now + int(CROW_S * 1000.0), "pos": perch.global_position, "yaw": 0.0}
			fields.crow_id = String(perch.name)
			_send_crow(peer, String(perch.name))
		&"caw":
			if not _crows.has(peer):
				return "no_crow"
			fields.crow_id = _crows[peer].id
			_sound(&"caw", _crows[peer].pos)
		_:
			return "unknown"
	if COOLDOWN_S.has(kind):
		next[kind] = now + int(COOLDOWN_S[kind] * 1000.0)
	Log.event(&"ghost_action", fields)
	return ""


## One step of crow flight: `dir` (length <= 1, world space) at CROW_SPEED_MPS, altitude clamped, and the crow stays put
## when a wall, roof or boundary is in the way (ray on the world layer). Static so the check can drive it.
static func fly(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, delta: float) -> Vector3:
	var to := from + dir.limit_length(1.0) * CROW_SPEED_MPS * delta
	to.y = clampf(to.y, CROW_MIN_Y, CROW_MAX_Y)
	var ahead := to + (to - from).normalized() * CROW_RADIUS_M
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, ahead, WORLD_MASK))
	if not hit.is_empty():
		return from
	return to


func _physics_process(delta: float) -> void:
	_t += delta
	var tick := _t >= CROW_SEND_S
	if tick:
		_t = 0.0
	if Game.is_host():
		for p in _crows.keys():  # the crow lets go after 20 s, or when its ghost walks again
			if Time.get_ticks_msec() >= int(_crows[p].until) or not Game.is_ghost(p):
				_crows.erase(p)
				_steer.erase(p)
				_send_crow(p, "")
				continue
			var c: Dictionary = _crows[p]
			var st: Dictionary = _steer.get(p, {})
			var dir: Vector3 = st.dir if not st.is_empty() and Time.get_ticks_msec() - int(st.at) < CROW_STEER_STALE_MS else Vector3.ZERO
			c.pos = fly(get_viewport().world_3d.direct_space_state, c.pos, dir, delta)
			if Vector2(dir.x, dir.z).length() > 0.05:
				c.yaw = atan2(dir.x, dir.z)
			if tick:
				Net.to_peers(&"apply_crow_pos", [p, c.pos, c.yaw])
				_on_apply(&"crow_pos", [p, c.pos, c.yaw])
	if _my_crow != "":
		var pl := _local_player()
		var f: Dictionary = _flyers.get(Game.local_peer(), {})
		if pl and not f.is_empty():
			var eye: Vector3 = pl._cam.global_position - pl.global_position
			pl.global_position = f.node.global_position - eye  # the view rides the crow
			if tick and not Game.console_open:
				var d := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
				var want: Vector3 = pl._cam.global_transform.basis * Vector3(d.x, 0.0, d.y)
				Net.to_host(&"request_crow_steer", [want])


func _process(delta: float) -> void:
	_move_flyers(delta)
	var pl := _local_player()
	var on: bool = pl != null and pl.ghost
	var body := _creature_mesh()
	if on != _vision:
		_vision = on
		for n: Node3D in get_tree().get_nodes_in_group(&"trap_spots"):
			n.visible = not on  # every trap look (clue, sprung, pickup) hangs under its spot: ghosts never see traps
		if on and OS.get_cmdline_user_args().has("--ghost-auto"):
			_auto_run()
		if not on:
			_my_crow = ""
			if body:
				body.visible = true
				body.transparency = 0.0
	if not on or body == null:
		return
	var eye: Vector3 = pl._cam.global_position
	var sight := CROW_SIGHT_M if _my_crow != "" else SEE_CREATURE_M
	body.visible = body.global_position.distance_to(eye) <= sight
	body.transparency = SMEAR


func _unhandled_input(event: InputEvent) -> void:
	var pl := _local_player()
	if pl == null or not pl.ghost or Game.console_open:
		return
	for action in [&"use_tool", &"alt_use", &"lantern"]:
		if event.is_action_pressed(action):
			_use(action, pl.global_position)


## Local ghost: sends the request a key asks for. The host decides.
func _use(action: StringName, at: Vector3) -> void:
	if action == &"use_tool" and _my_crow != "":
		Net.to_host(&"request_crow_caw")
	elif action == &"use_tool":
		var rig := _nearest_light(at)
		if rig:
			Net.to_host(&"request_flicker", [_light_id(rig)])
	elif action == &"alt_use":
		Net.to_host(&"request_rustle")
	elif action == &"lantern":
		var perch := _nearest_perch(at)
		if perch:
			Net.to_host(&"request_possess_crow", [String(perch.name)])


## QA `--ghost-auto`: a fresh ghost presses each key once (light, rustle, crow), then caws from the crow.
func _auto_run() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or _local_player() == null:
		return
	for action in [&"use_tool", &"alt_use", &"lantern"]:
		_use(action, _local_player().global_position)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree() or _local_player() == null:
		return
	_use(&"use_tool", Vector3.ZERO)
	var body := _creature_mesh()
	Log.event(&"ghost_vision", {"traps_shown": get_tree().get_nodes_in_group(&"trap_spots").filter(
			func(n: Node3D) -> bool: return n.is_visible_in_tree()).size(), "creature_seen": body != null and body.visible,
			"creature_m": snappedf(body.global_position.distance_to(_local_player()._cam.global_position), 0.1) if body else -1.0})


func _on_apply(what: StringName, args: Array) -> void:
	var played := true
	match what:
		&"ghost_light":
			var rig := _light(String(args[0]))
			played = rig != null and LightFlicker.play(rig)
		&"ghost_sound":
			Soundscape.play_3d(&"sfx_step_corn" if args[0] == &"rustle" else &"sfx_crow_caw", args[1])
		&"crow_possessed":
			_set_flyer(int(args[0]), String(args[1]))
			if args[0] == Game.local_peer():
				_my_crow = String(args[1])
		&"crow_pos":
			if _flyers.has(int(args[0])):
				_flyers[int(args[0])].to = args[1]
				_flyers[int(args[0])].yaw = args[2]
			return
		_:
			return
	if not Game.is_host():  # QA: this peer applied it
		Log.event(&"ghost_action_seen", {"what": String(what), "args": str(args), "played": played})


func _sound(kind: StringName, pos: Vector3) -> void:
	Net.to_peers(&"apply_ghost_sound", [kind, pos])
	_on_apply(&"ghost_sound", [kind, pos])


func _send_crow(peer: int, crow_id: String) -> void:
	_on_apply(&"crow_possessed", [peer, crow_id])  # every peer draws the crow, not only its ghost
	Net.to_peers(&"apply_crow_possessed", [peer, crow_id])


## Every peer: the ghost `peer` took the crow at perch `id` (a flying crow appears, the perch crow hides) or let go
## (`id` ""; the flying crow heads home and lands).
func _set_flyer(peer: int, id: String) -> void:
	if id == "":
		if _flyers.has(peer):
			_flyers[peer].back = true
		return
	var perch := _perch(id)
	if perch == null:
		return
	if _flyers.has(peer):
		_land(peer)
	var node := (load("res://assets/models/animal_crow.glb") as PackedScene).instantiate() as Node3D
	add_child(node)
	node.global_position = perch.global_position
	for ap in node.find_children("*", "AnimationPlayer"):
		(ap as AnimationPlayer).get_animation(&"fly").loop_mode = Animation.LOOP_LINEAR
		(ap as AnimationPlayer).play(&"fly")
	_perch_crow(perch).visible = false
	_flyers[peer] = {"node": node, "to": perch.global_position, "yaw": 0.0, "home": perch.global_position, "back": false, "perch": perch}


func _perch_crow(perch: Node3D) -> Node3D:  # the scenery crow WorldProps put under the marker
	for c in perch.get_children():
		if c is Node3D:
			return c
	return Node3D.new()


func _land(peer: int) -> void:
	var f: Dictionary = _flyers[peer]
	f.node.queue_free()
	_flyers.erase(peer)
	for o: Dictionary in _flyers.values():
		if o.perch == f.perch:
			return  # another ghost holds this perch now
	_perch_crow(f.perch).visible = true


func _qa_shot(n: Node3D, peer: int) -> void:
	var cam := Camera3D.new()
	n.add_child(cam)
	cam.position = Vector3(0.0, 1.0, -4.0)
	cam.look_at(n.global_position)
	cam.make_current()
	for l: CanvasLayer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		l.visible = false  # the intro card and HUD hide the crow
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/crow_peer%d_of%d.png" % [_qa_shot_dir, Game.local_peer(), peer])
	cam.queue_free()


func _move_flyers(delta: float) -> void:
	for peer in _flyers.keys():
		var f: Dictionary = _flyers[peer]
		var n: Node3D = f.node
		if not f.back and _qa_shot_dir != "" and n.global_position.distance_to(f.home) > 12.0 and not f.has("shot"):
			f.shot = true
			_qa_shot(n, peer)
		if int(Time.get_ticks_msec() * 0.001) != f.get("logged", -1):
			f.logged = int(Time.get_ticks_msec() * 0.001)
			Log.event(&"crow_flyer_seen", {"peer": peer, "x": snappedf(n.global_position.x, 0.1), "y": snappedf(n.global_position.y, 0.1), "z": snappedf(n.global_position.z, 0.1), "back": f.back})
		var goal: Vector3 = f.home if f.back else f.to
		if f.back:
			var d := goal - n.global_position
			if d.length() <= CROW_RETURN_MPS * delta:
				_land(peer)
				continue
			n.global_position += d.normalized() * CROW_RETURN_MPS * delta
			f.yaw = atan2(d.x, d.z)
		else:
			n.global_position = n.global_position.lerp(goal, 1.0 - exp(-15.0 * delta))
		n.rotation.y = lerp_angle(n.rotation.y, f.yaw, 1.0 - exp(-10.0 * delta))


func _living_near(pos: Vector3) -> bool:
	for p in Game.players:
		if not Game.is_ghost(p) and pos.distance_to(Game.players[p].get("pos", Vector3.INF)) <= NEAR_LIVING_M:
			return true
	return false


func _in_corn(pos: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = Vector3(pos.x, 1.0, pos.z)
	q.collision_mask = CORN_MASK
	q.collide_with_areas = true
	return not get_viewport().world_3d.direct_space_state.intersect_point(q, 1).is_empty()


## A light's id is its `lightrig_spots` marker path, the same on every peer.
func _light_id(rig: LightRig) -> String:
	return String(_main().get_path_to(rig.get_parent()))


func _light(id: String) -> LightRig:
	var spot := _main().get_node_or_null(NodePath(id))
	if spot == null or not spot.is_in_group(&"lightrig_spots"):
		return null
	for c in spot.get_children():
		if c is LightRig:
			return c
	return null


func _nearest_light(pos: Vector3) -> LightRig:
	var best: LightRig = null
	for r: LightRig in get_tree().get_nodes_in_group(&"light_rigs"):
		if r.current_level() > LightFlicker.LIT and r.get_parent().is_in_group(&"lightrig_spots") \
				and (best == null or r.global_position.distance_to(pos) < best.global_position.distance_to(pos)):
			best = r
	return best


func _perch(id: String) -> Node3D:
	for n: Node3D in get_tree().get_nodes_in_group(&"crow_perches"):
		if n.name == id:
			return n
	return null


func _nearest_perch(pos: Vector3) -> Node3D:
	var best: Node3D = null
	for n: Node3D in get_tree().get_nodes_in_group(&"crow_perches"):
		if best == null or n.global_position.distance_to(pos) < best.global_position.distance_to(pos):
			best = n
	return best


func _creature_mesh() -> MeshInstance3D:
	var c := get_tree().get_first_node_in_group(&"creature")
	return c.find_children("*", "MeshInstance3D", false, false).pop_front() if c else null


func _main() -> Node:
	return get_parent().get_parent()  # GhostPowers sits under Death, under Main


func _local_player() -> Node:
	var players := _main().get_node_or_null("Players")
	return players.player(Game.local_peer()) if players else null
