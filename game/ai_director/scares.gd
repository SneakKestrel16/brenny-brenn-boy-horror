extends Node
## Doc 03 section 13: the scares (P3-05). Node `Scares`, added by `main.gd` after the Creature.
## Host: while the AI Director allows a big scare on a player (`allow(&"scare", peer)`: day, third 2 or 3,
## peak, the scare budget, a won town stand roll there (D-115)), rolls a chance each second; on a hit it picks a `scare_*`
## record (ai_director.json) by weight among the open ones that fit where the player is. It sends the
## build-up, checks the rules again after it, then spends the budget, sends the scare (private: the target
## only; public: all), applies the cost and logs `scare`. Every peer plays what it is sent.
## Presentation may read true positions (section 11). Not built: `the trap` (doc 03 section 13 says "not a
## race", but a pry only happens in a trap race, so nothing triggers it), `scarecrow_moved` (weight 0, placed
## by sabotage in P3-06), the teammate's hat on the wrong count (no hats yet: a plain farmer shape), the
## jumpscare on the screens of others in view, and the creature's own body in it (a capsule flash only).

const Logic := preload("res://game/ai_director/director_logic.gd")
const TIMED: Array[StringName] = [&"jumpscare", &"shed", &"whisper", &"own_voice", &"wrong_count", &"hallucination"]
const BUILDUP_S := 3.0  ## placeholder: build-up before the scare lands (doc 03 section 13 "built up")
const TICK_S := 1.0
const SCARE_CHANCE_PER_S := 0.05  ## placeholder: a 20 s peak scares a player about 2 times in 3 ("rare", "randomizes")
const FAKE_OUT_CHANCE_PER_S := 1.0 / 240.0  ## placeholder: about one crow fake-out every 4 minutes, at random
const BEHIND_M := 1.2  ## placeholder: the whisper's source behind the target
const IN_VIEW_DOT := 0.5  ## placeholder: "a place the player can see" read as within 60 degrees of facing; walls not checked
const LUNGE_BLACK_S := 1.5  ## placeholder: the disarm lunge's cut to black
const KNOCKDOWN_S := 2.0  ## placeholder: jumpscare knockdown camera
const APPARITION_MAX_S := 20.0  ## placeholder: a silhouette nobody looks at still goes

var _ok := false
var _dir: Node
var _creature: Node
var _d: Dictionary = {}  ## scare kind (without `scare_`) -> record
var _rules: Dictionary = {}
var _t := 0.0
var _busy: Dictionary = {}  ## peer -> a scare in its build-up
var _wrong_today := 0
var _own: Dictionary = {}  ## peer -> own-voice scares this season
var _lunged: Dictionary = {}  ## peer -> the disarm hold already rolled
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Net.apply_received.connect(_on_apply)
	if not Game.is_host() or not Data.has_table(&"ai_director"):
		return
	_ok = true
	for r in Data.records(&"ai_director"):
		if String(r.id).begins_with("scare_") and r.id != "scare_rules":
			_d[StringName(String(r.id).trim_prefix("scare_"))] = r
	_rules = Data.record(&"ai_director", &"scare_rules")
	_rng.seed = Game.seed_value + 5
	Clock.day_changed.connect(func(_day: int) -> void: _wrong_today = 0)
	_setup.call_deferred()


func _setup() -> void:
	_dir = get_tree().get_first_node_in_group(&"ai_director")
	_creature = get_tree().get_first_node_in_group(&"creature")


# --- host ---------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _ok or _dir == null or _creature == null:
		return
	_disarm_lunges()
	_t += delta
	if _t < TICK_S:
		return
	_t = 0.0
	if _rng.randf() < FAKE_OUT_CHANCE_PER_S * TICK_S:
		_fake_out()  # inference: doc 01 does not say when fake-outs fire; at random, so they tell nothing
	var peers: Array = Game.players.keys().filter(func(p: int) -> bool: return p > 0 and _alive(p))  # a bot has nobody to scare
	peers.sort()
	for i in range(peers.size() - 1, 0, -1):  # seeded shuffle: targets reproduce from --seed
		var j := _rng.randi_range(0, i)
		var s: int = peers[i]
		peers[i] = peers[j]
		peers[j] = s
	for p: int in peers:
		if _busy.has(p) or not _dir.allow(&"scare", p) or _rng.randf() >= SCARE_CHANCE_PER_S * TICK_S:
			continue
		var kind := _pick(p)
		if kind != &"":
			fire(kind, p)
			return


## A kind for `p` by weight among the open records that fit where `p` is; empty for none.
func _pick(p: int) -> StringName:
	var kinds: Array[StringName] = []
	var w := PackedFloat32Array()
	for k in TIMED:
		var x := Logic.scare_weight_of(_d[k], Clock.day, _dir.third(), bool(Game.players[p].get("tainted", false)))
		if x > 0.0 and fits(k, p) == "":
			kinds.append(k)
			w.append(x)
	return kinds[_rng.rand_weighted(w)] if not kinds.is_empty() else &""


## Why `kind` cannot land on `p` where they are now; empty when it can (doc 03 section 13 rules).
func fits(kind: StringName, p: int) -> String:
	if not _alive(p):
		return "not_alive"
	var pos: Vector3 = Game.players[p].pos
	match kind:
		&"jumpscare":
			if not _creature._outdoor(pos):
				return "indoors"  # a building, lit or not (inference: doc 03 says lit; dark ones are left out too)
			if _race_on():
				return "trap_race"
			if _creature.state == &"chase":
				return "chase"
		&"shed":
			if _creature._building(pos) != "ToolShed":
				return "not_in_shed"
		&"whisper":
			if _voice(p, false) == "":
				return "no_teammate_clip"
		&"own_voice":
			if int(_own.get(p, 0)) >= int(_rules.own_voice_per_player_per_season):
				return "season_cap"
			if _voice(p, true) == "":
				return "no_own_clip"
		&"wrong_count", &"hallucination":
			if kind == &"wrong_count" and _wrong_today >= int(_rules.wrong_count_per_team_per_day):
				return "team_cap"
			if not _creature._outdoor(pos):
				return "indoors"
			if _in_view(p, _d.hallucination.distance_m) == Vector3.INF:
				return "no_place_in_view"
		&"disarm_lunge":
			pass
		_:
			return "not_built"
	return ""


## Host: play `kind` on `p` (the AI Director allowed it, or the dev console `forced` it). The build-up first;
## then, unless forced, the rules again: a target who went indoors, into a trap race, lost the town stand roll, or died
## gets no scare and spends no budget (`scare_dropped`).
func fire(kind: StringName, p: int, hold: Dictionary = {}, forced := false) -> void:
	var rec: Dictionary = _d[kind]
	var private := bool(rec.private)
	_busy[p] = true
	_send(&"buildup", p, private, Game.players[p].pos, String(kind))
	await get_tree().create_timer(BUILDUP_S).timeout
	if not is_inside_tree():
		return
	_busy.erase(p)
	if not Game.players.has(p):  # left during the build-up, forced or not
		return
	var why := "" if forced else fits(kind, p)
	if why == "" and not forced and not _dir.allow(&"scare", p):
		why = "director"
	if why != "":
		Log.event(&"scare_dropped", {"kind": String(kind), "target": p, "why": why})
		return
	var pos: Vector3 = Game.players[p].pos
	var extra := ""
	match kind:
		&"jumpscare":
			_dir.jumpscare(p)
		&"shed":
			pos = _door_of("ToolShed")
		&"whisper", &"own_voice":
			extra = _voice(p, kind == &"own_voice")
			var yaw := float(Game.players[p].get("yaw", 0.0))
			pos += Vector3(sin(yaw), 0.0, cos(yaw)) * BEHIND_M
		&"wrong_count", &"hallucination":
			pos = _in_view(p, _d.hallucination.distance_m)
			if pos == Vector3.INF:  # forced by the dev console with nowhere in view: straight ahead
				var yaw := float(Game.players[p].get("yaw", 0.0))
				pos = Game.players[p].pos + Vector3(-sin(yaw), 0.0, -cos(yaw)) * float(_d.hallucination.distance_m[0])
	if bool(rec.big) and kind != &"jumpscare":
		_dir.spend(&"scare", p)
	if kind == &"wrong_count":
		_wrong_today += 1
	elif kind == &"own_voice":
		_own[p] = int(_own.get(p, 0)) + 1
	_send(kind, p, private, pos, extra)
	if kind in [&"jumpscare", &"disarm_lunge"]:
		var traps := get_parent().get_node_or_null(^"TrapRace")
		if traps:
			traps.shake(p)  # Shaken 60 s, never Taint (doc 01 "Jumpscares")
	if kind == &"jumpscare":
		var farm := get_parent().get_node_or_null(^"Farm")
		if farm and farm.cans:
			farm.cans.drop(p)  # dropped items: the can in hand (the shovel and a held trap stay, not built)
	Log.event(&"scare", {"kind": String(kind), "target": p, "big": bool(rec.big), "private": private,
		"day": Clock.day, "third": _dir.third(), "position": _v(pos), "extra": extra if extra else null,
		"hold": hold.get("target") if hold else null})


## Doc 03 section 13 "Disarm lunge": a player starting the disarm hold is lunged at, if allowed now.
func _disarm_lunges() -> void:
	var farm := get_parent().get_node_or_null(^"Farm")
	if farm == null or farm.registry == null:
		return
	for p in _lunged.keys():
		if not farm.registry.holds.has(p):
			_lunged.erase(p)
	for p: int in farm.registry.holds.keys():  # a copy: cancel erases from holds
		var h: Dictionary = farm.registry.holds[p]
		if h.verb != &"disarm_bear" or _lunged.has(p):
			continue
		_lunged[p] = true
		if p > 0 and not _busy.has(p) and _dir.allow(&"scare", p) and Logic.scare_weight_of(_d.disarm_lunge, Clock.day, _dir.third(), false) > 0.0:
			farm.registry.cancel(p, &"scare")
			fire(&"disarm_lunge", p, {"target": String(h.target.name)})


## Public, not big (doc 03 section 13): a crow bursts from the perch nearest a living outdoor player.
## Closed by its record unless `forced`. False when none plays.
func _fake_out(forced := false) -> bool:
	if not forced and Logic.scare_weight_of(_d.fake_out, Clock.day, _dir.third(), false) <= 0.0:
		return false
	var best: Node3D = null
	var best_d := INF
	for p: int in Game.players.keys().filter(_alive):
		if not _creature._outdoor(Game.players[p].pos):
			continue
		for n: Node3D in get_tree().get_nodes_in_group(&"crow_perches"):
			var dist := n.global_position.distance_to(Game.players[p].pos)
			if dist < best_d:
				best = n
				best_d = dist
	if best == null:
		return false
	_send(&"fake_out", -1, false, best.global_position, "")
	Log.event(&"scare", {"kind": "fake_out", "target": -1, "big": false, "private": false, "day": Clock.day,
		"third": _dir.third(), "position": _v(best.global_position)})
	return true


## `apply_scare` to `p` alone when `private` (nothing for a bot: no machine), else to every peer.
func _send(id: StringName, p: int, private: bool, pos: Vector3, extra: String) -> void:
	var args := [id, p if private else -1, pos, extra]
	if not private:
		Net.to_peers(&"apply_scare", args)
	elif p != 1 and p in multiplayer.get_peers():
		Net.to_peers(&"apply_scare", args, [p])
	if not private or p == 1:
		Net.apply_received.emit(&"scare", args)


## A `clip:<owner>:<id>` source for `p`: their own (own voice) or a random living teammate's at least
## COULD_NOT_BE_M away (the whisper: "while the teammate is across the field"); empty for none.
func _voice(p: int, own: bool) -> String:
	var found: Array[String] = []
	for q: int in Game.players:
		if (q == p) != own or Game.voice_setting_of(q) != "lobby_lines":
			continue
		if not own and (not _alive(q) or Game.players[q].pos.distance_to(Game.players[p].pos) < _creature.COULD_NOT_BE_M):
			continue
		for c in _creature._fitting_clips(q, p, true):
			found.append("clip:%d:%s" % [q, c])
	return found[_rng.randi() % found.size()] if not found.is_empty() else ""


## A corn edge or cover point `range_m` [min, max] from `p`, the most in front of their facing; INF for none.
func _in_view(p: int, range_m: Array) -> Vector3:
	var pos: Vector3 = Game.players[p].pos
	var yaw := float(Game.players[p].get("yaw", 0.0))
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var best := Vector3.INF
	var best_dot := IN_VIEW_DOT
	for n: Node3D in get_tree().get_nodes_in_group(&"crow_perches") + get_tree().get_nodes_in_group(&"creature_cover"):
		var to := n.global_position - pos
		to.y = 0.0
		var dot := fwd.dot(to.normalized())
		if to.length() >= float(range_m[0]) and to.length() <= float(range_m[1]) and dot > best_dot:
			best = Vector3(n.global_position.x, 0.0, n.global_position.z)
			best_dot = dot
	return best


func _door_of(building: String) -> Vector3:
	for d: Node3D in get_tree().get_nodes_in_group(&"doors"):
		if String(d.get_parent().name) == building:
			return d.global_position
	return Vector3.ZERO


func _race_on() -> bool:
	var traps := get_parent().get_node_or_null(^"TrapRace")
	return traps != null and not traps.races.is_empty()


func _alive(p: int) -> bool:
	return Game.players.has(p) and Game.players[p].has("pos") and not Game.is_ghost(p)


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]


## D-081: the body's own hit (`cre_jumpscare_hit_gaunt` for `body_gaunt`), else the shared one when the body
## is not known yet or its file is missing (`play_2d` would fail silently).
static func jumpscare_id(body: StringName) -> StringName:
	var id := "cre_jumpscare_hit_" + String(body).trim_prefix("body_")
	return StringName(id) if body != &"" and ResourceLoader.exists("res://assets/audio/%s.wav" % id) else &"cre_jumpscare_hit"


# --- every peer ---------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	if what == &"scare":
		_present(args[0], args[1], args[2], args[3])


## The build-up or the scare, on this machine (doc 03 section 13, doc 08 section 5.4). A build-up whose
## scare is then dropped just ends: the hush lifts on its own.
func _present(kind: StringName, slot: int, pos: Vector3, extra: String) -> void:
	var me := _local_player()
	match kind:
		&"buildup":
			Soundscape.hush(BUILDUP_S + 1.0)
			if extra == "shed":
				Soundscape.play_3d(&"cre_door_bang", _door_of("ToolShed") + Vector3(0.0, 0.0, -3.0))  # a bang outside
			return
		&"jumpscare":
			Soundscape.play_2d(jumpscare_id(Soundscape.creature_body))  # the file carries the body thud and the running away (CEO, P3-08)
			if me:
				me.knockdown_camera(KNOCKDOWN_S)
				_apparition(me.global_position - me.global_transform.basis.z * 1.5, true, 0.4)
		&"disarm_lunge":
			for i in 2:
				Soundscape.play_3d(&"cre_corn_part", pos + Vector3(randf_range(-3.0, 3.0), 0.0, -4.0))
				await get_tree().create_timer(0.3).timeout
				if not is_inside_tree():
					return
			Soundscape.play_2d(&"cre_lunge")
			_black(LUNGE_BLACK_S)
		&"shed":
			Soundscape.play_3d(&"sfx_door_slam", pos)
			if me:
				_lock(me, float(Data.value(&"ai_director", &"scare_shed", &"locked_s")))
		&"whisper", &"own_voice":
			Net.apply_received.emit(&"lure", ["scare_%s" % kind, extra, pos, slot, &"none", false])  # the lure clip player
		&"wrong_count", &"hallucination":
			Soundscape.play_2d(&"cre_presence_swell")
			_apparition(pos, kind == &"hallucination", APPARITION_MAX_S)
		&"fake_out":
			Soundscape.play_3d(&"sfx_step_corn", pos)  # the rustle; no layer change (doc 08 section 4.4 rule 4)
			Soundscape.play_3d(&"sfx_crow_burst", pos)
	if not Game.is_host() and Game.local_peer() == slot:
		Log.event(&"scare_applied", {"kind": String(kind)})


func _local_player() -> Node:
	var players := get_parent().get_node_or_null(^"Players")
	return players.player(Game.local_peer()) if players else null


## Locked in the shed: a placeholder freeze (no door lock yet); a Shaken it interrupts carries on after.
func _lock(me: Node, seconds: float) -> void:
	var was_s: float = me._shaken_s
	var was_mult: float = me.speed_mult
	me.shake(seconds, 0.0)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(me) and was_s > seconds:
		me.shake(was_s - seconds, was_mult)


## A placeholder silhouette (no model yet): the creature (tall, black) or a farmer. It goes after
## `vanish_look_s` looked at, `vanish_approach_m` walked toward it, or `seconds`.
func _apparition(pos: Vector3, creature: bool, seconds: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.height = 2.6 if creature else 1.8
	mesh.radius = 0.35 if creature else 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02) if creature else Color(0.35, 0.28, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if creature else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh.material = mat
	var n := MeshInstance3D.new()
	n.mesh = mesh
	get_parent().add_child(n)
	n.global_position = pos + Vector3.UP * mesh.height / 2.0
	var h: Dictionary = Data.record(&"ai_director", &"scare_hallucination")
	var me := _local_player()
	var start_d: float = me.global_position.distance_to(pos) if me else 0.0
	var look := 0.0
	var t := 0.0
	while t < seconds and is_instance_valid(n):
		var dt := get_process_delta_time()
		t += dt
		var cam := get_viewport().get_camera_3d()
		if cam and (-cam.global_transform.basis.z).dot((n.global_position - cam.global_position).normalized()) > 0.97:
			look += dt
		if look >= float(h.vanish_look_s) or (is_instance_valid(me) and start_d - me.global_position.distance_to(pos) >= float(h.vanish_approach_m)):
			break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if is_instance_valid(n):
		n.queue_free()


func _black(seconds: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(layer):
		layer.queue_free()
