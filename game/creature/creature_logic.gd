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
