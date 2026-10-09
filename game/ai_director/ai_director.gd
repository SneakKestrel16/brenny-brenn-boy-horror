extends Node
## Doc 03 section 11: the AI Director (P3-04). Host only, never on clients (CONTRACTS section 4). It keeps
## the tension meter and its phases, the day and night profiles, the day arc, the scare budget per player
## and the daily roll, and nudges the creature's wander region one hop toward the players (section 11.6).
## It decides when and where, never a goal point: the Creature asks `allow(kind, peer)` before a lure,
## stalk, chase or kill and reports with `spend`. Rules live in director_logic.gd; numbers in
## `ai_director.json`. Scares (picking `scare_*`, calling `jumpscare`) live in scares.gd (P3-05); the daily
## disturbances in its child `Sabotage` (sabotage.gd, P3-06).
## Not built: the `harvest_moon` profile (section 14), nightmare trap race numbers (no difficulty yet),
## deep and earshot day deaths (rolled and logged only, nothing reads them).

const Logic := preload("res://game/ai_director/director_logic.gd")

var phase: StringName = &"build_up"
var meter := 0.0
var wander_region := ""  ## the creature's wander region; empty until the first nudge
var roll: Dictionary = {}  ## the day's daily roll: deep_m, earshot_m, trap_race_m, deep_trap_race_m

var _ok := false
var _creature: Node
var _d: Dictionary = {}  ## record id (String) -> record
var _t_phase := 0.0
var _relax_s := 0.0
var _log_t := 0.0
var _nudge_t := 0.0
var _now := 0.0
var _regions: Dictionary = {}  ## name -> Rect2 (x, z), smallest first
var _links: Dictionary = {}  ## name -> Array of linked names
var _big: Dictionary = {}  ## peer -> big or private events today
var _last_big: Dictionary = {}  ## peer -> time of the last one
var _events: Dictionary = {}  ## peer -> build-up events this build-up
var _chases: Dictionary = {}  ## peer -> chases this peak
var _scares: Dictionary = {}  ## peer -> peak scares this peak
var _steps: Dictionary = {}  ## peer -> step noise meter gain in the current second
var _step_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"ai_director")
	var sab := Node.new()  # P3-06: sabotage (sabotage.gd), on every peer for its clue marks; added here, not in main.gd
	sab.set_script(load("res://game/ai_director/sabotage.gd"))
	sab.name = "Sabotage"
	add_child(sab)
	if not Game.is_host() or not Data.has_table(&"ai_director"):
		return
	_ok = true
	for r in Data.records(&"ai_director"):
		_d[String(r.id)] = r
	_rng.seed = Game.seed_value + 4  # its own stream: the creature's picks stay as they were
	_relax_s = float(_d.phases.relax_min_s)
	Clock.day_changed.connect(func(_d2: int) -> void:
		_big.clear()
		_last_big.clear())
	Clock.phase_changed.connect(func(p: StringName) -> void:
		if p == &"dawn":
			_roll(Clock.day + 1)
			wander_region = ""
		_events.clear())
	_setup.call_deferred()  # after the farm and the Creature are in the tree
	_roll(Clock.day)


func _setup() -> void:
	_creature = get_tree().get_first_node_in_group(&"creature")
	if _creature:
		_creature.heard.connect(_on_heard)
		_creature.trap_sprung.connect(func(_i: String, _k: StringName, _p: int, _pos: Vector3, _deep: bool) -> void: _add(_d.meter.trap_sprung))
	var areas := get_tree().get_nodes_in_group(&"regions")
	areas.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _size(a).x * _size(a).z < _size(b).x * _size(b).z)
	for a: Node3D in areas:
		var s := _size(a)
		_regions[String(a.name)] = Rect2(a.global_position.x - s.x / 2.0, a.global_position.z - s.z / 2.0, s.x, s.z)
	var link := float(_d.nudge.link_m)
	for r: String in _regions:
		_links[r] = _regions.keys().filter(func(o: String) -> bool: return o != r and _regions[r].grow(link).intersects(_regions[o]))


static func _size(a: Node3D) -> Vector3:
	for c in a.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			return c.shape.size
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not _ok:
		return
	_now += delta
	var m: Dictionary = _d.meter
	var gain := 0.0
	var outside := 0
	for p in Game.players:
		if not _alive(p):
			continue
		if Clock.phase == &"night" and _creature and _creature._outdoor(Game.players[p].pos):
			outside += 1
		if bool(Game.players[p].get("sprint", false)):
			gain += float(m.sprint_per_s) * delta
	gain += minf(outside * float(m.outside_per_s), float(m.outside_cap_per_s)) * delta
	if phase in [&"fade", &"relax"]:
		gain -= float(m.relax_decay_per_s) * delta
	_add(gain)
	_step_t += delta
	if _step_t >= 1.0:
		_step_t = 0.0
		_steps.clear()
	_t_phase += delta
	var next := Logic.next_phase(phase, _t_phase, meter, _d.phases, _relax_s)
	if next != phase:
		_set_phase(next)
	_log_t += delta
	if _log_t >= float(m.log_every_s):
		_log_t = 0.0
		Log.event(&"tension", {"value": snappedf(meter, 0.1), "phase": String(phase), "profile": String(_profile_id())})
	_nudge_t += delta
	if _nudge_t >= float(_d.nudge.cooldown_s) and Clock.phase == &"night" and phase == &"build_up":
		_nudge_t = 0.0
		_nudge()


func _set_phase(p: StringName) -> void:
	phase = p
	_t_phase = 0.0
	if p == &"build_up":
		_events.clear()
		_relax_s = float(_d.phases.relax_min_s)
	elif p == &"peak":
		_chases.clear()
		_scares.clear()


func _add(v: float) -> void:
	meter = clampf(meter + v, 0.0, float(_d.meter.max))


## Doc 03 section 11.1: a noise the creature heard; `step_*` kinds at most `step_cap_per_s` a second per player.
func _on_heard(radius_m: float, kind: StringName, peer: int) -> void:
	var v := radius_m * float(_d.meter.noise_per_radius_m)
	if String(kind).begins_with("step_"):
		v = minf(v, float(_d.meter.step_cap_per_s) - float(_steps.get(peer, 0.0)))
		_steps[peer] = float(_steps.get(peer, 0.0)) + v
	_add(v)


func lure_worked() -> void:
	if _ok:
		_add(_d.meter.lure_worked)


## P3-05 calls this when a jumpscare plays on `peer`: -30 and a 45 s relax (section 11.1).
func jumpscare(peer: int) -> void:
	if not _ok:
		return
	_add(_d.meter.jumpscare)
	_set_phase(&"relax")
	_relax_s = float(_d.meter.jumpscare_relax_s)
	spend(&"scare", peer)


func _profile_id() -> StringName:
	return &"day" if Clock.phase == &"day" else &"night"


## The day's third (1 to 3), 0 when it is not day.
func third() -> int:
	return Logic.day_third(Clock.t_phase, Clock.length_of(&"day"), _d.day_arc) if Clock.phase == &"day" else 0


## Doc 03 sections 11.2 to 11.5: may the creature do `kind` to `peer` now? Kinds: `lure` and `stalk`
## (night build-up events), `chase` (night peak), `kill`, `day_lure` (private) and `scare` (big). Sanctuary
## blocks all of them. `peer` 0 (a noise with no player) is always allowed. Without the director: yes.
func allow(kind: StringName, peer: int) -> bool:
	if not _ok or peer == 0:
		return true
	if Game.players.has(peer) and _creature and _creature._in_sanctuary(Game.players[peer].pos):
		return false
	var pr: Dictionary = _d["profile_" + _profile_id()]
	var n := int(_events.get(peer, 0))
	match kind:
		&"kill":
			return true
		&"lure":
			return bool(pr.lures) and phase == &"build_up" and n < int(pr.buildup_events_per_player)
		&"stalk":
			return phase == &"peak" or (phase == &"build_up" and n < int(pr.buildup_events_per_player))
		&"chase":
			return phase == &"peak" and int(_chases.get(peer, 0)) < int(pr.peak_chases_per_player)
		&"day_lure":
			return bool(pr.lures) and third() >= 2 and _scare_ok(peer)
		&"scare":
			return third() >= 2 and phase == &"peak" and int(_scares.get(peer, 0)) < int(pr.peak_big_scares_per_player) and _scare_ok(peer)
	return false


func _scare_ok(peer: int) -> bool:
	return Logic.scare_ok(int(_big.get(peer, 0)), float(_last_big.get(peer, -INF)), _now, _d.scare_rules)


## The Creature did `kind` to `peer` (after `allow`).
func spend(kind: StringName, peer: int) -> void:
	if not _ok or peer == 0:
		return
	match kind:
		&"lure", &"stalk":
			if phase == &"build_up":
				_events[peer] = int(_events.get(peer, 0)) + 1
		&"chase":
			_chases[peer] = int(_chases.get(peer, 0)) + 1
		&"day_lure", &"scare":
			_big[peer] = int(_big.get(peer, 0)) + 1
			_last_big[peer] = _now
			if kind == &"scare":
				_scares[peer] = int(_scares.get(peer, 0)) + 1


## Doc 03 section 11.4: one target for a private day event among `peers`, weighted unscared 3 : 1; 0 for none.
func day_lure_target(peers: Array) -> int:
	var ok := peers.filter(func(p: int) -> bool: return allow(&"day_lure", p))
	if ok.is_empty():
		return 0
	var w := PackedFloat32Array()
	for p: int in ok:
		w.append(Logic.scare_weight(int(_big.get(p, 0)), _d.scare_rules))
	return ok[_rng.rand_weighted(w)]


## Doc 03 section 7.2: the trap race start distance for today.
func trap_race_m(deep: bool) -> float:
	if not _ok:
		return float(Data.value(&"ai_director", &"trap_race", &"deep_start_distance_m" if deep else &"start_distance_m"))
	return roll.deep_trap_race_m if deep else roll.trap_race_m


## Doc 03 section 11.4 "Daily variation": deep, earshot and trap race distances. Never a death condition.
func _roll(day: int) -> void:
	var dr: Dictionary = _d.daily_roll
	var tr: Dictionary = _d.trap_race
	var floor_m := (Data.hold_s(&"pry") + float(tr.min_spare_s)) * float(Data.value(&"creature", &"trap_race_speed_mps", &"speed_mps"))
	roll = {"day": day, "deep_m": snappedf(_rng.randf_range(dr.deep_m[0], dr.deep_m[1]), 0.1),
		"earshot_m": snappedf(_rng.randf_range(dr.earshot_m[0], dr.earshot_m[1]), 0.1),
		"trap_race_m": snappedf(Logic.race_m(tr.start_distance_m, tr.bend_m, _rng.randf_range(-1.0, 1.0), floor_m), 0.1),
		"deep_trap_race_m": snappedf(Logic.race_m(tr.deep_start_distance_m, tr.bend_m, _rng.randf_range(-1.0, 1.0), 0.0), 0.1)}
	Log.event(&"daily_roll", roll)


## The region holding `pos` (smallest box first), else the nearest one.
func region_of(pos: Vector3) -> String:
	var best := ""
	var best_d := INF
	var q := Vector2(pos.x, pos.z)
	for r: String in _regions:
		var rect: Rect2 = _regions[r]
		var d := q.distance_to(q.clamp(rect.position, rect.end))
		if d < best_d:
			best = r
			best_d = d
	return best


func region_rect(r: String) -> Rect2:
	return _regions.get(r, Rect2())


## Doc 03 section 11.6: one hop of the wander region toward the region with the most living players (their
## true region: presentation, region only).
func _nudge() -> void:
	if _creature == null or _regions.is_empty():
		return
	var count: Dictionary = {}
	for p in Game.players:
		if _alive(p):
			var r := region_of(Game.players[p].pos)
			count[r] = int(count.get(r, 0)) + 1
	if count.is_empty():
		return
	var toward: String = count.keys().reduce(func(a: String, b: String) -> String: return a if count[a] >= count[b] else b)
	var from := wander_region if wander_region else region_of(_creature.global_position)
	var to := Logic.hop(_links, from, toward)
	if to == wander_region:
		return
	wander_region = to
	Log.event(&"nudge", {"from": from, "to": to, "toward": toward})


## Doc 03 section 11.3: in the calm first third, the day cover keeps `calm_field_keepout_m` from the field
## region the most living players are in. Returns `default` when it already does.
func day_cover(default: Vector3) -> Vector3:
	if not _ok or third() != 1:
		return default
	var field := ""
	var best := 0
	for f in ["field_a", "field_b"]:
		var n := Game.players.keys().filter(func(p: int) -> bool: return _alive(p) and region_rect(f).has_point(Vector2(Game.players[p].pos.x, Game.players[p].pos.z))).size()
		if n > best:
			field = f
			best = n
	var keep := float(_d.day_arc.calm_field_keepout_m)
	var far := func(v: Vector3) -> bool:
		var r := region_rect(field)
		var q := Vector2(v.x, v.z)
		return field == "" or q.distance_to(q.clamp(r.position, r.end)) >= keep
	if far.call(default):
		return default
	for n: Node3D in get_tree().get_nodes_in_group(&"creature_cover"):
		if far.call(n.global_position):
			return n.global_position
	return default


func _alive(p: int) -> bool:
	return Game.players[p].has("pos") and not Game.is_ghost(p)


## Doc 03 section 11.7 / doc 05 section 19.
func debug_state() -> Dictionary:
	var left: Dictionary = {}
	for p in Game.players:
		left[p] = {"events": int(_d.get("profile_" + _profile_id(), {}).get("buildup_events_per_player", 0)) - int(_events.get(p, 0)),
			"big_today": int(_big.get(p, 0))}
	return {"tension": meter, "phase": phase, "profile": _profile_id(), "phase_time_s": _t_phase, "third": third(),
		"nudge_region": wander_region, "nudge_cooldown_s": maxf(0.0, float(_d.get("nudge", {}).get("cooldown_s", 0.0)) - _nudge_t),
		"budget_left": left, "regions": _regions, "roll": roll}
