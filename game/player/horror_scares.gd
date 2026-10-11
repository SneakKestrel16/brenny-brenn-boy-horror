class_name HorrorScares
extends Node
## P5-53, reworked by P5-71 (CEO D-188): the Horror role's local layer. Built once by Main, on every peer; it does
## nothing unless the LOCAL player holds the role (or the dev console `horror` forces one). Everything here
## is drawn and played on this machine only: nothing is sent, nothing touches NoiseBus, tension, the
## creature, a trap, a hold, movement, carried items or Game.players. Nothing here can hurt, slow, drop,
## kill, cut to black, jolt the camera or white-flash (doc 01 "Photosensitivity safety"). The one thing that comes from the
## host is the sixth sense's REAL chill (scares.gd `_sixth_sense`, a private `chill` with no position);
## this node makes fake chills too, so a chill is never proof.
## P5-71: every visible or voiced scare of the role is now the AI Director's (scares.gd), so it counts toward the
## Director's budget, once-per-season and spacing limits: the Horror peer is picked first and sees hallucinations from
## day 5 (doc 01 "Ramp-up"); its hallucinations are the same distant silhouette, sometimes turning to face the player with a stinger
## ("turn") or at the edge of the view, gone when looked at ("edge"). Whispers and the own-voice clip are the Director's
## `whisper` and `own_voice` records. No local silhouette, whisper, shadow or grab remains.
## What it does (numbers: data/roles.json `horror` perks, all placeholder):
##   darker world   `ambient_mult`, `fog_mult`, `lamp_mult` below, read by WorldLook and LightRig. Dimming only:
##                  only ghosts may make lights blink (CONTRACTS, doc 07 s4.3), so that roles.json key stays false.
##   steps          footsteps follow from behind and stop the moment the player turns (not a hallucination).
##   chill          cold slow vignette and a swell; no flash.
## `reduce_scares` doubles every interval.

const CHILL_SHADER := "shader_type canvas_item;\nuniform float k = 0.0;\nvoid fragment() {\n\tvec2 d = UV - vec2(0.5);\n\tfloat e = smoothstep(0.15, 0.75, length(d) * 1.45);\n\tCOLOR = vec4(0.05, 0.1, 0.2, e * 0.6 * k);\n}\n"
const KINDS: Array[StringName] = [&"steps"]
const STEP_GAP_S := 0.55  ## placeholder: seconds between the following steps

## Darker world, read every frame by WorldLook (ambient, fog) and LightRig (lamps). 1.0 = unchanged.
static var ambient_mult := 1.0
static var fog_mult := 1.0
static var lamp_mult := 1.0

var forced_until_msec := 0  ## the dev console `horror`: act without the role until this tick (20 s)
var _t := 0.0
var _due: Dictionary = {}  ## kind -> time it fires next
var _rng := RandomNumberGenerator.new()
var _steps_left := 0.0  ## > 0 while footsteps follow
var _step_at := 0.0
var _gap := 3.0
var _yaw_prev := 0.0
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


## The darker world's multipliers for a role's perks; all 1.0 for none.
static func dark_for(perks: Dictionary) -> Array:
	if perks.is_empty() or not perks.has("dark_lamp_mult"):
		return [1.0, 1.0, 1.0]
	return [float(perks.dark_ambient_mult), float(perks.dark_fog_mult), float(perks.dark_lamp_mult)]


# --- every frame ------------------------------------------------------------------------------------

func _active() -> bool:
	return Time.get_ticks_msec() < forced_until_msec or (Roles.of(Game.local_peer()) == &"horror" and not Game.is_ghost(Game.local_peer()))


func _process(delta: float) -> void:
	var on := _active()
	var d := dark_for(Roles.perks(&"horror")) if on else [1.0, 1.0, 1.0]
	ambient_mult = d[0]
	fog_mult = d[1]
	lamp_mult = d[2]
	LightRig.lamp_mult = lamp_mult  # pushed, so LightRig compiles without the Game autoload (test_light_rig)
	if not on:
		_clear()
		return
	var pl := _player()
	if pl == null:
		return
	_t += delta
	var hz := Roles.perks(&"horror")
	var reduced := bool(Settings.get_value(&"reduce_scares"))
	for k in KINDS:
		if not _due.has(k):
			_due[k] = _t + interval(hz.steps_every_s, _rng.randf(), reduced)  # the first one is not at once
		elif _t >= _due[k]:
			_due[k] = _t + interval(hz.steps_every_s, _rng.randf(), reduced)
			run(k)
	if _chill_k <= 0.0 and _rng.randf() < delta * float(hz.chill_fake_share) / 20.0:  # fake chills for no reason, about one a 50 s: never proof
		chill(false)
	_follow(pl, delta, hz)


## Run one scare now, local only. Returns a short word for what happened.
func run(kind: StringName) -> String:
	var pl := _player()
	if pl == null:
		return "no_player"
	var hz := Roles.perks(&"horror")
	var out := ""
	match kind:
		&"steps":
			_steps_left = float(hz.steps_max_s)
			_step_at = 0.0
			_gap = float(hz.steps_gap_m[0])
			_yaw_prev = pl.yaw
			out = "following"
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


func _player() -> Node3D:
	var players := get_parent().get_node_or_null(^"Players")
	return players.player(Game.local_peer()) if players else null


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
