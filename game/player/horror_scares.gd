class_name HorrorScares
extends Node
## P5-53 (CEO pick 2026-10-10): the Horror role's scare layer. Built once by Main, on every peer; it does
## nothing unless the LOCAL player holds the role (or the dev console `horror` forces one). Everything here
## is drawn and played on this machine only: nothing is sent, nothing touches NoiseBus, tension, the
## creature, a trap, a hold, movement, carried items or Game.players. A scare can never hurt, slow, drop,
## kill, cut to black or white-flash (doc 01 "Photosensitivity safety"). The one thing that comes from the
## host is the sixth sense's REAL chill (scares.gd `_sixth_sense`, a private `chill` with no position);
## this node makes fake chills too, so a chill is never proof.
## What it does (numbers: data/roles.json `horror` perks, all placeholder):
##   darker world   `ambient_mult`, `fog_mult`, `lamp_mult` below, read by WorldLook and LightRig. Dimming only:
##                  only ghosts may make lights blink (CONTRACTS, doc 07 s4.3), so the `flicker` key stays false (QUESTIONS).
##   silhouette     an extra distant hallucination (Scares._apparition), from `hallucination_from_day`.
##   whisper        a fake whisper or a teammate's real clip from a far corn spot (the teammate is not there).
##   name_whisper   a clip of the player's OWN recorded voice from the corn; only if their voice setting
##                  replays it (Game.replays_voice: Live clips on, not streamer-safe) and a clip exists.
##   steps          footsteps follow from behind and stop the moment the player turns.
##   shadow         a dark shape at the screen edge that vanishes when looked at.
##   grab           a camera jolt and a stinger as if caught, then nothing.
##   chill          cold slow vignette and a swell; no flash.
## `reduce_scares` doubles every interval and drops the shadow and the grab.

const CHILL_SHADER := "shader_type canvas_item;\nuniform float k = 0.0;\nvoid fragment() {\n\tvec2 d = UV - vec2(0.5);\n\tfloat e = smoothstep(0.15, 0.75, length(d) * 1.45);\n\tCOLOR = vec4(0.05, 0.1, 0.2, e * 0.6 * k);\n}\n"
const KINDS: Array[StringName] = [&"silhouette", &"whisper", &"name_whisper", &"steps", &"shadow", &"grab"]
const GROUPS: Array[StringName] = [&"creature_cover", &"crow_perches"]
const STEP_GAP_S := 0.55  ## placeholder: seconds between the following steps

## Darker world, read every frame by WorldLook (ambient, fog) and LightRig (lamps). 1.0 = unchanged.
static var ambient_mult := 1.0
static var fog_mult := 1.0
static var lamp_mult := 1.0

var forced_until_msec := 0  ## the dev console `horror`: act without the role until this tick (20 s)
var _t := 0.0
var _due: Dictionary = {}  ## kind -> time it fires next
var _rng := RandomNumberGenerator.new()
var _day := -1
var _grabs_today := 0
var _steps_left := 0.0  ## > 0 while footsteps follow
var _step_at := 0.0
var _gap := 3.0
var _yaw_prev := 0.0
var _shadow: MeshInstance3D
var _shadow_ttl := 0.0
var _chill_k := 0.0
var _chill_rect: ColorRect
var _chill_tw: Tween


func _ready() -> void:
	add_to_group(&"horror_scares")
	_rng.randomize()
	var layer := CanvasLayer.new()
	layer.layer = 0  # over the world and post pass, under every UI layer and the Taint smudge
	_chill_rect = ColorRect.new()
	_chill_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = CHILL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_chill_rect.material = mat
	_chill_rect.visible = false
	layer.add_child(_chill_rect)
	add_child(layer)


# --- pure helpers (tests/gameplay/test_horror.gd) --------------------------------------------------

## A second count in `range_s` [min, max], doubled when scares are reduced.
static func interval(range_s: Array, u: float, reduced: bool) -> float:
	return lerpf(float(range_s[0]), float(range_s[1]), u) * (2.0 if reduced else 1.0)


## True when `yaw` moved more than `deg` from `prev` (the player turned round).
static func turned(prev: float, yaw: float, deg: float) -> bool:
	return absf(rad_to_deg(angle_difference(prev, yaw))) > deg


## Angle in degrees between the camera's forward and the direction to a point (both flat, normalised here).
static func off_axis_deg(cam_fwd: Vector3, to: Vector3) -> float:
	var a := Vector3(cam_fwd.x, 0.0, cam_fwd.z).normalized()
	var b := Vector3(to.x, 0.0, to.z).normalized()
	return rad_to_deg(a.angle_to(b))


## The darker world's multipliers for a role's perks; all 1.0 for none.
static func dark_for(perks: Dictionary) -> Array:
	if perks.is_empty() or not perks.has("dark_lamp_mult"):
		return [1.0, 1.0, 1.0]
	return [float(perks.dark_ambient_mult), float(perks.dark_fog_mult), float(perks.dark_lamp_mult)]


## Which scares may run now. `day` follows doc 01 "Ramp-up" for silhouettes; `reduced` drops the loud two.
static func allowed(kind: StringName, day: int, perks: Dictionary, reduced: bool) -> bool:
	if reduced and kind in [&"shadow", &"grab"]:
		return false
	return kind != &"silhouette" or day >= int(perks.hallucination_from_day)


# --- every frame ------------------------------------------------------------------------------------

func _active() -> bool:
	return Time.get_ticks_msec() < forced_until_msec or (Roles.of(Game.local_peer()) == &"horror" and not Game.is_ghost(Game.local_peer()))


func _process(delta: float) -> void:
	var on := _active()
	var d := dark_for(Roles.perks(&"horror")) if on else [1.0, 1.0, 1.0]
	ambient_mult = d[0]
	fog_mult = d[1]
	lamp_mult = d[2]
	if not on:
		_clear()
		return
	var pl := _player()
	if pl == null:
		return
	_t += delta
	if Clock.day != _day:
		_day = Clock.day
		_grabs_today = 0
	var hz := Roles.perks(&"horror")
	var reduced := bool(Settings.get_value(&"reduce_scares"))
	for k in KINDS:
		if not _due.has(k):
			_due[k] = _t + interval(hz.get(_range_key(k), [60, 120]), _rng.randf(), reduced)  # the first one is not at once
		elif _t >= _due[k]:
			_due[k] = _t + interval(hz.get(_range_key(k), [60, 120]), _rng.randf(), reduced)
			if allowed(k, Clock.day, hz, reduced):
				run(k)
	if _chill_k <= 0.0 and _rng.randf() < delta * float(hz.chill_fake_share) / 20.0:  # fake chills for no reason, about one a 50 s: never proof
		chill(false)
	_follow(pl, delta, hz)
	_shadow_watch(delta, hz)


static func _range_key(kind: StringName) -> String:
	return {&"silhouette": "silhouette_every_s", &"whisper": "whisper_every_s", &"name_whisper": "name_whisper_every_s",
			&"steps": "steps_every_s", &"shadow": "shadow_every_s", &"grab": "grab_every_s"}[kind]


## Run one scare now, local only. Returns a short word for what happened ("" for nothing: nowhere to put it).
func run(kind: StringName) -> String:
	var pl := _player()
	if pl == null:
		return "no_player"
	var hz := Roles.perks(&"horror")
	var out := ""
	match kind:
		&"silhouette":
			out = _silhouette(pl, hz)
		&"whisper":
			out = _whisper(pl, hz)
		&"name_whisper":
			out = _name_whisper(pl, hz)
		&"steps":
			_steps_left = float(hz.steps_max_s)
			_step_at = 0.0
			_gap = float(hz.steps_gap_m[0])
			_yaw_prev = pl.yaw
			out = "following"
		&"shadow":
			out = _edge_shadow(pl, hz)
		&"grab":
			if _grabs_today < int(hz.grab_max_per_day) or Time.get_ticks_msec() < forced_until_msec:
				_grabs_today += 1
				_grab(pl, hz)
				out = "grab"
		&"chill":
			chill(false)
			out = "chill"
	Log.event(&"horror_scare", {"kind": String(kind), "result": out if out else "none", "local": true})
	return out


## The sixth sense's cue. `real` is the host's chill; fakes call this with false. The player cannot tell them apart.
func chill(real := false) -> void:
	if not _active():
		return
	if not real:
		Log.event(&"horror_chill", {"target": Game.local_peer(), "real": false})
	Soundscape.play_2d(&"cre_presence_swell", -10.0)
	_chill_rect.visible = true
	if _chill_tw:
		_chill_tw.kill()
	_chill_tw = create_tween()
	_chill_tw.tween_method(_set_chill, _chill_k, 1.0, 0.8)  # slow: no flash (doc 07 s4.3)
	_chill_tw.tween_interval(0.6)
	_chill_tw.tween_method(_set_chill, 1.0, 0.0, 2.5)
	_chill_tw.tween_callback(func() -> void: _chill_rect.visible = false)


func _set_chill(k: float) -> void:
	_chill_k = k
	(_chill_rect.material as ShaderMaterial).set_shader_parameter(&"k", k)


func _clear() -> void:
	_steps_left = 0.0
	_due.clear()
	if is_instance_valid(_shadow):
		_shadow.queue_free()
		_shadow = null


# --- the scares --------------------------------------------------------------------------------------

func _player() -> Node3D:
	var players := get_parent().get_node_or_null(^"Players")
	return players.player(Game.local_peer()) if players else null


## A cover point or perch `range_m` [min, max] away within 60 degrees of the camera, or Vector3.INF.
func _spot_in_view(pl: Node3D, range_m: Array) -> Vector3:
	var fwd := Vector3(-sin(pl.yaw), 0.0, -cos(pl.yaw))
	var pool: Array = []
	for g in GROUPS:
		pool += get_tree().get_nodes_in_group(g)
	pool.shuffle()
	for n: Node3D in pool:
		var to := n.global_position - pl.global_position
		to.y = 0.0
		if to.length() >= float(range_m[0]) and to.length() <= float(range_m[1]) and fwd.dot(to.normalized()) > 0.5:
			return Vector3(n.global_position.x, 0.0, n.global_position.z)
	return Vector3.INF


## Any cover point or perch in range, any direction (a sound needs no line of sight).
func _spot_near(pl: Node3D, range_m: Array) -> Vector3:
	var pool: Array = []
	for g in GROUPS:
		pool += get_tree().get_nodes_in_group(g)
	pool.shuffle()
	for n: Node3D in pool:
		var d := n.global_position.distance_to(pl.global_position)
		if d >= float(range_m[0]) and d <= float(range_m[1]):
			return Vector3(n.global_position.x, 0.0, n.global_position.z)
	var a := _rng.randf() * TAU  # none near: any ring point (an open field), no sight needed
	return pl.global_position + Vector3(sin(a), 0.0, cos(a)) * float(range_m[0])


func _silhouette(pl: Node3D, hz: Dictionary) -> String:
	var at := _spot_in_view(pl, hz.silhouette_distance_m)
	var scares := get_parent().get_node_or_null(^"Scares")
	if at == Vector3.INF or scares == null:
		return ""
	scares.call(&"_present", &"hallucination", Game.local_peer(), at, "")  # the same swell and silhouette as the host-sent one; vanishes the same way
	if _rng.randf() < 0.4:
		chill(false)  # hallucinations also trigger the chill (CEO pick)
	return "silhouette"


## A far whisper: a teammate's real clip when their setting replays it, else a stranger line, low.
func _whisper(pl: Node3D, hz: Dictionary) -> String:
	var at := _spot_near(pl, hz.whisper_distance_m)
	var src := _clip_source(false)
	if src != "":
		Net.apply_received.emit(&"lure", ["horror_voice", src, at, Game.local_peer(), &"none", false])
	else:
		Soundscape.play_3d(Soundscape.STRANGER_LINES[_rng.randi() % Soundscape.STRANGER_LINES.size()], at, {"db": -8.0})
	if _rng.randf() < 0.3:
		chill(false)
	return "teammate_clip" if src != "" else "stranger"


## The player's own recorded voice from the corn. Doc 06 s11: only when their own setting replays it.
func _name_whisper(pl: Node3D, hz: Dictionary) -> String:
	var src := _clip_source(true)
	if src == "":
		return ""
	var at := _spot_near(pl, hz.name_whisper_distance_m)
	Net.apply_received.emit(&"lure", ["horror_own_voice", src, at, Game.local_peer(), &"none", false])
	return "own_clip"


## `clip:<owner>:<id>` of this player's own clip (own) or a random other player's, "" for none. Honors
## Game.replays_voice (Off / streamer-safe owners are never replayed).
func _clip_source(own: bool) -> String:
	var me := Game.local_peer()
	var found: Array[String] = []
	for q: int in Game.players:
		if (q == me) != own or not Game.replays_voice(q):
			continue
		for c in Voice.clips.clip_ids(q):
			found.append("clip:%d:%s" % [q, c])
	return found[_rng.randi() % found.size()] if not found.is_empty() else ""


## Footsteps behind, closing in, while the player moves; they stop the moment the player turns.
func _follow(pl: Node3D, delta: float, hz: Dictionary) -> void:
	if _steps_left <= 0.0:
		return
	if turned(_yaw_prev, pl.yaw, float(hz.steps_turn_deg)):
		_steps_left = 0.0  # they turned: it stops
		return
	_steps_left -= delta
	_yaw_prev = lerp_angle(_yaw_prev, pl.yaw, minf(delta * 3.0, 1.0))  # a slow drift, so a quick turn counts
	if _t >= _step_at and Vector2(pl.velocity.x, pl.velocity.z).length() > 0.5:
		_step_at = _t + STEP_GAP_S
		_gap = move_toward(_gap, float(hz.steps_gap_m[1]), 0.12)
		var back := Vector3(sin(pl.yaw), 0.0, cos(pl.yaw))
		Soundscape.play_3d(&"sfx_step_corn", pl.global_position + back * _gap, {"quiet": true})


func _edge_shadow(pl: Node3D, hz: Dictionary) -> String:
	if is_instance_valid(_shadow):
		return ""
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var ang := deg_to_rad(_rng.randf_range(hz.shadow_edge_deg[0], hz.shadow_edge_deg[1])) * side
	var dist := _rng.randf_range(hz.shadow_distance_m[0], hz.shadow_distance_m[1])
	var fwd := Vector3(-sin(pl.yaw), 0.0, -cos(pl.yaw)).rotated(Vector3.UP, ang)
	var mesh := CapsuleMesh.new()
	mesh.height = 2.0
	mesh.radius = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.01, 0.01, 0.02)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	_shadow = MeshInstance3D.new()
	_shadow.mesh = mesh
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(_shadow)
	_shadow.global_position = pl.global_position + fwd * dist + Vector3.UP * 1.0
	_shadow_ttl = 9.0
	return "shadow"


## A shadow goes the moment it nears the middle of the view (no fade a flash could read as), or after a while.
func _shadow_watch(delta: float, hz: Dictionary) -> void:
	if not is_instance_valid(_shadow):
		return
	_shadow_ttl -= delta
	var cam := get_viewport().get_camera_3d()
	var gone := _shadow_ttl <= 0.0
	if cam:
		gone = gone or off_axis_deg(-cam.global_transform.basis.z, _shadow.global_position - cam.global_position) < float(hz.shadow_gone_deg)
	if gone:
		_shadow.queue_free()
		_shadow = null


## A jolt and a stinger as if caught, then nothing. The camera's roll and vertical offset only; nothing is
## held, dropped, locked, slowed or sent. Scaled by the camera-shake setting (0 = no jolt, the sound stays).
func _grab(pl: Node3D, hz: Dictionary) -> void:
	Soundscape.play_2d(&"cre_jumpscare_hit", -4.0)
	var k := float(Settings.get_value(&"camera_shake"))
	var cam: Camera3D = pl.get("_cam")
	if cam == null or k <= 0.0:
		return
	var s := float(hz.grab_jolt_s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(cam, "v_offset", -0.25 * k, s * 0.2)
	tw.tween_property(cam, "rotation:z", 0.14 * k, s * 0.2)
	tw.chain().tween_property(cam, "v_offset", 0.0, s * 0.8)
	tw.parallel().tween_property(cam, "rotation:z", 0.0, s * 0.8)
	chill(false)
