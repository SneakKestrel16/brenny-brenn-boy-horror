extends RefCounted
## Pure rules of the AI Director (doc 03 section 11). No autoloads, so
## tests/creature/test_director_logic.gd runs them headless. game/ai_director/ai_director.gd feeds them.


## Doc 03 section 11.1 phase machine. `t` is seconds in `phase`; `ph` is `ai_director.json` `phases`;
## `relax_s` is this relax's minimum (`relax_min_s`, or `jumpscare_relax_s` after a jumpscare).
## Inference (P3-04): the meter decays in `fade` as in `relax`, else a quiet fade never reaches `fade_to`.
static func next_phase(phase: StringName, t: float, meter: float, ph: Dictionary, relax_s: float) -> StringName:
	match phase:
		&"build_up":
			if meter >= float(ph.peak_at):
				return &"peak"
		&"peak":
			if t >= float(ph.peak_max_s):
				return &"fade"
		&"fade":
			if meter <= float(ph.fade_to):
				return &"relax"
		&"relax":
			if t >= relax_s and meter <= 0.0:
				return &"build_up"
	return phase


## Doc 03 section 11.3: the third of the day (1, 2 or 3) at `t` seconds of a `day_s` day.
static func day_third(t: float, day_s: float, arc: Dictionary) -> int:
	var f := t / maxf(day_s, 0.001)
	return 1 if f < float(arc.second_third_at) else (2 if f < float(arc.last_third_at) else 3)


## Doc 03 section 11.4: a big or private event may land on a player with `count` of them today, the
## last at `last_t` (-INF for none).
static func scare_ok(count: int, last_t: float, now: float, rules: Dictionary) -> bool:
	return count < int(rules.big_per_player_per_day) and now - last_t >= float(rules.big_gap_s)


## Doc 03 section 11.4: a player not yet scared today is `unscared_weight` : `scared_weight` likelier.
static func scare_weight(count: int, rules: Dictionary) -> float:
	return float(rules.unscared_weight) if count == 0 else float(rules.scared_weight)


## Doc 03 section 13: a `scare_*` record's pick weight on `day` in `third` (0 is not day), 0 while closed:
## before `opens_day`, or by day before `from_third`. A Tainted target scales it by `tainted_mult`.
static func scare_weight_of(rec: Dictionary, day: int, third: int, tainted: bool) -> float:
	if day < int(rec.opens_day) or (third != 0 and third < int(rec.from_third)):
		return 0.0
	return float(rec.weight) * (float(rec.get("tainted_mult", 1.0)) if tainted else 1.0)


## Doc 03 section 7.2 and 11.4: the day's trap race start distance. `u` is a roll in -1..1. A normal
## trap keeps `floor_m` (pry plus `min_spare_s` at the approach speed); a deep trap has no floor.
static func race_m(base_m: float, bend_m: float, u: float, floor_m: float) -> float:
	return maxf(base_m + bend_m * u, floor_m)


## Doc 03 section 11.6, D-021: the first region on a shortest path from `from` to `to` over `links`
## (region -> Array of neighbours). `to` itself when adjacent, `from` when there is no path.
static func hop(links: Dictionary, from: String, to: String) -> String:
	if from == to or not links.has(from):
		return from
	var prev := {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var r: String = queue.pop_front()
		if r == to:
			while prev[r] != from:
				r = prev[r]
			return r
		for n: String in links.get(r, []):
			if not prev.has(n):
				prev[n] = r
				queue.append(n)
	return from
