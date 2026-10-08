extends "res://game/interaction/interactable.gd"
## Doc 05 section 11 (P2-11): a spot on the ground where a player holds `place_flag`. Not a scene
## object: the client builds one for its ring, the host builds one per request (`flag:<x>,<z>`), and the
## HoldRegistry frees it when the hold ends. A flag is free and unlimited (doc 01 "Night Traps > Flags").

const MIN_GAP_M := 1.0  ## placeholder: two flags closer than this are one flag

var pos := Vector3.ZERO
var sweep: Node  ## the TrapSweep (host)


## `flag:<x>,<z>` with one decimal; the wire name the client and the host both build.
static func make_id(p: Vector3) -> String:
	return "flag:%.1f,%.1f" % [p.x, p.z]


static func from_id(wire: String) -> Vector3:
	var xz := wire.trim_prefix("flag:").split(",")
	return Vector3(float(xz[0]), 0.0, float(xz[1])) if xz.size() == 2 else Vector3.INF


func _init() -> void:
	range_m = 3.0  # the ray reach (HoldController.REACH_M)


func target_pos() -> Vector3:
	return pos


func can_start(verb: StringName, _st: Dictionary) -> StringName:
	if verb != &"place_flag":
		return &"no_such_verb"
	return &"flag_here" if sweep.flag_near(pos, MIN_GAP_M) else &""


func complete(_verb: StringName, peer: int, _st: Dictionary) -> void:
	sweep.add_flag(pos, peer)
