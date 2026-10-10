extends CharacterBody3D
## Doc 05 section 6: one Player per peer. The local one reads input, owns movement and camera and
## streams `move` frames; a remote one is a proxy that smooths toward the latest `moves` target.

const EYE_STAND := 1.65  ## CONTRACTS section 3
const HEIGHT_STAND := 1.8
const HEIGHT_CROUCH := 1.1  ## placeholder: no crouch height in the docs
const EYE_CROUCH := 0.95  ## placeholder
const RADIUS := 0.35  ## placeholder
const GRAVITY := 20.0
const JUMP_V := 5.0  ## P5-10 low gravity jump speed, m/s (placeholder; with 0.2 gravity it floats about 3 m up for 2.5 s)
const RESUME_S := 1.5  ## placeholder: stamina needed to sprint again after running dry (doc 02 section 2.2 gives max and refill only)
const TaintScript := preload("res://game/player/taint.gd")
const FarmerBody := preload("res://game/player/farmer_body.gd")
const PROXY_SMOOTH := 15.0  ## exponential smoothing rate for proxies (ponytail: no snapshot buffer)

var peer := 0
var colour_slot := 0  ## P5-13 (D-159): index into FarmerBody.COLOURS; Players sets it on every peer before the body is made
var is_local := false
var players: Node  ## the Players manager

var yaw := 0.0
var pitch := 0.0
var crouching := false
var stamina := 0.0  ## seconds of sprint left (doc 02 section 2.2)
var exhausted := false  ## ran dry: no sprint until `stamina` refills to RESUME_S (stops a per-frame flip at 0)
var ghost := false  ## dead: flies, no collision, no sound (set by Death on every peer)
var pinned := false  ## caught in a bear trap: cannot move (TrapRace sets it on every peer)
var speed_mult := 1.0  ## slowed after a bear trap (doc 01 "Night Traps") or locked in the shed; the host mirrors it
var _shaken_s := 0.0  ## seconds left of `speed_mult` (the name predates P3-07 Shaken, which is `shaken_s`)
var shaken_s := 0.0  ## P3-07 Shaken (doc 01 "The Taint"): sprint time x0.6 while above 0, host-told
var _spec := 0  ## ghost: peer being watched, 0 = free flight

var nav_path: Array = []  ## QA waypoints for `--autochore` (HoldController fills it)
var _cam: Camera3D
var _held: Node3D
var _water_can: MeshInstance3D
var _fuel_can: MeshInstance3D
var _shovel: MeshInstance3D  ## P2-11 placeholder props
var _trap_prop: MeshInstance3D
var _shape: CollisionShape3D
var _mesh: FarmerBody  ## P5-13: the rigged farmer (FarmerBody), origin at the feet
var _emote_s := 0.0  ## seconds left of an emote animation
var _prev_pos := Vector3.ZERO
var _seq := 0
var _send_t := 0.0
var _sprint_any := false  ## sprinted at any point since the last packet (the host judges the whole interval's speed)
var _crouch_all := true  ## crouched for the whole interval
var _target_pos := Vector3.ZERO
var _autowalk := false  ## QA: `-- --autowalk` walks in a circle with no input (multi-instance tests)
var _t := 0.0
var _eye := EYE_STAND  ## smoothed eye height; the head bob rides on it
var _bob := 0.0  ## head bob phase
var _sprint_on := false  ## toggle_sprint (D-047): sprint stays on until you stop, run dry or crouch
var body_scale := 1.0  ## P5-10 dev toys (doc 01 "Dev toys"): shrink, 0.25; body, eye and camera follow
var head_scale := 1.0  ## P5-10: big heads, 3.0
var gravity_scale := 1.0  ## P5-10: low gravity
var jump_ok := false  ## P5-10: low gravity also turns on a jump (Space); the game has no jump otherwise (inference, see doc 05 s25)
var _head: MeshInstance3D  ## P5-10: made on first use
var _toy_tw: Tween
var _pushing := false  ## P4-32: locked to a festival cart handle slot (cart.push_slot)
var _cart_yaw := 0.0  ## P4-32: the cart heading last frame, so the pusher turns with the route


func _ready() -> void:
	collision_layer = 2  # player
	collision_mask = 1 if is_local else 0  # world blocks the body; corn (layer 5) is walkable, sight/sound only
	_shape = CollisionShape3D.new()
	_shape.shape = CapsuleShape3D.new()
	add_child(_shape)
	_mesh = FarmerBody.new(colour_slot)
	add_child(_mesh)
	_apply_height(false)
	_cam = Camera3D.new()
	_cam.position.y = EYE_STAND
	add_child(_cam)
	_target_pos = global_position
	_make_held()
	Net.apply_received.connect(_on_carry)
	if is_local:
		_cam.current = true
		_cam.fov = float(Settings.get_value(&"fov"))
		Settings.changed.connect(func(k: StringName) -> void: if k == &"fov": _cam.fov = float(Settings.get_value(&"fov")))
		_mesh.visible = false
		stamina = float(Data.value(&"labor", &"sprint", &"max_s"))
		_autowalk = OS.get_cmdline_user_args().has("--autowalk")
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Net.teleport_received.connect(func(p: Vector3) -> void: global_position = p)
		var hc := Node.new()
		hc.set_script(preload("res://game/interaction/hold_controller.gd"))
		hc.name = "HoldController"
		add_child(hc)
		var hud := CanvasLayer.new()  # P1-16: plain text HUD (game/ui/hud.gd), local player only
		hud.set_script(preload("res://game/ui/hud.gd"))
		hud.name = "Hud"
		hud.player = self
		hud.hold = hc
		add_child(hud)
	Log.event(&"player_spawned", {"peer": peer, "local": is_local})


## Placeholder in-hand props (no art yet), children of the camera so the owner and everyone else see
## them at the same spot: a blue watering can (pale when empty) and a red fuel can (replaces it while carried).
func _make_held() -> void:
	_held = Node3D.new()
	_held.position = Vector3(0.35, -0.35, -0.6)
	_cam.add_child(_held)
	_water_can = _prop(Vector3(0.22, 0.22, 0.3), Color(0.5, 0.58, 0.64))
	_water_can.visible = false
	_fuel_can = _prop(Vector3(0.2, 0.3, 0.14), Color(0.85, 0.15, 0.1))
	_fuel_can.visible = false
	_shovel = _prop(Vector3(0.08, 0.08, 1.1), Color(0.45, 0.32, 0.18))  # long wooden handle
	_shovel.position = Vector3(0.15, 0.05, -0.2)
	_shovel.visible = false
	_trap_prop = _prop(Vector3(0.35, 0.08, 0.35), Color(0.2, 0.2, 0.22))  # a disarmed bear trap, dark iron
	_trap_prop.position = Vector3(-0.35, 0.0, 0.0)
	_trap_prop.visible = false
	var farm := get_tree().get_first_node_in_group(&"farm")  # a late spawn still shows what the farm already knows
	if farm and farm.carry.has(peer):
		var c: Dictionary = farm.carry[peer]
		_on_carry(&"carry", [peer, c.can, c.bag, c.fuel_can])
		_on_carry(&"hands", [peer, c.get("shovel", false), c.get("trap", false)])


func _prop(size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	_held.add_child(mi)
	return mi


func _on_carry(what: StringName, args: Array) -> void:
	if what == &"hands" and args[0] == peer:
		_shovel.visible = bool(args[1])
		_trap_prop.visible = bool(args[2])
		return
	if what == &"cans_applied" and farm_has_carry():
		var c: Dictionary = get_tree().get_first_node_in_group(&"farm").carry[peer]
		what = &"carry"
		args = [peer, c.can, c.bag, c.fuel_can]
	if what != &"carry" or args[0] != peer:
		return
	# D-054: a can shows in hand only while this player carries one (kind and fullness from the carry state)
	var farm := get_tree().get_first_node_in_group(&"farm")
	var kind: StringName = farm.carry.get(peer, {}).get("held_kind", &"") if farm else &""
	_fuel_can.visible = kind == &"fuel"
	_water_can.visible = kind == &"water"
	(_fuel_can.material_override as StandardMaterial3D).albedo_color = Color(0.85, 0.15, 0.1) if bool(args[3]) else Color(0.4, 0.15, 0.12)
	(_water_can.material_override as StandardMaterial3D).albedo_color = Color(0.15, 0.4, 0.95) if int(args[1]) > 0 else Color(0.5, 0.58, 0.64)  # galvanized gray-blue when empty


func farm_has_carry() -> bool:
	var farm := get_tree().get_first_node_in_group(&"farm")
	return farm != null and farm.carry.has(peer)


func _apply_height(crouch: bool) -> void:
	var h := (HEIGHT_CROUCH if crouch else HEIGHT_STAND) * body_scale
	var r := RADIUS * body_scale
	(_shape.shape as CapsuleShape3D).height = h
	(_shape.shape as CapsuleShape3D).radius = r
	_shape.position.y = h / 2.0
	_mesh.scale = Vector3.ONE * body_scale  # crouching is the farmer's crouch animation, not a squash
	_mesh.position = Vector3.ZERO
	if _head:
		var s := head_scale * body_scale
		_head.scale = Vector3.ONE * s
		_head.position.y = h + 0.12 * s


## P5-10 dev toys (every peer, visual and collision size only; the host's speed check is untouched).
func set_body_scale(s: float) -> void:
	body_scale = s
	_apply_height(crouching)


## P5-10: a head sphere on the body, `s` times its size (1 hides it).
func set_head_scale(s: float) -> void:
	head_scale = s
	if _head == null and s != 1.0:
		_head = MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.18
		sp.height = 0.36
		_head.mesh = sp
		add_child(_head)
	_apply_height(crouching)


## P5-10 disco: one frame of the dance at time `t` (bob 1.5 per second, a slow spin). Visual only; `dance_end` undoes it.
func dance(t: float) -> void:
	_mesh.rotation.y = t * 2.0
	_mesh.position.y = 0.15 * absf(sin(t * PI * 1.5))


func dance_end() -> void:
	_mesh.rotation = Vector3.ZERO
	_apply_height(crouching)


## P5-10 nuke: thrown `dir` (world, flat) and back over `secs`, tumbling, as a body and as a gentle camera roll.
## Visual only: the position the host and the others track never moves.
func ragdoll(dir: Vector3, secs: float) -> void:
	if _toy_tw:
		_toy_tw.kill()
	var ld := global_transform.basis.inverse() * dir
	var base := 0.0
	_toy_tw = create_tween()
	_toy_tw.tween_method(_ragdoll_pose.bind(ld, base), 0.0, 1.0, secs)
	_toy_tw.tween_callback(func() -> void:
		_mesh.rotation = Vector3.ZERO
		_cam.rotation.z = 0.0
		_apply_height(crouching))


func _ragdoll_pose(k: float, ld: Vector3, base: float) -> void:
	var arc := sin(k * PI)
	_mesh.position = Vector3(ld.x * 6.0 * arc, base + 2.5 * arc, ld.z * 6.0 * arc)
	_mesh.rotation.x = k * TAU * 2.0
	_cam.rotation.z = 0.35 * arc


## Proxies and the host's relay: where the latest frame says this player is.
func set_target(pos: Vector3, p_yaw: float, p_pitch: float, crouch: bool) -> void:
	_target_pos = pos
	yaw = p_yaw
	pitch = p_pitch
	if crouch != crouching:
		crouching = crouch
		_apply_height(crouch)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := float(Settings.get_value(&"mouse_sensitivity"))
		yaw -= event.relative.x * s
		pitch = clampf(pitch + event.relative.y * s * (1.0 if bool(Settings.get_value(&"invert_y")) else -1.0), -1.5, 1.5)  # D-047 invert Y
	elif event.is_action_pressed(&"crouch") and bool(Settings.get_value(&"toggle_crouch")):
		_set_crouch(not crouching)
	elif event.is_action_pressed(&"sprint") and bool(Settings.get_value(&"toggle_sprint")) and not Game.console_open:
		_sprint_on = not _sprint_on


func _set_crouch(c: bool) -> void:
	if c == crouching:
		return
	crouching = c  # ponytail: no stand-up headroom check, nothing low to hide under yet
	_apply_height(c)


func _physics_process(delta: float) -> void:
	if is_local:
		_local(delta)
	else:
		global_position = global_position.lerp(_target_pos, 1.0 - exp(-PROXY_SMOOTH * delta))
		var ghost_view := Game.is_ghost(Game.local_peer())
		_mesh.visible = not ghost or ghost_view  # ghosts are seen only by ghosts
		# Doc 01 "Static voices": the living hear a ghost only through static; Voice puts a ghost's emitter
		# on the ghost static chain (P3-10), so here only the per-player volume applies.
		var ve := get_node_or_null("VoiceEmitter") as AudioStreamPlayer3D
		if ve:
			ve.volume_db = _peer_gain_db()
	_held.visible = not ghost
	_animate(delta)
	if _head:
		_head.visible = head_scale != 1.0 and _mesh.visible
	rotation.y = yaw
	_cam.rotation.x = pitch
	_eye = lerpf(_eye, (EYE_CROUCH if crouching else EYE_STAND) * body_scale, 1.0 - exp(-12.0 * delta))
	_cam.position.y = _eye + _head_bob(delta)


## D-047 head bob: a small vertical sway while walking, scaled by `camera_shake`. Local view only; nothing else reads it.
func _head_bob(delta: float) -> float:
	var k := float(Settings.get_value(&"camera_shake"))
	if not is_local or ghost or k <= 0.0:
		return 0.0
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	_bob = fmod(_bob + (Vector2(velocity.x, velocity.z).length() * 1.6 * delta if moving else 0.0), TAU)
	return sin(_bob) * 0.03 * k if moving else 0.0


## D-047 knockdown camera: the view tumbles to the side and gets up. `camera_shake` 0 keeps it level.
## Nothing calls it yet (no knockdown in Phase 2 so far); the creature work calls it on the local player.
func knockdown_camera(seconds: float) -> void:
	var k := float(Settings.get_value(&"camera_shake"))
	if not is_local or k <= 0.0:
		return
	var tw := create_tween()
	tw.tween_property(_cam, "rotation:z", 1.2 * k, 0.25)
	tw.tween_interval(maxf(seconds - 0.75, 0.0))
	tw.tween_property(_cam, "rotation:z", 0.0, 0.5)


## D-047: this listener's volume for this speaker; 0 is mute.
func _peer_gain_db() -> float:
	var v := Settings.peer_volume(peer)
	return linear_to_db(v) if v > 0.0 else -80.0


## Seconds of sprint a full tank holds now: Taint and Shaken shorten it (doc 02 section 13, P3-07).
func sprint_max() -> float:
	return float(Data.value(&"labor", &"sprint", &"max_s")) * TaintScript.sprint_mult(
			bool(Game.players.get(peer, {}).get("tainted", false)), shaken_s > 0.0,
			float(Data.value(&"taint", &"taint", &"sprint_mult")), float(Data.value(&"taint", &"shaken", &"sprint_mult")))


## Host-told slow (TrapRace after a bear trap, Scares' shed lock): all speeds x `mult` for `seconds`.
func shake(seconds: float, mult: float) -> void:
	_shaken_s = seconds
	speed_mult = mult


## P3-11 (doc 05 s14), P5-13: an emote on this body, every peer: the farmer's wave, point, shrug or scream
## animation. The owner sees nothing on itself (first person, its mesh is hidden).
func play_emote(kind: StringName) -> void:
	if kind in [&"wave", &"point", &"shrug", &"scream"] and _mesh.has_anim(kind):
		_emote_s = _mesh.shot(kind)


## Locomotion animation from the speed this body actually moves (local and proxy alike); an emote plays out first.
func _animate(delta: float) -> void:
	var v := Vector2(global_position.x - _prev_pos.x, global_position.z - _prev_pos.z).length() / maxf(delta, 0.0001)
	_prev_pos = global_position
	if v > 20.0:
		v = 0.0  # a spawn or teleport, not a run
	if _emote_s > 0.0:
		_emote_s -= delta
		if _emote_s > 0.0:
			return
	var walk := Data.speed(&"walk")
	if crouching:
		_mesh.loop(&"crouch", 1.0 if v < 0.3 else 1.5)
	elif v > walk * 1.3:
		_mesh.loop(&"run", clampf(v / Data.speed(&"sprint"), 0.8, 1.3))
	elif v > 0.3:
		_mesh.loop(&"walk", clampf(v / walk, 0.6, 1.4))
	else:
		_mesh.loop(&"idle")


## Dead (doc 05 section 14): no body, no collision. Local: fly with the camera. Others: hidden from the living.
func become_ghost() -> void:
	ghost = true
	pinned = false
	_spec = 0
	collision_mask = 0


func respawn(pos: Vector3) -> void:
	ghost = false
	_spec = 0
	global_position = pos
	_target_pos = pos
	velocity = Vector3.ZERO
	collision_mask = 1 if is_local else 0


## Ghost: `spectate_next` / `spectate_prev` follow a living player; any move input goes back to free flight.
func _spectate(dir: Vector2, delta: float) -> void:
	var living: Array = players._players.keys().filter(func(p: int) -> bool: return p != peer and not Game.is_ghost(p))
	living.sort()
	if dir != Vector2.ZERO:
		_spec = 0
	elif living.is_empty():
		_spec = 0
	elif Input.is_action_just_pressed(&"spectate_next") or Input.is_action_just_pressed(&"spectate_prev"):
		var i := living.find(_spec)
		var step := 1 if Input.is_action_just_pressed(&"spectate_next") else -1
		_spec = living[(i + step + living.size()) % living.size()] if i >= 0 else living[0]
	if _spec != 0 and Game.is_ghost(_spec):
		_spec = 0
	if _spec != 0:
		var t: Node3D = players.player(_spec)
		# The watched player's yaw arrives in 20 Hz steps; orbiting their raw rotation made the view jump
		# whenever they turned. Smooth the yaw and place the camera from the smoothed value.
		var k := 1.0 - exp(-10.0 * delta)
		yaw = lerp_angle(yaw, t.yaw, k)
		global_position = global_position.lerp(t.global_position + Vector3(sin(yaw), 0, cos(yaw)) * 2.0 + Vector3(0, 1.0, 0), k)


func _local_ghost(delta: float) -> void:
	var dir := Vector2.ZERO if Game.console_open else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_spectate(dir, delta)
	if _spec == 0:
		var fly := (_cam.global_transform.basis * Vector3(dir.x, 0, dir.y)) * Data.speed(&"sprint")
		global_position += fly * delta
	_send_t += delta
	if _send_t >= 1.0 / players.SEND_HZ:
		_send_t = 0.0
		_seq += 1
		players.submit_local(_seq, global_position, yaw, pitch, false, true)


func _local(delta: float) -> void:
	if ghost:
		_local_ghost(delta)
		return
	_t += delta
	if _shaken_s > 0.0:
		_shaken_s -= delta
		if _shaken_s <= 0.0:
			speed_mult = 1.0
	shaken_s = maxf(shaken_s - delta, 0.0)
	var typing := Game.console_open  # D-031: keys go to the dev console, not the body
	var still := not typing and Input.is_action_pressed(&"go_still")  # doc 05 section 6: freezes the body, sends nothing special
	var dir := Vector2.ZERO if typing else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var want_sprint := not typing and (_sprint_on if bool(Settings.get_value(&"toggle_sprint")) else Input.is_action_pressed(&"sprint"))
	if _autowalk:
		yaw = _t * 0.5
		dir = Vector2(0, -1)
		want_sprint = fmod(_t, 8.0) > 4.0 or OS.get_cmdline_user_args().has("--autosprint")  # QA: sprint held, stamina runs dry
	if not nav_path.is_empty():  # QA: walk to the next waypoint (`--autochore`), facing it
		var d: Vector3 = nav_path[0] - global_position
		d.y = 0.0
		if d.length() < 0.3:
			nav_path.pop_front()
		else:
			yaw = atan2(-d.x, -d.z)
			dir = Vector2(0, -1)
			want_sprint = false  # walking: a stamina-flipping sprint trips the host speed check
	if not bool(Settings.get_value(&"toggle_crouch")) and not typing:
		_set_crouch(Input.is_action_pressed(&"crouch"))
	var cart := get_tree().get_first_node_in_group(&"cart")
	var slot: Vector3 = cart.push_slot(peer) if cart else Vector3.INF
	if slot != Vector3.INF:
		# P4-32: face along the route at lock start, then turn with the cart as the route bends; the mouse
		# look stays free on top of that.
		var cy: float = cart.body.global_rotation.y
		yaw = cy if not _pushing else yaw + angle_difference(_cart_yaw, cy)
		_cart_yaw = cy
	_pushing = slot != Vector3.INF
	if still or pinned or _pushing:
		dir = Vector2.ZERO
	var sprint_rec := Data.record(&"labor", &"sprint")
	if exhausted and stamina >= RESUME_S:
		exhausted = false
	var sprinting := want_sprint and not crouching and dir != Vector2.ZERO and stamina > 0.0 and not exhausted
	if _sprint_on and (dir == Vector2.ZERO or exhausted or crouching or not sprinting):
		_sprint_on = false  # toggled sprint ends when you stop, run dry or crouch
	if sprinting:
		stamina = maxf(stamina - delta, 0.0)
		exhausted = stamina <= 0.0
	else:
		stamina = minf(stamina + float(sprint_rec["max_s"]) / float(sprint_rec["refill_s"]) / float(Quirks.local(&"sprint_refill_mult")) * delta, sprint_max())
	stamina = minf(stamina, sprint_max())  # Tainted or Shaken mid-sprint: the shorter tank
	var quirk_mult := float(Quirks.local(&"crouch_speed_mult") if crouching else (1.0 if sprinting else Quirks.local(&"walk_speed_mult")))  # P5-09 Hoarding disorder
	var speed := Data.speed(&"crouch" if crouching else (&"sprint" if sprinting else &"walk")) * speed_mult * quirk_mult
	var wish := (global_transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * speed
	if _pushing:  # P4-32: held at the handle slot, moving with the cart (the host pins the same spot)
		wish = Vector3(slot.x - global_position.x, 0.0, slot.z - global_position.z) / delta
	velocity.x = wish.x
	velocity.z = wish.z
	if jump_ok and is_on_floor() and not Game.console_open and Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = JUMP_V  # P5-10 low gravity only
	elif is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * gravity_scale * delta
	move_and_slide()
	_sprint_any = _sprint_any or sprinting
	_crouch_all = _crouch_all and crouching
	_send_t += delta
	if _send_t >= 1.0 / players.SEND_HZ:
		_send_t = 0.0
		_seq += 1
		# A mode change inside the interval would read as too fast (sprint to walk) or free (walk to crouch):
		# send the faster mode, so the host limit covers the distance walked.
		players.submit_local(_seq, global_position, yaw, pitch, _crouch_all, _sprint_any)
		_sprint_any = false
		_crouch_all = true


## P5-13 (D-165): the host's colour slot arrived (or changed): re-tint the body.
func set_colour_slot(slot: int) -> void:
	colour_slot = slot
	if _mesh:
		_mesh.tint(slot)
