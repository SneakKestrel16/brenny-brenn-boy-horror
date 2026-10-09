extends RefCounted
## Pure rules of sabotage (doc 03 section 10, P3-06). No autoloads, so tests/creature/test_director_logic.gd
## runs them headless. game/ai_director/sabotage.gd feeds them `sabotage.json` records.


## Doc 03 section 10 "The pool opens by day": the budgeted, enabled kinds open on `day`. Days 1-2 leave only
## `trample` and `stolen_tool` ("evidence of sabotage only").
static func pool(records: Array, day: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Dictionary in records:
		if bool(r.get("enabled", true)) and bool(r.get("budget", true)) and int(r.opens_day) <= day:
			out.append(StringName(r.id))
	return out


## Doc 03 section 10 "Trample (rule restated)" and "Unattended farm": plots trampled at dawn. `best_out_s`
## is the most seconds any living player spent outdoors that night; `nobody_s` the seconds of night with no
## living player outdoors; `gen_dead` the generator at dawn.
static func trample_count(rec: Dictionary, best_out_s: float, nobody_s: float, gen_dead: bool) -> int:
	var n := int(rec.per_night)
	if best_out_s < float(rec.nobody_outside_s):
		n += int(rec.nobody_outside_extra)
	if gen_dead:
		n += int(rec.dead_generator_extra)
	var over := maxf(nobody_s - float(rec.nobody_outside_s), 0.0)
	return n + mini(floori(over / float(rec.unattended_every_s)), int(rec.unattended_cap))


## Seconds into the day of disturbance `i` of `n`: spread evenly over the first third (doc 03 section 11.3:
## the calm third is "evidence of sabotage only"). Inference: doc 03 does not say when in the day they land.
static func place_at(i: int, n: int, day_s: float, first_third_end: float) -> float:
	return day_s * first_third_end * (i + 0.5) / maxf(n, 1)
