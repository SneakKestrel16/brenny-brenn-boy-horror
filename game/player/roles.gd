class_name Roles
extends RefCounted
## P4-09 (doc 01 "Roles", D-077): the ten roles. Numbers are in `data/roles.json`; nothing here is a number.
## The host keeps `Game.roles` (player uid -> role id) so a reconnecting player keeps theirs (doc 01 "Rejoining");
## `Game.players[peer].role` is the replicated view that holds, noise and the animals read. The pure helpers
## take plain values so tests/gameplay/test_roles.gd runs them with no scene.

## Hold verb -> the roles.json perk that scales it. `pry` is not here: only prying someone else counts.
const HOLD_PERK := {&"repair_generator": [&"mechanic", &"repair_hold_mult"], &"refuel": [&"mechanic", &"refuel_hold_mult"],
		&"disarm_bear": [&"tracker", &"disarm_hold_mult"], &"place_scarecrow": [&"carpenter", &"build_hold_mult"],
		&"repair_fence": [&"carpenter", &"fence_repair_hold_mult"], &"round_up": [&"rancher", &"round_up_hold_mult"]}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in Data.records(&"roles"):
		out.append(StringName(r.id))
	return out


static func perks(role: StringName) -> Dictionary:
	return Data.record(&"roles", role).get("perks", {}) if role != &"" else {}


static func of(peer: int) -> StringName:
	return StringName(String(Game.players.get(peer, {}).get("role", "")))


## The hold-time multiplier for `verb`; 1.0 without the matching role. `night_crop`: the harvest is a moonflower.
static func hold_mult(verb: StringName, role: StringName, night_crop: bool = false) -> float:
	if verb == &"harvest" and night_crop and role == &"night_owl":
		return float(perks(role).moonflower_harvest_hold_mult)
	var h: Array = HOLD_PERK.get(verb, [])
	if h.is_empty() or h[0] != role:
		return 1.0
	return float(perks(role)[h[1]])


## Night Owl: steps and tool noise at night (doc 01 Roles). Voice and the whistle are not scaled.
static func noise_mult(role: StringName, kind: StringName, night: bool) -> float:
	if role != &"night_owl" or not night or not (kind.begins_with("step_") or kind.begins_with("tool_")):
		return 1.0
	return float(perks(role).noise_mult)


## Farmer: true on every `bonus_crop_every_n_harvests`-th harvest of this player. Counts in `st.harvests`.
static func harvest_bonus(st: Dictionary) -> bool:
	if StringName(String(st.get("role", ""))) != &"farmer":
		return false
	st.harvests = int(st.get("harvests", 0)) + 1
	return int(st.harvests) % int(perks(&"farmer").bonus_crop_every_n_harvests) == 0


## Medic: the medical bill after `medic_deaths` of `deaths` happened near a medic; those deaths' share is cut (ceil).
## Inference: doc 01 says "cuts the bill for deaths they were near"; per-death share of the bill settles it.
static func cut_bill(bill: int, deaths: int, medic_deaths: int) -> int:
	if deaths <= 0 or medic_deaths <= 0:
		return bill
	var share := float(mini(medic_deaths, deaths)) / float(deaths)
	return ceili(bill * (1.0 - share * (1.0 - float(perks(&"medic").bill_cut_mult))) - 0.0001)


## Host: is a living Medic (not `except`) within `bill_cut_radius_m` of `pos`?
static func medic_near(pos: Vector3, except: int) -> bool:
	var r := float(perks(&"medic").bill_cut_radius_m)
	for p in Game.players:
		if p != except and of(p) == &"medic" and not Game.is_ghost(p):
			var q: Vector3 = Game.players[p].get("pos", Vector3(1e9, 0, 1e9))
			if Vector2(q.x - pos.x, q.z - pos.z).length() <= r:
				return true
	return false


## Carpenter: a build's coin cost. ponytail: no buyer calls this until the store (P4-06) sells scarecrows and fences.
static func build_cost(base: int, role: StringName) -> int:
	return ceili(base * (float(perks(role).build_cost_mult) if role == &"carpenter" else 1.0) - 0.0001)


## Why `uid` may not take `role` now, empty if it may. `taken`: uid -> role of everyone else who holds one.
static func refusal(role: StringName, uid: String, taken: Dictionary) -> StringName:
	if role == &"":
		return &""
	if not role in ids():
		return &"unknown_role"
	for u in taken:
		if u != uid and StringName(taken[u]) == role:
			return &"role_taken"
	return &""


# --- Host side: pick, lock, replicate -----------------------------------------------------------

static var _locked := false  ## the last `apply_roles` said a loaded season keeps its roles


## A loaded season keeps its roles (`on_request` refuses every pick). True on the host and, via `sync`, on clients.
static func locked() -> bool:
	return not Game.season_uids.is_empty() if Game.is_host() else _locked

static func _uid(peer: int) -> String:
	return str(Net.profiles.get(peer, {}).get("uid", ""))


## Roles held by other players: in the barn only those present, in a match everyone on the roster (a dropped player keeps theirs).
static func _taken(except_uid: String) -> Dictionary:
	var out := {}
	var here := {}
	for p in Game.players:
		here[_uid(p)] = true
	for u in Game.roles:
		if u != except_uid and (not Game.in_lobby or here.has(u)):
			out[u] = Game.roles[u]
	return out


## Host, from `Net.request_role`. `role` "" means no role. Locked once the match starts (doc 01 "Picking a role").
static func on_request(peer: int, role: StringName) -> void:
	if not Game.is_host() or not Game.players.has(peer):
		return
	var uid := _uid(peer)
	var why: StringName = &"" if Game.in_lobby and Game.season_uids.is_empty() else &"locked"  # a loaded season keeps its roles
	if why == &"" and uid == "":
		why = &"no_identity"
	if why == &"":
		why = refusal(role, uid, _taken(uid))
	if why != &"":
		Log.event(&"hold_refused", {"verb": "pick_role", "reason": String(why), "peer": peer})
		sync()  # the picker's card snaps back
		return
	if role == &"":
		Game.roles.erase(uid)
	else:
		Game.roles[uid] = role
	Log.event(&"role_picked", {"player": peer, "role": String(role)})
	sync()


## Host: copy `Game.roles` onto the live players and send the table to everyone. Call after anything that
## rebuilds `Game.players[peer]` (match start, rejoin).
static func sync() -> void:
	if not Game.is_host():
		return
	var table := {"locked": not Game.season_uids.is_empty()}  # P4-35: clients grey the cards of a loaded season too
	for p in Game.players:
		table[p] = String(Game.roles.get(_uid(p), ""))
	apply(table)
	Net.to_peers(&"apply_roles", [table])


static func apply(table: Dictionary) -> void:
	_locked = bool(table.get("locked", false))
	for p in table:
		if p is int and Game.players.has(p):
			Game.players[int(p)].role = StringName(String(table[p]))
	Game.roles_changed.emit()
