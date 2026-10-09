extends RefCounted
## Pure rules of the animals (P4-08, doc 02 section 10.1). No autoloads, so tests/gameplay/test_animals.gd runs them headless.


## Hold seconds of a round-up: `base_s` times the Rancher's multiplier, rounded up (`season.json` `round_up_rounding`
## `ceil`, doc 02 section 4: perk multipliers round up like every scaled value).
static func round_up_s(base_s: float, mult: float) -> float:
	return ceilf(base_s * mult - 0.0001)


## Coins taken at dawn for `out` animals still loose when dusk ended: `out x scaled(each, pct)`, never taking the
## bank below `floor_coins` (doc 02 section 10.1; the shortfall is not carried). Returns [cost, paid].
static func dusk_bill(out: int, each: int, pct: int, coins: int, floor_coins: int) -> Array[int]:
	var cost := out * ((each * pct + 99) / 100)
	return [cost, clampi(coins - floor_coins, 0, cost)]


## Escape spots at least `min_m` (flat) from the pen gate (doc 04 section 7.3; `season.json` `animal_escape_m`).
static func far_spots(spots: Array, gate: Vector3, min_m: float) -> Array:
	return spots.filter(func(p: Vector3) -> bool: return Vector2(p.x - gate.x, p.z - gate.z).length() >= min_m)


## `from` moved up to `step` toward `to` on the ground plane.
static func step_toward(from: Vector3, to: Vector3, step: float) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if d.length() <= step:
		return Vector3(to.x, from.y, to.z)
	return from + d.normalized() * step
