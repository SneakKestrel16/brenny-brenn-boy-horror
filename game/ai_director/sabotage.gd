extends Node
## Doc 03 section 10: sabotage (P3-06). Node `Sabotage`, a child of the AiDirector, which adds it on every peer.
## Host: each day spends the day's disturbance count (doc 02 section 11, ramp_up.json `disturbances_4p`
## scaled by headcount) over the first third of the day, from the pool open that day (sabotage_logic.gd).
## Each lands in a region with no living player in it (section 11.6: by region, never at a player; true
## positions, placement only), leaves its clue and waits for its fix. Free and daily: one scarecrow moves.
## Through the night it counts who stayed outside; at dawn it tramples plots (section 10 "Trample" and
## "Unattended farm") nearest where the creature is, and `farm_damage` is what the Death node's
## `dawn_summary` reports. Logs `disturbance_placed`, `disturbance_fixed`, `trample`.
## Every peer: the clue marks, the scarecrows and the bury / pull-seeds targets (`apply_disturbance`).
## Not built: `broken_fence`, `pumpkin_gnaw` (D-059, Phase 4), buying a stolen tool back, burying a dead crow
## by washing, the full-wipe doubling of farm damage (doc 02 section 14), the cost points (the budget is the
## count, doc 03 section 10 "Budget"; the points are placeholders left for `sim`).

const Logic := preload("res://game/ai_director/sabotage_logic.gd")
const Interactable := preload("res://game/interaction/interactable.gd")
const Plot := preload("res://game/farming/plot.gd")

const AWAY_M := 12.0  ## placeholder: never placed nearer a living player than this ("never at a player")
const BY_TRAP_M := 1.6  ## placeholder: a stolen tool lies beside the armed trap, just past its 1.0 m spring
const CHECK_S := 0.5  ## host: how often fixes are checked
const SCARECROWS := ["scarecrow_01", "scarecrow_02"]  ## doc 04: the two field scarecrows' start spots

## A dead crow or strange seeds: the fix hold on the mark (`bury` needs the shovel in hand, doc 03 section 10.1).
class FixTarget extends "res://game/interaction/interactable.gd":
	var verb: StringName
	var did := 0
	var sab: Node

	func verbs_for(_st: Dictionary) -> Array[StringName]:
		var out: Array[StringName] = [verb]
		return out

	func can_start(v: StringName, st: Dictionary) -> StringName:
		if v != verb:
			return &"no_such_verb"
		return &"no_shovel" if v == &"bury" and not bool(st.get("shovel", false)) else &""

	func complete(_v: StringName, peer: int, _st: Dictionary) -> void:
		sab.fixed(did, peer, verb)


var farm_damage := 0  ## host: coins of crops trampled at the last dawn (read by death.gd's `dawn_summary`)
var live: Dictionary = {}  ## host: id -> {kind, pos, plot, can, src}; disturbances not fixed yet

var _ok := false
var _recs: Dictionary = {}  ## kind -> sabotage.json record
var _dir: Node
var _creature: Node
var _farm: Node
var _plan: Array = []  ## host: today's seconds-into-day of each placement still to come
var _planned_day := 0
var _next_id := 1
var _check_t := 0.0
var _hands_on: Dictionary = {}  ## host: target id -> the last peer seen holding a verb on it
var _out_s: Dictionary = {}  ## host, tonight: peer -> seconds outdoors alive
var _nobody_s := 0.0  ## host, tonight: seconds with no living player outdoors
var _crows: Array = []  ## every peer: the scarecrow nodes
var _crow_at: Array = []  ## host: each scarecrow's spot name
var _marks: Dictionary = {}  ## every peer: id -> mark node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"sabotage")
	Net.apply_received.connect(_on_apply)
	_setup.call_deferred()  # after the world and the Farm are in the tree
	if not Game.is_host() or not Data.has_table(&"sabotage"):
		return
	_ok = true
	for r in Data.records(&"sabotage"):
		_recs[StringName(r.id)] = r
	_rng.seed = Game.seed_value + 6  # its own stream, like the AI Director's (+4) and the scares' (+5)
	Clock.phase_changed.connect(func(p: StringName) -> void:
		if p == &"night":
			_out_s.clear()
			_nobody_s = 0.0
		elif p == &"dawn":
			_dawn_trample())
	Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
		if what != &"farm_state":
			return  # a late joiner gets the marks and where the scarecrows stand
		for id in live:
			var d: Dictionary = live[id]
			Net.to_peers(&"apply_disturbance", [id, d.kind, d.pos, 0.0, true], [peer])
		for i in _crows.size():
			Net.to_peers(&"apply_disturbance", [-(i + 1), &"scarecrow_moved", _crows[i].global_position, _crows[i].rotation.y, true], [peer]))


func _setup() -> void:
	_dir = get_parent()
	_creature = get_tree().get_first_node_in_group(&"creature")
	_farm = get_tree().get_first_node_in_group(&"farm")
	for s: String in SCARECROWS:
		var m := _spot(s)
		if m:
			_crows.append(_scarecrow(m.global_position, _face_yaw(m.global_position)))
			_crow_at.append(s)


# --- host ---------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _ok or _dir == null or _farm == null or not Clock.running:
		return
	if Clock.phase == &"day" and _planned_day != Clock.day:
		_plan_day()
	while not _plan.is_empty() and Clock.phase == &"day" and Clock.t_phase >= float(_plan[0]):
		_plan.pop_front()
		_place_one()
	if Clock.phase == &"night":
		_track_night(delta)
	for p in _farm.registry.holds:
		if is_instance_valid(_farm.registry.holds[p].target):
			_hands_on[_farm.registry.holds[p].target.id] = p
	_check_t += delta
	if _check_t >= CHECK_S:
		_check_t = 0.0
		_check_fixes()


## Doc 02 section 11: today's count, at even times over the first third; and the free daily scarecrow.
func _plan_day() -> void:
	_planned_day = Clock.day
	var row: Dictionary = Data.record(&"ramp_up", StringName("day_%d" % clampi(Clock.day, 1, 7))) if Data.has_table(&"ramp_up") else {}
	var heads := clampi(Game.player_count(), 2, Game.max_players())
	var n := Data.scaled(int(row.get("disturbances_4p", 0)), &"disturbances", heads)
	var third := float(Data.value(&"ai_director", &"day_arc", &"second_third_at"))
	_plan.clear()
	for i in n:
		_plan.append(Logic.place_at(i, n, Clock.length_of(&"day"), third))
	Log.event(&"sabotage_plan", {"day": Clock.day, "players": heads, "count": n,
		"pool": Logic.pool(_recs.values(), Clock.day).map(func(k: StringName) -> String: return String(k))})
	if bool(_recs.get(&"scarecrow_moved", {}).get("enabled", false)):
		_move_scarecrow()


## One disturbance: the open kinds in a seeded random order, the first that has a place to land.
func _place_one() -> void:
	var kinds := Logic.pool(_recs.values(), Clock.day)
	for i in range(kinds.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var k := kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = k
	for kind in kinds:
		if _place(kind):
			return
	Log.event(&"disturbance_skipped", {"day": Clock.day, "reason": "no_place"})


func _place(kind: StringName) -> bool:
	match kind:
		&"trample":
			var plots := _away(_plots(func(p: Plot) -> bool: return p.state != &"empty"), func(p: Plot) -> Vector3: return p.target_pos())
			if plots.is_empty():
				return false
			_trample(plots[_rng.randi() % plots.size()], false)
		&"stolen_tool":
			var free: Array = _farm.cans.cans.keys().filter(func(c: int) -> bool:
				return _farm.cans.cans[c].holder == 0 and not live.values().any(func(d: Dictionary) -> bool: return d.get("can", -1) == c))
			var spot := _tool_spot()
			if free.is_empty() or spot == Vector3.INF:
				return false
			var c: int = free[_rng.randi() % free.size()]
			_farm.cans.cans[c].pos = spot
			_farm.cans.taint_can(c, &"stolen_tool")
			_farm.cans.snapshot_to(0)
			_add(kind, spot, {"can": c})
		&"dead_crow", &"strange_seeds":
			var at: Array = []
			if kind == &"dead_crow":
				at = get_tree().get_nodes_in_group(&"crow_perches").map(func(n: Node3D) -> Vector3: return Vector3(n.global_position.x, 0.0, n.global_position.z))
			else:
				at = _plots(func(_p: Plot) -> bool: return true).map(func(p: Plot) -> Vector3: return p.target_pos())
			at = _away(at, func(v: Vector3) -> Vector3: return v)
			if at.is_empty():
				return false
			var pos: Vector3 = at[_rng.randi() % at.size()]
			pos.y = 0.0
			_add(kind, pos, {"src": get_tree().get_first_node_in_group(&"taint").add_source(kind, pos)})
		&"generator_kill":
			var gen: Node = _farm.targets["generator"].gen if _farm.targets.has("generator") else null
			if gen == null or not gen.powered() or live.values().any(func(d: Dictionary) -> bool: return d.kind == kind):
				return false
			var pos: Vector3 = _farm.targets["generator"].target_pos()
			if _away([pos], func(v: Vector3) -> Vector3: return v).is_empty():
				return false
			gen.fuel_s = 0.0
			gen._went_dead(&"sabotage")
			_hands_on.erase("generator")
			_add(kind, pos, {})
		_:
			return false
	return true


## Doc 03 section 10: a stolen tool lands beside an armed trap `near_trap_pct` of the time, else at a trap
## spot or the creature's cover. INF when nothing is away from the players.
func _tool_spot() -> Vector3:
	var pick := func(at: Array) -> Vector3:
		at = _away(at, func(v: Vector3) -> Vector3: return v)
		if at.is_empty():
			return Vector3.INF
		var v: Vector3 = at[_rng.randi() % at.size()]
		var a := _rng.randf() * TAU
		return Vector3(v.x + cos(a) * BY_TRAP_M, 0.0, v.z + sin(a) * BY_TRAP_M)
	if _creature and _rng.randi_range(1, 100) <= int(_recs.stolen_tool.near_trap_pct):
		var v: Vector3 = pick.call(_creature._traps.values().filter(func(t: Dictionary) -> bool: return t.armed).map(func(t: Dictionary) -> Vector3: return t.position))
		if v != Vector3.INF:
			return v
	var spots: Array = []
	for g in [&"trap_spots", &"creature_cover"]:
		spots += get_tree().get_nodes_in_group(g).map(func(n: Node3D) -> Vector3: return n.global_position)
	return pick.call(spots)


## Doc 03 section 11.6: keep the items whose position is in a region with no living player and at least
## AWAY_M from every living player; if no region is empty, only the distance rule holds.
func _away(items: Array, pos_of: Callable) -> Array:
	var near := func(v: Vector3) -> bool:
		return Game.players.keys().any(func(p: int) -> bool: return _alive(p) and Vector2(v.x - Game.players[p].pos.x, v.z - Game.players[p].pos.z).length() < AWAY_M)
	var busy: Dictionary = {}
	for p in Game.players:
		if _alive(p):
			busy[_dir.region_of(Game.players[p].pos)] = true
	var far := items.filter(func(it: Variant) -> bool: return not near.call(pos_of.call(it)))
	var empty := far.filter(func(it: Variant) -> bool: return not busy.has(_dir.region_of(pos_of.call(it))))
	return empty if not empty.is_empty() else far


func _plots(pick: Callable) -> Array:
	return _farm.targets.values().filter(func(t: Node) -> bool: return t is Plot and not t.locked and pick.call(t))


## The crop is lost and the plot is empty to replant (doc 02 section 14). Footprints left on it.
func _trample(p: Plot, dawn: bool) -> void:
	p.state = &"empty"
	p.watered = false
	p.age = 0
	_farm.plot_changed(p)
	_hands_on.erase(p.id)
	_add(&"trample", p.target_pos(), {"plot": p.id, "dawn": dawn})


func _add(kind: StringName, pos: Vector3, extra: Dictionary) -> void:
	var id := _next_id
	_next_id += 1
	var d := {"kind": kind, "pos": pos}
	d.merge(extra)
	live[id] = d
	var line := {"id": id, "kind": String(kind), "day": Clock.day, "region": _dir.region_of(pos),
		"pos": [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)], "clue": String(_recs[kind].clue)}
	for k in extra:
		if k != "src":
			line[k] = extra[k]
	Log.event(&"disturbance_placed", line)
	_send(id, kind, pos, 0.0, true)


## Host: disturbance `id` was fixed by `peer` (0: nobody seen, e.g. the new day's fuel) with `how`.
func fixed(id: int, peer: int, how: StringName) -> void:
	if not live.has(id):
		return
	var d: Dictionary = live[id]
	live.erase(id)
	for p in _farm.registry.holds.keys():  # a second player on the same fix: its target is about to go
		if is_instance_valid(_farm.registry.holds[p].target) and _farm.registry.holds[p].target.id == "dist_%d" % id:
			_farm.registry.cancel(p, &"gone")
	if d.has("src"):
		get_tree().get_first_node_in_group(&"taint").remove_source(d.src)
	Log.event(&"disturbance_fixed", {"id": id, "kind": String(d.kind), "by": peer, "fix": String(how), "day": Clock.day})
	_send(id, d.kind, d.pos, 0.0, false)


## Fixes that happen through other systems: a replant, picking the stolen tool up, refuelling.
func _check_fixes() -> void:
	var gen: Node = _farm.targets["generator"].gen if _farm.targets.has("generator") else null
	for id in live.keys():
		var d: Dictionary = live[id]
		match d.kind:
			&"trample":
				if _farm.targets[d.plot].state != &"empty":
					fixed(id, _hands_on.get(d.plot, 0), &"plant")
			&"stolen_tool":
				var holder: int = _farm.cans.cans[d.can].holder
				if holder != 0:
					fixed(id, holder, &"picked_up")  # its Taint goes to the holder; washing is the rest of the fix
				elif _farm.cans.cans[d.can].pos.distance_to(d.pos) > 0.5:
					fixed(id, 0, &"moved")  # the creature took it again (creature_move_cans)
			&"generator_kill":
				if gen and gen.fuel_s > 0.0:
					var by: int = _hands_on.get("generator", 0)
					fixed(id, by, &"refuel" if by != 0 else &"new_day")  # the tank fills each new day (generator.gd)


## Doc 03 section 10: "nobody outside" counts living players outdoors (creature.gd `_outdoor`, building rects).
func _track_night(delta: float) -> void:
	var anyone := false
	for p in Game.players:
		if _alive(p) and _creature and _creature._outdoor(Game.players[p].pos):
			_out_s[p] = float(_out_s.get(p, 0.0)) + delta
			anyone = true
	if not anyone:
		_nobody_s += delta


## Doc 03 section 10 "Trample (rule restated)", "Unattended farm": plots with a crop nearest the creature
## ("where the creature roamed", doc 01 "Dawn"; inference: its position at dawn stands for the night's roaming).
## Runs before Death's `dawn` (AiDirector is added first), so `farm_damage` is ready for `dawn_summary`.
func _dawn_trample() -> void:
	var best := 0.0
	for p in _out_s:
		best = maxf(best, float(_out_s[p]))
	var gen: Node = _farm.targets["generator"].gen if _farm.targets.has("generator") else null
	var gen_dead: bool = gen != null and not gen.powered()
	var want := Logic.trample_count(_recs.trample, best, _nobody_s, gen_dead)
	var from: Vector3 = _creature.global_position if _creature else Vector3.ZERO
	var crops := _plots(func(p: Plot) -> bool: return p.state != &"empty")
	crops.sort_custom(func(a: Plot, b: Plot) -> bool: return a.target_pos().distance_squared_to(from) < b.target_pos().distance_squared_to(from))
	var hit := crops.slice(0, want)
	for p: Plot in hit:
		_trample(p, true)
	# Inference: damage in coins (the dawn report shows it as a coin row): each lost crop at its sell price.
	farm_damage = hit.size() * int(Data.value(&"crops", &"turnip", &"sell"))
	Log.event(&"trample", {"day": Clock.day, "want": want, "trampled": hit.size(), "best_outside_s": snappedf(best, 0.1),
		"nobody_outside_s": snappedf(_nobody_s, 0.1), "generator_dead": gen_dead, "farm_damage": farm_damage})


## Doc 03 section 13 "scarecrow moved": free, daily, never dangerous. One scarecrow to a free spot among
## `scarecrow_03` to `_07`, never the spot nearest a living player, at least `trap_clear_m` from every trap spot,
## facing the farmhouse door.
func _move_scarecrow() -> void:
	if _crows.is_empty():
		return
	var clear := float(_recs.scarecrow_moved.trap_clear_m)
	var traps := get_tree().get_nodes_in_group(&"trap_spots")
	var spots := get_tree().get_nodes_in_group(&"scarecrow_spots").filter(func(n: Node3D) -> bool:
		return String(n.name) >= "scarecrow_03" and String(n.name) <= "scarecrow_07" \
				and not _crow_at.has(String(n.name)) \
				and not traps.any(func(t: Node3D) -> bool: return t.global_position.distance_to(n.global_position) < clear))
	# Inference: "the one closest to a player" is one spot, the nearest to any living player.
	var near: Node3D = null
	var near_d := INF
	for p in Game.players:
		if _alive(p):
			for n: Node3D in spots:
				var d := n.global_position.distance_squared_to(Game.players[p].pos)
				if d < near_d:
					near = n
					near_d = d
	spots.erase(near)
	if spots.is_empty():
		return
	var i := _rng.randi() % _crows.size()
	var to: Node3D = spots[_rng.randi() % spots.size()]
	_crow_at[i] = String(to.name)
	Log.event(&"disturbance_placed", {"id": -(i + 1), "kind": "scarecrow_moved", "day": Clock.day, "region": _dir.region_of(to.global_position),
		"pos": [snappedf(to.global_position.x, 0.1), snappedf(to.global_position.z, 0.1)], "spot": String(to.name), "clue": "none"})
	_send(-(i + 1), &"scarecrow_moved", to.global_position, _face_yaw(to.global_position), true)


func _send(id: int, kind: StringName, pos: Vector3, yaw: float, on: bool) -> void:
	Net.to_peers(&"apply_disturbance", [id, kind, pos, yaw, on])
	Net.apply_received.emit(&"disturbance", [id, kind, pos, yaw, on])  # the host is its own client


func _alive(p: int) -> bool:
	return Game.players[p].has("pos") and not Game.is_ghost(p)


## Host: bot jobs (game/bots/bot.gd): [verb, target id] for each open fix, oldest first. Test teammates
## may know where things are; the creature never reads this.
func fix_jobs() -> Array:
	_check_fixes()  # a fix finished since the last 0.5 s check is not handed out again
	var out: Array = []
	for id in live:
		var d: Dictionary = live[id]
		match d.kind:
			&"trample": out.append([&"plant", d.plot])
			&"stolen_tool": out.append([&"take_can", "can_%d" % d.can])
			&"dead_crow", &"strange_seeds": out.append([StringName(_recs[d.kind].fix), "dist_%d" % id])
	return out


# --- every peer ---------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	if what != &"disturbance":
		return
	var id: int = args[0]
	var kind: StringName = args[1]
	if id < 0:
		var i := -id - 1
		if i < _crows.size():
			_crows[i].global_position = args[2]
			_crows[i].rotation.y = args[3]
		return
	if _marks.has(id):
		var t := "dist_%d" % id
		if _farm and _farm.targets.has(t):
			_farm.targets.erase(t)
		_marks[id].queue_free()
		_marks.erase(id)
	if args[4]:
		_marks[id] = _mark(id, kind, args[2])


## Placeholder art until the Technical Artist's: dark footprints, three claw scratches, black feathers. A
## dead crow or strange seeds also gets the fix target (Taint draws the crow and the seeds themselves).
func _mark(id: int, kind: StringName, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Disturbance%d" % id
	add_child(root)
	root.global_position = pos
	var rec: Dictionary = Data.record(&"sabotage", kind) if Data.has_table(&"sabotage") else {}
	var clue := StringName(rec.get("clue", "none"))
	var r := RandomNumberGenerator.new()
	r.seed = id  # the same marks on every peer
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.05, 0.04)
	match clue:
		&"footprints":
			for k in 5:
				_box(root, Vector3(0.14, 0.02, 0.3), Vector3(-1.2 + 0.6 * k, 0.01, 0.9 + (0.2 if k % 2 else -0.2)), mat)
		&"claw_marks":
			for k in 3:
				_box(root, Vector3(0.05, 0.02, 0.7), Vector3(0.6 + 0.15 * k, 0.01, 0.0), mat)
		&"feathers":
			for k in 6:
				_box(root, Vector3(0.04, 0.02, 0.18), Vector3(r.randf_range(-0.8, 0.8), 0.01, r.randf_range(-0.8, 0.8)), mat).rotation.y = r.randf() * TAU
	if rec.get("fix_hold_s") != null and _farm:
		var t := FixTarget.new()
		t.verb = StringName(rec.fix)
		t.did = id
		t.sab = self
		t.farm = _farm
		t.id = "dist_%d" % id
		root.add_child(t)
		t.add_pick_body(Vector3(1.0, 0.5, 1.0))
		_farm.targets[t.id] = t
	return root


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## Placeholder scarecrow until the Technical Artist's: a post, a crossbar, a sack head with a dark face on the
## side it faces (-Z).
func _scarecrow(pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Scarecrow%d" % (_crows.size() + 1)
	add_child(root)
	root.global_position = pos
	root.rotation.y = yaw
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.45, 0.36, 0.2)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.04, 0.03)
	_box(root, Vector3(0.12, 2.0, 0.12), Vector3(0, 1.0, 0), straw)
	_box(root, Vector3(1.4, 0.1, 0.1), Vector3(0, 1.5, 0), straw)
	_box(root, Vector3(0.4, 0.45, 0.4), Vector3(0, 2.1, 0), straw)
	_box(root, Vector3(0.25, 0.1, 0.02), Vector3(0, 2.15, -0.21), dark)
	return root


## Yaw that turns -Z toward the farmhouse door.
func _face_yaw(pos: Vector3) -> float:
	for d in get_tree().get_nodes_in_group(&"doors"):
		if String(d.get_meta("building", "")) == "farmhouse":
			var v: Vector3 = (d as Node3D).global_position - pos
			return atan2(-v.x, -v.z)
	return 0.0


func _spot(s: String) -> Node3D:
	for n in get_tree().get_nodes_in_group(&"scarecrow_spots"):
		if String(n.name) == s:
			return n
	return null
