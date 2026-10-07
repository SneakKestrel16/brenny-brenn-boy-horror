extends CharacterBody3D
## Doc 05 section 6: one Player per peer. The local one reads input, owns movement and camera and
## streams `move` frames; a remote one is a proxy that smooths toward the latest `moves` target.

const EYE_STAND := 1.65  ## CONTRACTS section 3
const HEIGHT_STAND := 1.8
const HEIGHT_CROUCH := 1.1  ## placeholder: no crouch height in the docs
const EYE_CROUCH := 0.95  ## placeholder
const RADIUS := 0.35  ## placeholder
const GRAVITY := 20.0
const PROXY_SMOOTH := 15.0  ## exponential smoothing rate for proxies (ponytail: no snapshot buffer)

var peer := 0
var is_local := false
var players: Node  ## the Players manager

var yaw := 0.0
var pitch := 0.0
var crouching := false
var stamina := 0.0  ## seconds of sprint left (doc 02 section 2.2)

var _cam: Camera3D
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _seq := 0
var _send_t := 0.0
var _target_pos := Vector3.ZERO
var _autowalk := false  ## QA: `-- --autowalk` walks in a circle with no input (multi-instance tests)
var _t := 0.0


func _ready() -> void:
	collision_layer = 2  # player
	collision_mask = (1 | 16) if is_local else 0  # world and corn (layer 5) block the local body
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
	rotation.y = yaw
	_cam.rotation.x = pitch
	_cam.position.y = lerpf(_cam.position.y, EYE_CROUCH if crouching else EYE_STAND, 1.0 - exp(-12.0 * delta))


func _local(delta: float) -> void:
	_t += delta
	var still := Input.is_action_pressed(&"go_still")  # doc 05 section 6: freezes the body, sends nothing special
	var dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var want_sprint := Input.is_action_pressed(&"sprint")
	if _autowalk:
		yaw = _t * 0.5
		dir = Vector2(0, -1)
		want_sprint = fmod(_t, 8.0) > 4.0
	if not bool(Settings.get_value(&"toggle_crouch")):
		_set_crouch(Input.is_action_pressed(&"crouch"))
	if still:
		dir = Vector2.ZERO
	var sprint_rec := Data.record(&"labor", &"sprint")
	var sprinting := want_sprint and not crouching and dir != Vector2.ZERO and stamina > 0.0
	if sprinting:
		stamina = maxf(stamina - delta, 0.0)
	else:
		stamina = minf(stamina + float(sprint_rec["max_s"]) / float(sprint_rec["refill_s"]) * delta, float(sprint_rec["max_s"]))
	var speed := Data.speed(&"crouch" if crouching else (&"sprint" if sprinting else &"walk"))
	var wish := (global_transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * speed
	velocity.x = wish.x
	velocity.z = wish.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_send_t += delta
	if _send_t >= 1.0 / players.SEND_HZ:
		_send_t = 0.0
		_seq += 1
		players.submit_local(_seq, global_position, yaw, pitch, crouching, sprinting)
