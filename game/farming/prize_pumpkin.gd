extends "res://game/interaction/interactable.gd"
## P4-05 (doc 02 s6, doc 01 "The Prize Pumpkin"): the one Prize Pumpkin, on the `pumpkin_patch` marker. Host owns
## the counters; every peer shows the size. Size = rank from watered days (and guarded nights for Giant), minus
## one per gnaw and escort bite, floor Sad. Numbers come from pumpkin.json. Verbs: `plant` (free seed, D-017),
## `water_prize_pumpkin`, `lift_prize` (carry it, one hand-load), `set_down_prize` (G). Judged once at the final
## dawn (`judge`), payout logged. P4-11 calls `gnaw()`, P4-12 calls `bite()`.

const SIZES: Array[StringName] = [&"sad", &"medium", &"large", &"giant"]  ## index = rank
const DIAMETER_M := [0.7, 1.3, 2.0, 3.0]  ## gray-box; giant 3 m from doc 07 s11.5

var planted := false
var watered_days := 0  ## days watered, counted when the water goes in
var watered := false  ## watered today
var guarded_nights := 0
var drops := 0  ## gnaws + bites taken
var bites := 0
var carrier := 0  ## peer carrying it, 0 none
var judged := false
var _gnaw_day := 0  ## host: day of the last gnaw (one gnaw per night, doc 03 s10)
var guard_s: Dictionary = {}  ## host, this night: peer -> seconds within guard radius
var _night_closed := true
var _mesh: MeshInstance3D
var _home: Node3D


func _ready() -> void:
	_home = get_parent() as Node3D
	_mesh = MeshInstance3D.new()
	_mesh.mesh = SphereMesh.new()
	_home.add_child(_mesh)
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		Clock.day_changed.connect(func(_d: int) -> void: watered = false; _send())
		Clock.phase_changed.connect(_on_phase)
		Game.player_left.connect(_set_down)  # a carrier who leaves drops it where they last stood
	range_m = 3.0
	_refresh()


# ---- size rules (static so tests can read them) ----

static func short_season() -> bool:
	return int(Data.value(&"season", &"season_days")) < 7


## Rank 0..3 from the day counts, before gnaw and bite drops.
static func base_rank(w_days: int, g_nights: int) -> int:
	if short_season():
		var s: Dictionary = Data.record(&"pumpkin", &"short_season")
		if w_days >= int(s.giant_min_watered_days) and g_nights >= int(s.giant_guarded_nights_min):
			return 3
		return 2 if w_days >= int(s.large_min_watered_days) else (1 if w_days >= int(s.medium_min_watered_days) else 0)
	var rank := 0
	for r in Data.records(&"pumpkin"):
		if r.has("rank") and w_days >= int(r.min_watered_days) and g_nights >= int(r.guarded_nights_min):
			rank = maxi(rank, int(r.rank))
	return rank


static func rank_of(w_days: int, g_nights: int, p_drops: int) -> int:
	return maxi(base_rank(w_days, g_nights) - p_drops, 0)


static func payout_for(rank: int, players: int = 0) -> int:
	return Data.scaled(int(Data.record(&"pumpkin", SIZES[rank]).payout_4p), &"pumpkin", players)


func rank() -> int:
	return rank_of(watered_days, guarded_nights, drops)


func size_name() -> StringName:
	return SIZES[rank()] if planted else &"none"


static func rule(field: StringName) -> int:
	return int(Data.value(&"pumpkin", &"rules", field))


# ---- interaction ----

func target_pos() -> Vector3:
	if carrier != 0 and Game.players.has(carrier) and Game.players[carrier].has("pos"):
		return Game.players[carrier].pos
	return _home.global_position


func verbs_for(st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if judged:
		return out
	if carrier != 0:
		if carrier == Game.local_peer():
			out.append(&"set_down_prize")
	elif not planted:
		out.append(&"plant")
	elif not watered and int(st.get("can", 0)) > 0:
		out.append(&"water_prize_pumpkin")
	else:
		out.append(&"lift_prize")
	return out


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if judged:
		return &"judged"
	match base(verb):
		&"plant":
			return &"not_empty" if planted else &""
		&"water_prize_pumpkin":
			if not planted:
				return &"not_growing"
			if st.get("held_kind", &"") != &"water":
				return &"no_can"
			if watered:
				return &"already_watered"
			return &"" if int(st.get("can", 0)) > 0 else &"can_empty"
		&"lift_prize":
			if not planted:
				return &"not_growing"
			if carrier != 0:
				return &"carried"
			if int(st.get("held_can", -1)) >= 0 or st.get("shovel", false) or st.get("trap", false):
				return &"hands_full"
			return &""
		&"set_down_prize":
			return &"" if carrier == _peer_of(st) and carrier != 0 else &"not_holding"
	return &"no_such_verb"


func _peer_of(st: Dictionary) -> int:
	for p in Game.players:
		if is_same(Game.players[p], st):  # identity: two players can hold equal dictionaries
			return p
	return 0


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	match base(verb):
		&"plant":
			planted = true
			Log.event(&"pumpkin_planted", {"player": peer, "day": Clock.day})
			NoiseBus.emit_kind(&"tool_plant", target_pos(), peer)
		&"water_prize_pumpkin":
			watered = true
			watered_days += 1
			st.can = int(st.can) - 1
			Log.event(&"pumpkin_watered", {"player": peer, "watered_days": watered_days, "size": String(size_name())})
			NoiseBus.emit_kind(&"tool_water", target_pos(), peer)
		&"lift_prize":
			carrier = peer
			st.held_prize = true
			Log.event(&"pumpkin_lifted", {"player": peer})
		&"set_down_prize":
			_set_down(peer)
	_send()


## Host: put it down where the carrier stands (also on death or leaving).
func _set_down(peer: int) -> void:
	if carrier != peer:
		return
	var st: Dictionary = Game.players.get(peer, {})
	if st.has("pos"):
		_home.global_position = Vector3(st.pos.x, 0.0, st.pos.z)
	st.erase("held_prize")
	carrier = 0
	Log.event(&"pumpkin_set_down", {"player": peer, "pos": [snappedf(_home.global_position.x, 0.1), snappedf(_home.global_position.z, 0.1)]})
	_send()


# ---- host: guarding, gnaw, bites, judging ----

func _on_phase(ph: StringName) -> void:
	if ph == &"night":
		guard_s.clear()
		_night_closed = false
	elif ph == &"dawn":
		end_night()


func _physics_process(delta: float) -> void:
	if not Game.is_host() or not planted or Clock.phase != &"night" or _night_closed:
		return
	if Clock.day < rule(&"guard_first_night") or Clock.day > rule(&"guard_last_night"):
		return
	# ponytail: no lit-doorway query exists, so time in a doorway's light still counts; add when doors expose their light radius
	var here := _home.global_position
	for p in Game.players:
		var st: Dictionary = Game.players[p]
		if not Game.is_ghost(p) and st.has("pos") and Vector2(st.pos.x - here.x, st.pos.z - here.z).length() <= float(rule(&"guard_radius_m")):
			guard_s[p] = float(guard_s.get(p, 0.0)) + delta


## Longest single guard's seconds this night.
func guard_max() -> float:
	var m := 0.0
	for p in guard_s:
		m = maxf(m, float(guard_s[p]))
	return m


## Host, dawn (idempotent): did one living player guard 60 s this night (nights 1 to 6)?
func end_night() -> void:
	if _night_closed or not planted:
		_night_closed = true
		return
	_night_closed = true
	if Clock.day < rule(&"guard_first_night") or Clock.day > rule(&"guard_last_night"):
		return
	var ok := guard_max() >= float(rule(&"guard_s"))
	if ok:
		guarded_nights += 1
	Log.event(&"pumpkin_night", {"day": Clock.day, "guard_max_s": snappedf(guard_max(), 0.1), "guard_total_s": snappedf(_guard_total(), 0.1),
			"guarded": ok, "guarded_nights": guarded_nights})
	_send()


func _guard_total() -> float:
	var t := 0.0
	for p in guard_s:
		t += float(guard_s[p])
	return t


## Host: `pumpkin_gnaw` (P4-11) calls this. Drops one size from night `gnaw_from_night`. D-083: logs the time
## players spent guarding it this night so far. `repair_s` is 0 because a gnaw has no fix (doc 03 s10); the field
## stays so P4-10 log readers need no change if a repair is ever added.
func gnaw() -> bool:
	if not planted or judged or Clock.day < rule(&"gnaw_from_night") or _gnaw_day == Clock.day:
		return false
	_gnaw_day = Clock.day
	drops += 1
	Log.event(&"pumpkin_gnaw", {"day": Clock.day, "size": String(size_name()), "drops": drops,
			"guard_max_s": snappedf(guard_max(), 0.1), "guard_total_s": snappedf(_guard_total(), 0.1), "repair_s": 0.0})
	_send()
	return true


## Host: an escort bite (P4-12), at most `max_escort_bites` per escort.
func bite() -> bool:
	if not planted or judged or bites >= rule(&"max_escort_bites"):
		return false
	bites += 1
	drops += 1
	Log.event(&"pumpkin_bite", {"bites": bites, "size": String(size_name())})
	_send()
	return true


## Host, final dawn: size sets the payout (counts toward the final payment, doc 02 s6). Once only.
func judge(farm: Node) -> Dictionary:
	end_night()
	if judged:
		return {}
	judged = true
	if carrier != 0:
		_set_down(carrier)
	var rk := rank()
	var pay := payout_for(rk) if planted else 0
	Log.event(&"pumpkin_judged", {"size": String(size_name()), "watered_days": watered_days, "guarded_nights": guarded_nights,
			"drops": drops, "payout": pay, "players": Game.player_count()})
	if pay > 0:
		farm.add_coins(pay, &"pumpkin_payout", 0)
	_send()
	return {"size": size_name(), "payout": pay}


# ---- replication and look ----

func _send() -> void:
	if Game.is_host():
		farm._broadcast(&"prize", [planted, watered_days, guarded_nights, drops, carrier, watered, judged,
				_home.global_position.x, _home.global_position.z])


func snapshot_to(peer: int) -> void:
	Net.to_peers(&"apply_prize", [planted, watered_days, guarded_nights, drops, carrier, watered, judged,
			_home.global_position.x, _home.global_position.z], [peer])


func _on_apply(what: StringName, args: Array) -> void:
	if what == &"death" and Game.is_host() and carrier == int(args[0]):
		_set_down.call_deferred(carrier)
	elif what == &"prize":
		if not Game.is_host():
			planted = args[0]
			watered_days = args[1]
			guarded_nights = args[2]
			drops = args[3]
			carrier = args[4]
			watered = args[5]
			judged = args[6]
			if carrier == 0:
				_home.global_position = Vector3(args[7], 0.0, args[8])
			Log.event(&"pumpkin_seen", {"size": String(size_name()), "watered_days": watered_days, "drops": drops, "judged": judged})
		_refresh()


func _process(_d: float) -> void:
	if carrier != 0:
		_home.global_position = Vector3(target_pos().x, 0.0, target_pos().z)  # the marker rides with the carrier


func _refresh() -> void:
	if _mesh == null:
		return
	_mesh.visible = planted and not judged
	var d: float = DIAMETER_M[rank()]
	(_mesh.mesh as SphereMesh).radius = d / 2.0
	(_mesh.mesh as SphereMesh).height = d * 0.8
	_mesh.position.y = (d * 0.4) + (1.2 if carrier != 0 else 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.2, 0.1) if drops > 0 else Color(0.9, 0.5, 0.1)  # darker = gnawed (art: pumpkin_prize_gnawed)
	_mesh.material_override = m
