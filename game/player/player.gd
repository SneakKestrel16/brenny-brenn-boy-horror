extends CharacterBody3D
## Doc 05 section 6: one Player per peer. The local one reads input, owns movement and camera and
## streams `move` frames; a remote one is a proxy that smooths toward the latest `moves` target.

const EYE_STAND := 1.65  ## CONTRACTS section 3
const HEIGHT_STAND := 1.8
const HEIGHT_CROUCH := 1.1  ## placeholder: no crouch height in the docs
const EYE_CROUCH := 0.95  ## placeholder
const RADIUS := 0.35  ## placeholder
const GRAVITY := 20.0
const RESUME_S := 1.5  ## placeholder: stamina needed to sprint again after running dry (doc 02 section 2.2 gives max and refill only)
const PROXY_SMOOTH := 15.0  ## exponential smoothing rate for proxies (ponytail: no snapshot buffer)

var peer := 0
var is_local := false
var players: Node  ## the Players manager

var yaw := 0.0
var pitch := 0.0
var crouching := false
var stamina := 0.0  ## seconds of sprint left (doc 02 section 2.2)
var exhausted := false  ## ran dry: no sprint until `stamina` refills to RESUME_S (stops a per-frame flip at 0)
var ghost := false  ## dead: flies, no collision, no sound (set by Death on every peer)
var pinned := false  ## caught in a bear trap: cannot move (TrapRace sets it on every peer)
var speed_mult := 1.0  ## Shaken (doc 01 "Night Traps"), local only; the host mirrors it in Game.players
var _shaken_s := 0.0
var _spec := 0  ## ghost: peer being watched, 0 = free flight

var nav_path: Array = []  ## QA waypoints for `--autochore` (HoldController fills it)
var _cam: Camera3D
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _seq := 0
var _send_t := 0.0
var _sprint_any := false  ## sprinted at any point since the last packet (the host judges the whole interval's speed)
var _crouch_all := true  ## crouched for the whole interval
var _target_pos := Vector3.ZERO
var _autowalk := false  ## QA: `-- --autowalk` walks in a circle with no input (multi-instance tests)
var _t := 0.0


func _ready() -> void:
	collision_layer = 2  # player
	collision_mask = 1 if is_local else 0  # world blocks the body; corn (layer 5) is walkable, sight/sound only
	_shape = CollisionShape3D.new()
	_shape.shape = CapsuleShape3D.new()
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = CapsuleMesh.new()
	add_child(_mesh)
	_apply_height(false)
	_cam = Camera3D.new()
	_cam.position.y = EYE_STAND
	add_child(_cam)
	_target_pos = global_position
	if is_local:
		_cam.current = true
		_cam.fov = float(Settings.get_value(&"fov"))
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


func _apply_height(crouch: bool) -> void:
	var h := HEIGHT_CROUCH if crouch else HEIGHT_STAND
	(_shape.shape as CapsuleShape3D).height = h
	(_shape.shape as CapsuleShape3D).radius = RADIUS
	_shape.position.y = h / 2.0
	(_mesh.mesh as CapsuleMesh).height = h
	(_mesh.mesh as CapsuleMesh).radius = RADIUS
	_mesh.position.y = h / 2.0


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
		pitch = clampf(pitch - event.relative.y * s, -1.5, 1.5)
	elif event.is_action_pressed(&"pause"):  # placeholder until the pause menu (game/ui/)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"crouch") and bool(Settings.get_value(&"toggle_crouch")):
		_set_crouch(not crouching)


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
		_mesh.visible = not ghost or Game.is_ghost(Game.local_peer())  # ghosts are seen only by ghosts
	rotation.y = yaw
	_cam.rotation.x = pitch
	_cam.position.y = lerpf(_cam.position.y, EYE_CROUCH if crouching else EYE_STAND, 1.0 - exp(-12.0 * delta))


## Host-told Shaken (TrapRace): all speeds x `mult` for `seconds`.
func shake(seconds: float, mult: float) -> void:
	_shaken_s = seconds
	speed_mult = mult


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
func _spectate(dir: Vector2) -> void:
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
		yaw = t.yaw
		global_position = t.global_position + t.global_transform.basis.z * 2.0 + Vector3(0, 1.0, 0)


func _local_ghost(delta: float) -> void:
	var dir := Vector2.ZERO if Game.console_open else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_spectate(dir)
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
	var typing := Game.console_open  # D-031: keys go to the dev console, not the body
	var still := not typing and Input.is_action_pressed(&"go_still")  # doc 05 section 6: freezes the body, sends nothing special
	var dir := Vector2.ZERO if typing else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var want_sprint := not typing and Input.is_action_pressed(&"sprint")
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
	if still or pinned:
		dir = Vector2.ZERO
	var sprint_rec := Data.record(&"labor", &"sprint")
	if exhausted and stamina >= RESUME_S:
		exhausted = false
	var sprinting := want_sprint and not crouching and dir != Vector2.ZERO and stamina > 0.0 and not exhausted
	if sprinting:
		stamina = maxf(stamina - delta, 0.0)
		exhausted = stamina <= 0.0
	else:
		stamina = minf(stamina + float(sprint_rec["max_s"]) / float(sprint_rec["refill_s"]) * delta, float(sprint_rec["max_s"]))
	var speed := Data.speed(&"crouch" if crouching else (&"sprint" if sprinting else &"walk")) * speed_mult
	var wish := (global_transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * speed
	velocity.x = wish.x
	velocity.z = wish.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
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
