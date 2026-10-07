extends Node
## Doc 05 section 8: the Noise interface. Host-side fan-out only; the creature (AI Programmer) connects
## to `noise_emitted`. Nothing is stored except a per-kind debug counter. Radii live in creature.json
## (`noise_<kind>` records, doc 03 section 3.1), never in code.

signal noise_emitted(position: Vector3, radius_m: float, kind: StringName, source_peer: int)

## Doc 03 section 3.1: Tainted footsteps are x1.5 (placeholder). Taint is off in Phase 1 (doc 05 section 20).
const TAINT_STEP_MULT := 1.5

var counts: Dictionary = {}  ## kind -> emissions, for the debug view


func emit(position: Vector3, radius_m: float, kind: StringName, source_peer: int) -> void:
	if not Game.is_host():
		push_warning("Noise.emit(%s) called on a client; ignored" % kind)
		return
	counts[kind] = int(counts.get(kind, 0)) + 1
	if radius_m <= 0.0 or (source_peer != 0 and Game.is_ghost(source_peer)):
		return
	noise_emitted.emit(position, radius_m, kind, source_peer)


func emit_kind(kind: StringName, position: Vector3, source_peer: int, mult: float = 1.0) -> void:
	var r := float(Data.value(&"creature", StringName("noise_" + kind), &"radius_m"))
	if kind.begins_with("step_") and bool(Game.players.get(source_peer, {}).get("tainted", false)):
		mult *= TAINT_STEP_MULT
	emit(position, r * mult, kind, source_peer)


## `Voice` calls this; radius = cap * (byte / byte_max)^exponent (doc 03 section 3.1 `voice` row).
func emit_voice(position: Vector3, volume_byte: int, source_peer: int) -> void:
	var rec := Data.record(&"creature", &"noise_voice")
	var r := float(rec["radius_m"]) * pow(float(volume_byte) / float(rec["byte_max"]), float(rec["exponent"]))
	emit(position, r, &"voice", source_peer)
