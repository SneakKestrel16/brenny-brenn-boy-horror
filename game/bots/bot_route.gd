extends RefCounted
## Waypoints for a bot across the DD Phase 1 gray box (doc 04 section 9). Bots have no collision, so
## the route keeps them out of walls and corn: through the barn door, round strip 2's tip, and round
## the barn's west wall to the generator. Coordinates from doc 04 section 9 and its building table.
## ponytail: hand-made for farm_phase1.tscn; a navmesh replaces it when the full farm (DD Phase 2) lands.

const BARN_MIN := Vector2(-8, -20)  ## barn x -8..8, z -20..0 (doc 04 "Buildings")
const BARN_MAX := Vector2(8, 0)
const DOOR_IN := Vector3(0, 0, -2)  ## barn door (0, 0), south side
const DOOR_OUT := Vector3(0, 0, 2)
const STRIP2_X := 15.0  ## strip 2: x 12..18, z -45..2
const STRIP2_TIP_Z := 2.0
const ROUND_STRIP2 := Vector3(15, 0, 9)  ## R2 "south of strip 2's tip" (doc 04 cart route)
const WEST_WALL_X := -8.0
const BEHIND_WEST_Z := 3.0  ## south of the barn's south wall, so the west-wall corner is cleared


static func in_barn(p: Vector3) -> bool:
	return p.x > BARN_MIN.x and p.x < BARN_MAX.x and p.z > BARN_MIN.y and p.z < BARN_MAX.y


## Waypoints from `a` to `b`, ending at `b`. Flat (y 0).
static func path(a: Vector3, b: Vector3) -> Array:
	var out: Array = []
	a.y = 0.0
	b.y = 0.0
	if in_barn(a) and not in_barn(b):
		out += [DOOR_IN, DOOR_OUT]
		a = DOOR_OUT
	if a.x < WEST_WALL_X and a.z < BARN_MAX.y:
		a = Vector3(a.x, 0, BEHIND_WEST_Z)
		out.append(a)
	var tail: Array = []
	if in_barn(b) and not in_barn(a):
		tail = [DOOR_OUT, DOOR_IN]
	elif b.x < WEST_WALL_X and b.z < BARN_MAX.y:
		tail = [Vector3(b.x, 0, BEHIND_WEST_Z)]
	var next: Vector3 = tail[0] if not tail.is_empty() else b
	if (a.x > STRIP2_X) != (next.x > STRIP2_X) and minf(a.z, next.z) < STRIP2_TIP_Z:
		out.append(ROUND_STRIP2)
	out += tail
	out.append(b)
	return out
