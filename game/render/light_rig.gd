class_name LightRig
extends Node3D
## Doc 07 section 4: every gameplay light is a LightRig. Only game/core/lights.gd calls set_on, set_dim
## and blow_out; the ghost effect (game/ghost/) uses the guarded energy_override below. All change
## speeds are slew-limited here (full energy per SLEW_S), so a bug elsewhere cannot strobe a light.
## Nothing here animates energy on its own: no noise, no tween, no pulse.

const SLEW_S := 0.2  ## doc 07 s4.1: max change is full energy per 0.2 s
const OVERRIDE_TOKEN := &"ghost"  ## placeholder guard: the caller must pass this (doc 07 s4.3)
const DIM_FLOOR := 0.35  ## doc 07 s4.2: lights never fall below 35% until the generator is dead
const DIM_WARM := Color("FF8A2A")  ## colour a nearly empty generator drifts toward

const SPILL_RANGE := 1.6  ## P5-50: soft outer spill light, times range_m (placeholder)
const FILL_ENERGY := 1.1  ## P5-50: interior fill energy, times the main energy (placeholder)
const INTERIOR_COL := Color("FFD8A0")
const SPILL_ENERGY := 0.3  ## P5-50: spill energy, times the main energy (placeholder)

## P5-50: 0..1 visibility of every painted ground pool; WorldLook sets it from the clock phase (0 by day).
## Visual only, not a light value, and the same on every peer.
static var pool_vis := 1.0
static var _pool_tex: GradientTexture2D

@export var color := Color("FFB45A")  ## doc 07 s3 porch light
@export var range_m := 6.0  ## doc 07 s3: 6 m doorway radius (Q-026)
@export var fill_range_m := 0.0  ## P5-50: > 0 adds a dim warm interior fill of this range (set by WorldLook per building)
@export var energy := 1.2
@export var ground_pool := true  ## painted warm pool on the ground matching range_m (doc 07 s3)

var _on := true
var _dim_warm := 0.0  ## 0..1, colour drift toward DIM_WARM
var _dim := 1.0  ## multiplier 0.35..1 from set_dim
var _level := 1.0  ## slewed 0..1 actually shown
var _override := -1.0  ## < 0: no override
var _override_tint := Color.WHITE
var _light: OmniLight3D
var _spill: OmniLight3D
static var lamp_mult := 1.0  # P5-53: Horror role dimming, set by HorrorScares; 1.0 for everyone else
var _fill: OmniLight3D  # P5-50: interior fill, only when fill_range_m > 0
var _lamp_mat: StandardMaterial3D
var _pool_mat: StandardMaterial3D
var _smoke: CPUParticles3D


func _ready() -> void:
	add_to_group(&"light_rigs")
	_light = OmniLight3D.new()
	_light.omni_range = range_m
	_light.shadow_enabled = false  # only the held lantern casts a shadow (doc 07 s3)
	_light.omni_attenuation = 1.5  # P5-50: a brighter core and a softer fall-off than the linear default
	add_child(_light)
	_spill = OmniLight3D.new()  # P5-50: wide, faint, so the edge of the pool is not a wall of dark
	_spill.omni_range = range_m * SPILL_RANGE
	_spill.omni_attenuation = 2.0
	_spill.shadow_enabled = false
	add_child(_spill)
	if fill_range_m > 0.0:  # P5-50: the room's own warm bulb light (doc 07 s3 interior bulb `#FFD8A0`, 1.0)
		_fill = OmniLight3D.new()
		_fill.omni_range = fill_range_m
		_fill.omni_attenuation = 1.0
		_fill.light_color = INTERIOR_COL
		_fill.shadow_enabled = false
		add_child(_fill)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	_lamp_mat.albedo_color = Color(0.1, 0.1, 0.1)
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	lamp.mesh = box
	lamp.material_override = _lamp_mat
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	if ground_pool:
		_pool_mat = StandardMaterial3D.new()
		_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var pool := MeshInstance3D.new()
		if _pool_tex == null:  # P5-50: radial falloff with a still readable edge, not a hard disc
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.6, 0.9, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
			_pool_tex = GradientTexture2D.new()
			_pool_tex.gradient = g
			_pool_tex.fill = GradientTexture2D.FILL_RADIAL
			_pool_tex.fill_from = Vector2(0.5, 0.5)
			_pool_tex.fill_to = Vector2(1.0, 0.5)
			_pool_tex.width = 128
			_pool_tex.height = 128
		_pool_mat.albedo_texture = _pool_tex
		var disc := PlaneMesh.new()
		disc.size = Vector2.ONE * range_m * 2.0
		pool.mesh = disc
		pool.material_override = _pool_mat
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pool)
		pool.global_position.y = 0.03
	_apply()


func set_on(on: bool) -> void:
	_on = on


## Fuel fraction 0..1 (doc 07 s4.2): monotonic, no noise. Below 25% fuel the light fades to 35%.
func set_dim(fraction: float) -> void:
	_dim = DIM_FLOOR + (1.0 - DIM_FLOOR) * smoothstep(0.0, 0.25, clampf(fraction, 0.0, 1.0))
	_dim_warm = 1.0 - smoothstep(0.0, 0.25, clampf(fraction, 0.0, 1.0))



## The one instant-off: off now, smoke puff, stays off until set_on(true).
func blow_out() -> void:
	_on = false
	_level = 0.0
	_puff()
	_apply()


func _puff() -> void:
	if _smoke == null:
		_smoke = CPUParticles3D.new()
		_smoke.one_shot = true
		_smoke.amount = 10
		_smoke.lifetime = 1.2
		_smoke.explosiveness = 1.0
		_smoke.direction = Vector3.UP
		_smoke.spread = 40.0
		_smoke.initial_velocity_min = 0.4
		_smoke.initial_velocity_max = 0.9
		_smoke.gravity = Vector3(0, 0.3, 0)
		_smoke.mesh = SphereMesh.new()
		(_smoke.mesh as SphereMesh).radius = 0.08
		(_smoke.mesh as SphereMesh).height = 0.16
		_smoke.emitting = false
		add_child(_smoke)
	_smoke.restart()


## Ghost effect only (doc 07 s4.3; called from game/ghost/). value is a fraction of full energy
## (0..1); negative clears it. tint is the temporary light colour. Bypasses the slew on purpose.
func energy_override(value: float, token: StringName, tint: Color = Color.WHITE) -> void:
	if token != OVERRIDE_TOKEN:
		return
	_override = value
	_override_tint = tint
	_apply()


func current_level() -> float:
	return _override if _override >= 0.0 else _level


func _process(delta: float) -> void:
	var goal := _dim if _on else 0.0
	_level = move_toward(_level, goal, delta / SLEW_S)
	_apply()


func _apply() -> void:
	if _light == null:
		return
	var lvl := current_level()
	var c := color.lerp(DIM_WARM, _dim_warm * 0.6)
	if _override >= 0.0:
		c = _override_tint
	_light.light_color = c
	_light.light_energy = energy * lvl * lamp_mult  # P5-53: steady local dimming for the Horror role; never animated
	_light.visible = lvl > 0.001
	_spill.light_color = c
	_spill.light_energy = energy * SPILL_ENERGY * lvl
	_spill.visible = lvl > 0.001
	if _fill:
		_fill.light_color = INTERIOR_COL if _override < 0.0 else c
		_fill.light_energy = energy * FILL_ENERGY * lvl * lamp_mult
		_fill.visible = lvl > 0.001
	_lamp_mat.emission = c
	_lamp_mat.emission_energy_multiplier = 3.0 * lvl
	if _pool_mat:
		_pool_mat.albedo_color = Color(c.r, c.g, c.b, 0.3 * lvl * pool_vis)
