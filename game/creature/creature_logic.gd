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


## P5-56 (Q-354): metres of the segment a-b (x, z) outside every rect in `corn`. Each rect clips the segment
## (Liang-Barsky); overlapping clips merge, so corn counted twice still counts once.
static func open_m(a: Vector2, b: Vector2, corn: Array) -> float:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return 0.0
	var spans: Array = []
	for r: Rect2 in corn:
		var t0 := 0.0
		var t1 := 1.0
		var ok := true
		for k in 2:
			var p := -d[k]
			var lo := a[k] - r.position[k]
			var hi := r.end[k] - a[k]
			for side in [[p, lo], [-p, hi]]:
				if absf(side[0]) < 0.000001:
					if side[1] < 0.0:
						ok = false
				else:
					var t: float = side[1] / side[0]
					if side[0] < 0.0:
						t0 = maxf(t0, t)
					else:
						t1 = minf(t1, t)
		if ok and t1 > t0:
			spans.append(Vector2(t0, t1))
	spans.sort_custom(func(u: Vector2, v: Vector2) -> bool: return u.x < v.x)
	var covered := 0.0
	var end := 0.0
	for s: Vector2 in spans:
		if s.y > end:
			covered += s.y - maxf(s.x, end)
			end = s.y
	return length * (1.0 - covered)


## P5-56: route waypoints in corn at least `min_m` thick (the ring): along the edge that faces the middle of all
## the corn, `inset_m` in, `step_m` apart. Cover points sit only by work spots, so a ring walk had no points.
static func corn_waypoints(corn: Array, step_m: float, inset_m: float, min_m: float) -> Array:
	if corn.is_empty():
		return []
	var all: Rect2 = corn[0]
	for r: Rect2 in corn:
		all = all.merge(r)
	var mid := all.get_center()
	var out: Array = []
	for r: Rect2 in corn:
		if minf(r.size.x, r.size.y) < min_m:
			continue
		var k := 0 if r.size.x < r.size.y else 1  # the thin axis: the edge runs along the other one
		var edge := r.position[k] + inset_m if absf(r.position[k] - mid[k]) < absf(r.end[k] - mid[k]) else r.end[k] - inset_m
		var along := r.size[1 - k]
		var n := maxi(1, roundi(along / step_m))
		for i in n:
			var p := Vector2.ZERO
			p[k] = edge
			p[1 - k] = r.position[1 - k] + along * (i + 0.5) / n
			out.append(p)
	return out


## P5-56: hop costs between every pair of `via` points, flat (i * n + j): length plus `open_mult` times open_m.
static func hop_costs(via: Array, corn: Array, open_mult: float) -> PackedFloat32Array:
	var n := via.size()
	var out := PackedFloat32Array()
	out.resize(n * n)
	for i in n:
		for j in range(i + 1, n):
			var a: Vector2 = via[i]
			var b: Vector2 = via[j]
			out[i * n + j] = a.distance_to(b) + open_mult * open_m(a, b, corn)
			out[j * n + i] = out[i * n + j]
	return out


## P5-56 (Q-354, doc 01 "Behavior states" Lurk "moves through corn"): the hops from `from` to `to` through
## `via` points, cheapest by length plus `open_mult` times the metres in the open (open_m). `vv` is hop_costs(via)
## (computed here when empty). Returns the points to walk, ending with `to`. Plain O(n^2) Dijkstra.
static func corn_route(from: Vector2, to: Vector2, via: Array, corn: Array, open_mult: float, vv := PackedFloat32Array()) -> Array:
	var m := via.size()
	if vv.size() != m * m:
		vv = hop_costs(via, corn, open_mult)
	var pts: Array = [from] + via + [to]
	var n := pts.size()
	var cost := func(u: int, v: int) -> float:
		if u > 0 and u <= m and v > 0 and v <= m:
			return vv[(u - 1) * m + v - 1]
		var a: Vector2 = pts[u]
		var b: Vector2 = pts[v]
		return a.distance_to(b) + open_mult * open_m(a, b, corn)
	var best: Array = []
	var prev: Array = []
	var done: Array = []
	best.resize(n)
	prev.resize(n)
	done.resize(n)
	best.fill(INF)
	prev.fill(-1)
	done.fill(false)
	best[0] = 0.0
	for _i in n:
		var u := -1
		for j in n:
			if not done[j] and (u < 0 or best[j] < best[u]):
				u = j
		if u < 0 or best[u] == INF or u == n - 1:
			break
		done[u] = true
		for v in n:
			if not done[v]:
				var c: float = best[u] + cost.call(u, v)
				if c < best[v]:
					best[v] = c
					prev[v] = u
	var out: Array = []
	var at := n - 1
	while at > 0:
		if out.is_empty() or (pts[at] as Vector2).distance_to(out[0]) > 0.1:
			out.push_front(pts[at])
		at = prev[at]
	return out
