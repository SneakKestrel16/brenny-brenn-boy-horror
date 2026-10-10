extends Node
## P4-06 (doc 02 s10, doc 05 s9): the shipping crate's store. Host-authoritative: a client sends
## `request_store(op, arg)` (`buy`, `flare`, `scarecrow`, `seeds` with arg `<crop>:<n>`), the host validates, mutates, logs and broadcasts
## the whole small state with `apply_store`. Every row is a `store.json` record; its `effect` holds the numbers. Seeds
## are not rows: the crate's menu (P4-22, game/ui/store_menu.gd) buys them into the team's stock, `team["seed_<crop>"]`
## (saved and sent with the rest of `team`), and planting uses one (plot.gd; D-093, which supersedes D-090).

const Crops := preload("res://game/farming/crops.gd")
const SEED_BUY_MAX := 10  ## the most seeds one request may buy (the menu offers 1 and 5)
const REACH_M := 3.5  ## how close to the crate a buy must be (placeholder)
const SPACING_M := 3.0  ## two placed scarecrows closer than this are one (placeholder)

var farm: Node
var team: Dictionary = {}  ## item id -> count bought for the whole team
var own: Dictionary = {}  ## peer -> {item id: true} for `per_player` rows
var scrap_bought := 0  ## paid scrap in stock; the free scrap is `farm.free_scrap`
var scarecrows: Array[Vector3] = []  ## placed bought scarecrows
var flare_shots := 0  ## shots left in the flare gun
var plots: Array[String] = []  ## field plots a `plot_pair` opened
var pick := 0  ## this machine's crate pick (`cycle_item`), an index into the table
var _flare_ready_ms := 0
var _crows: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"store")
	Net.request_received.connect(_on_request)
	Net.apply_received.connect(_on_apply)


# --- rules (host) ---------------------------------------------------------------------------------

func rec(id: StringName) -> Dictionary:
	for r in items():  # a client can send any id: no push_error for a bad one
		if StringName(r.id) == id:
			return r
	return {}


func items() -> Array[Dictionary]:
	return Data.records(&"store")


func owns(peer: int, id: StringName) -> bool:
	return own.get(peer, {}).has(id) or (not bool(rec(id).get("per_player", false)) and int(team.get(id, 0)) > 0)


func lantern_mult(peer: int) -> float:  ## the player lantern's light radius multiplier (nothing draws that lantern yet)
	return float(rec(&"brighter_lantern").effect.light_radius_mult) if owns(peer, &"brighter_lantern") else 1.0


## What `peer` pays for `id`: a Carpenter builds scarecrows at `build_cost_mult` (P4-09, doc 02 s15, rounded up).
func price(peer: int, id: StringName) -> int:
	var p := int(rec(id).get("price", 0))
	return Roles.build_cost(p, Roles.of(peer)) if id == &"scarecrow" else p


## Shots a full flare gun holds: one more while a Warden is on the team (P4-09, doc 02 s15). Inference: the gun is
## the team's, so the Warden's extra shot loads it for everyone; doc 01 only says "more flare shots".
func flare_capacity() -> int:
	var n := int(rec(&"flare_gun").effect.shots)
	for p in Game.players:
		if Roles.of(p) == &"warden":
			return n + int(Roles.perks(&"warden").flare_shots_extra)
	return n


func scrap_total() -> int:
	return farm.free_scrap + scrap_bought


## Host: one repair's scrap, the free one first (doc 01 Nights). False when there is none.
func take_scrap() -> bool:
	if farm.free_scrap > 0:
		farm.free_scrap -= 1
	elif scrap_bought > 0:
		scrap_bought -= 1
	else:
		return false
	Log.event(&"scrap_used", {"left": scrap_total()})
	_send()
	return true


## Host, dawn step 7 (doc 01 Store): the flare gun is loaded again. `flare_reloaded` feeds the Dawn Report line (D-147).
func refill_flare() -> void:
	if int(team.get(&"flare_gun", 0)) > 0:
		var before := flare_shots
		flare_shots = flare_capacity()
		if flare_shots > before:
			Log.event(&"flare_reloaded", {"before": before, "shots": flare_shots})
		_send()


func open_plots() -> int:
	var n := 0
	for t in farm.targets.values():
		if t.has_method(&"wire_state") and not t.locked and not t.bed:
			n += 1
	return n


## Host: why `peer` cannot buy `id` now, else empty. `near` false skips the crate distance (dev console).
func why_not(peer: int, id: StringName, near: bool = true) -> StringName:
	var r := rec(id)
	if r.is_empty():
		return &"no_item"
	if Game.is_ghost(peer):
		return &"ghost"
	if near and _too_far(peer):  # P4-22: with `near` false a client may ask too (the store menu greys rows)
		return &"too_far"
	if Clock.day < int(r.unlock_day):
		return &"locked_item"
	if id == &"flare_shell":  # D-147: a shell needs the gun and room in it
		if int(team.get(&"flare_gun", 0)) < 1:
			return &"no_flare"
		if flare_shots >= flare_capacity():
			return &"flare_full"
	if farm.coins < price(peer, id):
		return &"no_coins"
	var e: Dictionary = r.get("effect", {})
	if bool(r.per_player):
		if bool(r.upgrade) and owns(peer, id):
			return &"owned"
	elif bool(r.upgrade) and not e.has("max_bought") and id != &"plot_pair" and int(team.get(id, 0)) > 0:
		return &"owned"
	if e.has("max_bought") and int(team.get(id, 0)) >= int(e.max_bought):
		return &"max_bought"
	if id == &"plot_pair" and (_locked_plots().size() < int(e.plots) or open_plots() + int(e.plots) > farm.plot_ceiling()):
		return &"plots_max"  # doc 02 s4 ceilings
	return &""


func buy(peer: int, id: StringName, near: bool = true) -> StringName:
	var why := why_not(peer, id, near)
	if why != &"":
		Log.event(&"store_refused", {"item": String(id), "buyer": peer, "reason": String(why)})
		return why
	var r := rec(id)
	var e: Dictionary = r.get("effect", {})
	var paid := price(peer, id)
	farm.add_coins(-paid, &"store", peer)
	if bool(r.per_player):
		var mine: Dictionary = own.get(peer, {})
		mine[id] = true
		own[peer] = mine
	team[id] = int(team.get(id, 0)) + 1
	match id:
		&"scrap": scrap_bought += int(e.repairs)
		&"shed_lock":
			var cr := get_tree().get_first_node_in_group(&"creature")
			if cr:
				cr.shed_lock = true
		&"walkie_talkie": team[&"walkie_battery"] = int(team.get(&"walkie_battery", 0)) + int(e.batteries_included)  # P4-14 builds the radio
		&"flare_gun": flare_shots = flare_capacity()
		&"flare_shell": flare_shots = mini(flare_shots + int(e.shots), flare_capacity())
		&"plot_pair":
			for p in _locked_plots().slice(0, int(e.plots)):
				plots.append(p.id)
				p.locked = false
				p._refresh()
				farm.plot_changed(p)
	Log.event(&"store_buy", {"item": String(id), "price": paid, "buyer": peer, "day": Clock.day, "coins": farm.coins, "flare": flare_shots})
	_send()
	return &""


## Host: is `peer` out of reach of the crate? `pstate` is host-only.
func _too_far(peer: int) -> bool:
	var st: Dictionary = farm.pstate(peer)
	var crate := get_tree().get_first_node_in_group(&"store_crate") as Node3D
	return crate == null or not st.has("pos") or Vector2(st.pos.x - crate.global_position.x, st.pos.z - crate.global_position.z).length() > REACH_M


# --- seeds (P4-22, D-093) ---------------------------------------------------------------------------

static func seed_key(crop: StringName) -> StringName:
	return StringName("seed_" + crop)


## The team's seeds of `crop` in stock (every peer: `team` is replicated).
func seed_count(crop: StringName) -> int:
	return int(team.get(seed_key(crop), 0))


## Why the team cannot buy `n` seeds of `crop` now, else empty. `near` false skips the crate (client menu, bots).
func seed_why_not(peer: int, crop: StringName, n: int, near: bool = true) -> StringName:
	if not crop in Crops.ids() or n < 1 or n > SEED_BUY_MAX:  # a client can send anything
		return &"no_item"
	if Game.is_ghost(peer):
		return &"ghost"
	if near and _too_far(peer):
		return &"too_far"
	if not Crops.is_unlocked(crop, Clock.day):
		return &"locked_crop"
	return &"" if farm.coins >= int(Crops.rec(crop).seed) * n else &"no_coins"


## Host: buy `n` seeds of `crop` into the team's stock (doc 02 s10 seed prices).
func buy_seeds(peer: int, crop: StringName, n: int, near: bool = true) -> StringName:
	var why := seed_why_not(peer, crop, n, near)
	if why != &"":
		Log.event(&"store_refused", {"item": String(seed_key(crop)), "buyer": peer, "reason": String(why)})
		return why
	var paid := int(Crops.rec(crop).seed) * n
	farm.add_coins(-paid, &"seed", peer)
	team[seed_key(crop)] = seed_count(crop) + n
	Log.event(&"store_buy", {"item": String(seed_key(crop)), "count": n, "price": paid, "buyer": peer, "day": Clock.day, "coins": farm.coins})
	_send()
	return &""


## Host: one seed of `crop` goes into the ground (plot.gd `complete`).
func use_seed(crop: StringName) -> void:
	team[seed_key(crop)] = maxi(seed_count(crop) - 1, 0)
	_send()


func _locked_plots() -> Array:
	var out := []
	for t in farm.targets.values():
		if t.has_method(&"wire_state") and t.locked:
			out.append(t)
	return out


## Host: the flare gun goes off (doc 01 Store). Loud (`noise_flare`); a creature within that radius goes to Retreat
## for `retreat_s` (inference: the shot must be seen or heard to scare it).
func fire_flare(peer: int) -> StringName:
	var e: Dictionary = rec(&"flare_gun").get("effect", {})
	var st: Dictionary = farm.pstate(peer)
	if Game.is_ghost(peer) or not st.has("pos"):
		return &"ghost"
	if int(team.get(&"flare_gun", 0)) < 1:
		return &"no_flare"
	if flare_shots < 1:
		return &"flare_empty"
	if Time.get_ticks_msec() < _flare_ready_ms:
		return &"flare_reloading"
	flare_shots -= 1
	var reload := ceilf(float(e.reload_s) * (float(Roles.perks(&"warden").flare_reload_mult) if Roles.of(peer) == &"warden" else 1.0) - 0.0001)
	_flare_ready_ms = Time.get_ticks_msec() + int(reload * 1000.0)  # P4-09: the Warden reloads faster
	NoiseBus.emit_kind(&"flare", st.pos, peer)
	var cr := get_tree().get_first_node_in_group(&"creature")
	var hit: bool = cr != null and cr.global_position.distance_to(st.pos) <= float(Data.value(&"creature", &"noise_flare", &"radius_m")) and cr.flare_hit(float(e.retreat_s))
	Log.event(&"flare_fired", {"player": peer, "hit": hit, "left": flare_shots})
	_send()
	return &""


func place_scarecrow(peer: int) -> StringName:
	var st: Dictionary = farm.pstate(peer)
	if Game.is_ghost(peer) or not st.has("pos"):
		return &"ghost"
	if int(team.get(&"scarecrow", 0)) <= scarecrows.size():
		return &"no_scarecrow"
	var at := Vector3(st.pos.x, 0.0, st.pos.z)
	for s in scarecrows:
		if s.distance_to(at) < SPACING_M:
			return &"too_close"
	scarecrows.append(at)
	Log.event(&"scarecrow_placed", {"player": peer, "position": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)], "avoid_m": float(rec(&"scarecrow").effect.creature_avoid_m)})
	_send()
	return &""


## What Foreclosure may seize (doc 02 s10 "Upgrades"): every bought item except seeds and scrap. P4-07 calls it.
func seizable() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in items():
		if bool(r.upgrade) and (int(team.get(StringName(r.id), 0)) > 0):
			out.append(StringName(r.id))
	return out


## Host: take an upgrade away (P4-07). A plot pair clears and relocks its two plots; a scarecrow takes the last one placed.
func seize(id: StringName) -> void:
	if int(team.get(id, 0)) < 1:
		return
	team[id] = int(team[id]) - 1
	if bool(rec(id).get("per_player", false)):  # one upgrade seized = one owner's copy; the highest peer id loses it (placeholder)
		var owners: Array = own.keys().filter(func(p: int) -> bool: return own[p].has(id))
		if not owners.is_empty():
			own[owners.max()].erase(id)
	match id:
		&"plot_pair":
			for pid in plots.slice(-2):
				plots.erase(pid)
				var p: Node = farm.targets[pid]
				p._reset()  # D-086: a seized plot loses its crop
				p.locked = true
				p._refresh()
				farm.plot_changed(p)
		&"scarecrow":
			if scarecrows.size() > team[id]:
				scarecrows.pop_back()
		&"flare_gun": flare_shots = 0
		&"shed_lock":
			var cr := get_tree().get_first_node_in_group(&"creature")
			if cr:
				cr.shed_lock = false
	Log.event(&"store_seized", {"item": String(id)})
	_send()


# --- wire -------------------------------------------------------------------------------------------

func _state() -> Dictionary:
	return {"team": team, "own": own, "scrap": scrap_bought, "free": farm.free_scrap, "crows": scarecrows, "flare": flare_shots, "plots": plots}


func _send(peer: int = 0) -> void:
	var s := _state()
	Net.to_peers(&"apply_store", [s], [peer] if peer > 0 else [])
	if peer == 0:
		_on_apply(&"store", [s])


func _on_request(what: StringName, peer: int, args: Array) -> void:
	if not Game.is_host():
		return
	var why := &""
	match what:
		&"farm_state": _send(peer)
		&"store":
			match args[0]:
				&"buy": why = buy(peer, args[1])
				&"flare": why = fire_flare(peer)
				&"scarecrow": why = place_scarecrow(peer)
				&"seeds": why = buy_seeds(peer, StringName(String(args[1]).get_slice(":", 0)), String(args[1]).get_slice(":", 1).to_int())  # `<crop>:<n>` (the RPC has one arg)
			if why != &"":
				if peer == Game.local_peer():
					Net.apply_received.emit(&"refused", [args[0], why])
				else:
					Net.to_peers(&"apply_refused", [args[0], why], [peer])


func _on_apply(what: StringName, args: Array) -> void:
	if what != &"store":
		return
	var s: Dictionary = args[0]
	if not Game.is_host():
		team = s.team
		own = s.own
		scrap_bought = s.scrap
		farm.free_scrap = s.free
		flare_shots = s.flare
		scarecrows.assign(s.crows)
		plots.assign(s.plots)
		for pid in plots:
			if farm.targets.has(pid) and farm.targets[pid].locked:
				farm.targets[pid].locked = false
				farm.targets[pid]._refresh()
	_show_scarecrows()


## Placeholder look: a post with a sack head, until the Technical Artist's scarecrow (the creature avoids it on the host).
func _show_scarecrows() -> void:
	while _crows.size() > scarecrows.size():
		_crows.pop_back().queue_free()
	while _crows.size() < scarecrows.size():
		var n := Node3D.new()
		var post := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.06
		m.bottom_radius = 0.06
		m.height = 2.0
		post.mesh = m
		post.position.y = 1.0
		n.add_child(post)
		n.add_to_group(&"bought_scarecrow")
		get_parent().add_child(n)
		_crows.append(n)
	for i in _crows.size():
		_crows[i].global_position = scarecrows[i]


# --- client input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Game.console_open or not event.is_pressed() or event is InputEventMouse:
		return
	var n := items().size()
	if event.is_action_pressed(&"cycle_item") and n > 0:
		pick = (pick + 1) % n
		var r := items()[pick]
		Log.event(&"store_picked", {"item": String(r.id), "price": int(r.price)})
	elif event.is_action_pressed(&"buy_item") and n > 0:
		Net.to_host(&"request_store", [&"buy", StringName(items()[pick].id)])
	elif event.is_action_pressed(&"fire_flare"):
		Net.to_host(&"request_store", [&"flare", &""])
	elif event.is_action_pressed(&"place_scarecrow"):
		Net.to_host(&"request_store", [&"scarecrow", &""])


## Text for the tester prompt when the local player, standing `at`, is at the crate (no marker: it shows only up
## close). `at` is the local body's position: a client has no `Game.players[me].pos` (only the host sets it).
func prompt_text(at: Vector3) -> String:
	var crate := get_tree().get_first_node_in_group(&"store_crate") as Node3D
	if crate == null or Vector2(at.x - crate.global_position.x, at.z - crate.global_position.z).length() > REACH_M:
		return ""
	return "%s: open the store (seeds and tools)" % _key(&"interact")  # P4-22: the list is store_menu.gd


func _key(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode)
	return "?"
