extends "res://game/interaction/interactable.gd"
## Doc 05 section 11 (P2-11): a flag spot. Built three ways: the client builds one for its ring while
## placing, the host builds one per request (`flag:<x>,<z>`; the HoldRegistry frees it), and every peer
## gives each drawn flag one with a pick body, so any player can aim at it and pull it up (`remove_flag`,
## P4-33, D-142). Each player has at most `labor.json` `place_flag.max_per_player` flags out (doc 01 "Flags", D-120).

const MIN_GAP_M := 1.0  ## placeholder: two flags closer than this are one flag

var pos := Vector3.ZERO
var sweep: Node  ## the TrapSweep
var by := 0  ## a drawn flag: the peer who placed it


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


## Client: anyone may pull up a drawn flag (D-142).
func verbs_for(_st: Dictionary) -> Array[StringName]:
	return [&"remove_flag"]


func can_start(verb: StringName, st: Dictionary) -> StringName:
	match verb:
		&"place_flag":
			if sweep.flag_near(pos, MIN_GAP_M):
				return &"flag_here"
			return &"flag_limit" if sweep.count_of(int(st.get("peer", 0))) >= sweep.limit() else &""
		&"remove_flag":
			return &"" if sweep.flag_at(pos) >= 0 else &"no_flag"
	return &"no_such_verb"


func complete(verb: StringName, peer: int, _st: Dictionary) -> void:
	if verb == &"remove_flag":
		sweep.remove_flag(sweep.flag_at(pos), peer)
	else:
		sweep.add_flag(pos, peer)
