extends RefCounted
## Doc 05 section 6 / doc 06 section 6: host speed sanity check. Pure function, no autoloads, so a
## unit test can run it (tests/gameplay/test_speed_check.gd). Horizontal only: gravity is the client's.

const TOLERANCE := 1.2  ## doc 06 section 6: maximum plus 20% (placeholder)
const TELEPORT_X := 3.0  ## doc 06 section 6: a jump over 3x the maximum (placeholder)


## Returns {pos, violation, teleport}. `pos` is what the host keeps and relays: `to` when legal, else
## `from` advanced toward `to` by the allowed distance (clamped), or `from` on a teleport.
static func check(from: Vector3, to: Vector3, dt: float, max_speed: float) -> Dictionary:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var allowed := max_speed * TOLERANCE * maxf(dt, 0.001)
	var d := flat.length()
	if d <= allowed:
		return {"pos": to, "violation": false, "teleport": false}
	if d / maxf(dt, 0.001) > max_speed * TELEPORT_X:
		return {"pos": from, "violation": true, "teleport": true}
	var p := from + flat / d * allowed
	p.y = to.y
	return {"pos": p, "violation": true, "teleport": false}
