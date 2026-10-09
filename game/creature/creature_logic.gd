extends RefCounted
## Pure rules of the DD Phase 1 creature (doc 03 sections 3.1, 12.3 and 18). No autoloads, so
## tests/creature/test_creature_logic.gd runs them headless. game/creature/creature.gd feeds them.


## Doc 03 section 18 scripted sequence. `t` is seconds since the night began; `stalk_at` is the `t`
## the stalk began (negative until a player is outdoors after `lurk_s`). Returns the scripted state,
## or `&""` once the script is over and the creature hunts by sound.
## Inference (D-023): chase starts `chase_after_s` into the stalk, so the 20 s stalk is cut at 15 s;
## doc 03 section 18 "retreat after 10 s" is read as 10 s of chase, then `retreat_s` of retreat.
static func scripted_state(t: float, stalk_at: float, lurk_s: float, chase_after_s: float, chase_s: float, retreat_s: float) -> StringName:
	if stalk_at < 0.0 or t < lurk_s:
		return &"lurk"
	var d := t - stalk_at
	if d < chase_after_s:
		return &"stalk"
	if d < chase_after_s + chase_s:
		return &"chase"
	if d < chase_after_s + chase_s + retreat_s:
		return &"retreat"
	return &""


## Doc 03 section 3.1 sound memory. Entries are {position, margin, t, peer, kind}; `margin` is
## `effective_radius_m - distance_m` when heard. Entries older than `memory_s` are forgotten. A louder
## (larger margin) entry wins over newer ones within `replace_s` of the newest; ties go to the newest.
## Returns the entry the creature homes on, or {} when it has nothing.
static func pick_heard(memory: Array, now: float, memory_s: float, replace_s: float) -> Dictionary:
	var newest := -INF
	for e in memory:
		if now - float(e.t) <= memory_s:
			newest = maxf(newest, float(e.t))
	var best: Dictionary = {}
	for e in memory:
		if now - float(e.t) > memory_s or float(e.t) < newest - replace_s:
			continue
		if best.is_empty() or float(e.margin) > float(best.margin) or (float(e.margin) == float(best.margin) and float(e.t) > float(best.t)):
			best = e
	return best


## Doc 05 section 18 `lure_result`: `moved_m` is the largest reduction of the target's distance to
## the source since the lure started. Returns the new `moved_m` after one more sample.
static func lure_moved(moved_m: float, start_dist_m: float, now_dist_m: float) -> float:
	return maxf(moved_m, start_dist_m - now_dist_m)


## Doc 03 section 12.1 "Whose voice": one weight for a lure at `p` in `owner`'s voice. `w` holds
## `ai_director.json` `lures` (`weight_own`, `weight_dead`, `weight_alive`).
static func voice_weight(owner: int, p: int, dead: bool, w: Dictionary) -> float:
	return w[&"weight_own"] if owner == p else (w[&"weight_dead"] if dead else w[&"weight_alive"])


## Doc 03 section 3.3 (P3-07): where Taint tracking places a Tainted player. Within `radius_m` of the
## creature: where they are. Farther: a point of their night trail (`trail` oldest first, entries
## {position, t}, already cut to `taint_trail_s` of age) once the creature stands within `pickup_m` of one,
## namely the point `lead` steps newer than the newest point near it, so homing on it walks the trail.
## Vector3.INF when neither.
static func taint_fix(from: Vector3, pos: Vector3, trail: Array, radius_m: float, pickup_m: float, lead: int) -> Vector3:
	if from.distance_to(pos) <= radius_m:
		return pos
	for i in range(trail.size() - 1, -1, -1):
		if from.distance_to(trail[i].position) <= pickup_m:
			return trail[mini(i + lead, trail.size() - 1)].position
	return Vector3.INF


## Doc 01 "Bodies", doc 03 section 2: the season's body, one of `ids` (creature.json `kind` body).
## `forced` (`--body=<id>`, `body_` prefix optional) wins when it names a body; else `seed_n` picks.
static func pick_body(ids: Array, seed_n: int, forced: String = "") -> StringName:
	var f := StringName(forced if forced.begins_with("body_") else "body_" + forced)
	if forced != "" and f in ids:
		return f
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	return ids[rng.randi_range(0, ids.size() - 1)]
