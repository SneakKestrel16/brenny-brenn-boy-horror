class_name QuirkWatch
extends Node
## P5-09: the two quirks that run on their own timers (data/quirks.json). Built once by Main.
## Paranoia (this client only): now and then a footstep behind the player that is not there. Played locally through the
##   Soundscape; never NoiseBus (the creature cannot hear it), never sent, never a ghost voice, radio or light effect,
##   and it moves no tension (doc 01 Quirks, Photosensitivity safety: audio only).
## OCD (host): standing in a scarecrow's gaze for the dwell time makes that player Shaken (never Taint), once per
##   scarecrow per player per cooldown. A scarecrow has no stored facing yet: inference, the front arc is world -Z
##   (Godot's forward for an unrotated model); Q-276 asks who stores it once the model lands.

const CROW_FACING := Vector2(0.0, -1.0)  ## x, z

var _t := 0.0  ## seconds this node has run; the OCD cooldowns read it
var _next_step := -1.0  ## paranoia: the time of the next phantom
var _steps_left := 0
var _step_at := 0.0
var _today := 0
var _dwell: Dictionary = {}  ## host: peer -> seconds in a gaze
var _cool: Dictionary = {}  ## host: "peer:crow index" -> time the cooldown ends
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Clock.day_changed.connect(func(_d: int) -> void: _today = 0)


## Pure: is `pos` (x, z) within `range_m` of a scarecrow at `crow` and inside the arc around its facing?
static func in_gaze(crow: Vector3, pos: Vector3, range_m: float, arc_deg: float) -> bool:
	var v := Vector2(pos.x - crow.x, pos.z - crow.z)
	var d := v.length()
	if d > range_m:
		return false
	return d < 0.001 or absf(rad_to_deg(v.angle_to(CROW_FACING))) <= arc_deg / 2.0


func _process(delta: float) -> void:
	_t += delta
	if Quirks.mine == &"paranoia" and not Game.is_ghost(Game.local_peer()):
		_phantom(delta)


func _physics_process(delta: float) -> void:
	if Game.is_host():
		_gaze(delta)


func _phantom(_delta: float) -> void:
	var fx := Quirks.effects(&"paranoia")
	var pl: Node3D = get_parent().get_node(^"Players").player(Game.local_peer())
	if pl == null:
		return
	if _steps_left > 0:
		if _t >= _step_at:
			_steps_left -= 1
			_step_at = _t + 0.55
			var back := Vector3(sin(pl.yaw), 0.0, cos(pl.yaw))  # behind: opposite the camera's forward (-sin, -cos)
			Soundscape.play_3d(&"sfx_step_corn", pl.global_position + back * float(fx.phantom_step_behind_m))
		return
	if _next_step < 0.0:
		_next_step = _t + _rng.randf_range(float(fx.phantom_step_every_s_min), float(fx.phantom_step_every_s_max))
	elif _t >= _next_step:
		_next_step = -1.0
		if _today < int(fx.phantom_step_max_per_day):
			_today += 1
			_steps_left = int(fx.phantom_step_steps)
			_step_at = _t
			Log.event(&"phantom_step", {"day": Clock.day, "n": _today})


func _gaze(delta: float) -> void:
	var traps := get_parent().get_node_or_null(^"TrapRace")
	var farm := get_parent().get_node_or_null(^"Farm")
	if traps == null or farm == null or farm.store == null:
		return
	for p in Game.players:
		if Quirks.of(p) != &"ocd" or not Game.players[p].has("pos"):
			_dwell.erase(p)
			continue
		var fx := Quirks.effects(&"ocd")
		var seen := -1
		for i in farm.store.scarecrows.size():
			if _cool.get("%d:%d" % [p, i], 0.0) <= _t and in_gaze(farm.store.scarecrows[i], Game.players[p].pos, float(fx.scarecrow_gaze_m), float(fx.scarecrow_gaze_arc_deg)):
				seen = i
				break
		if seen < 0:
			_dwell.erase(p)
			continue
		_dwell[p] = float(_dwell.get(p, 0.0)) + delta
		if _dwell[p] >= float(fx.scarecrow_gaze_dwell_s):
			_dwell.erase(p)
			_cool["%d:%d" % [p, seen]] = _t + float(fx.scarecrow_gaze_cooldown_s)
			Log.event(&"quirk_ocd_gaze", {"player": p, "scarecrow": seen})
			traps.shake(p)
