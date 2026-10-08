extends RefCounted
## Doc 05 section 7 step 3: hold progress. `rate` is 1 / (product of multipliers), re-evaluated every
## tick, so a mid-hold multiplier change alters speed from then on without restarting.


static func rate(mults: Array = []) -> float:
	var p := 1.0
	for m in mults:
		p *= float(m)
	return 1.0 / maxf(p, 0.0001)


## New progress after `delta` seconds of a hold of `hold_s` seconds at `rate`; 1.0 means complete.
static func advance(progress: float, delta: float, rate_: float, hold_s: float) -> float:
	return minf(progress + delta * rate_ / maxf(hold_s, 0.0001), 1.0)
