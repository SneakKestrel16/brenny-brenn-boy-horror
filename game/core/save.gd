class_name Save
extends RefCounted
## P4-10 (doc 05 s17, doc 01 "Saving"): the dawn save. Written on the host at dawn step 6, copied to every
## client (`Net.apply_dawn_save`, channel 3) so any farmhand of the season can host it. Never holds voice,
## clips or lobby data (doc 01 "Voice settings > Storage"). Layout:
##   <Net.user_dir()>/saves/<season_id>/dawn_<NN>.json  (last KEEP kept) and latest.json
##   {schema_version, game_build, season_id, saved_at, state}
## Loading: `Game.load_season(path)` puts the state in `pending`; Clock resumes at that dawn and
## `apply_pending` (host, end of Main._ready) pushes it into the live nodes.
##
## Hooks for state this file does not know (inference: only the owner knows its own fields):
##  - a node in group `saveable` with `save_key: String`, `save_state() -> Dictionary` (JSON-safe) and
##    `load_state(d: Dictionary)` is saved under `state.extras[save_key]` (P4-14 walkie batteries, AI Director
##    and sabotage cross-day state, P4-11 anything per-node).
##  - a `Game` property named in GAME_FLAGS is saved if it exists (P4-11 difficulty flags).

const SCHEMA := 1
const KEEP := 3  ## dawn files kept besides latest.json (doc 05 s17)
const CHUNK := 16384  ## bytes per `apply_dawn_save` packet
const MAX_BYTES := 4 * 1024 * 1024
const GAME_FLAGS: Array[String] = ["streamer_safe", "no_live_clips", "quirks_on"]  ## P4-11 puts these on Game; saved only if present

static var pending: Dictionary = {}  ## host: a loaded save's state, applied once Main has built the world
static var own_by_uid: Dictionary = {}  ## host: store `per_player` items by player uid (the store keys by peer id)
static var battery_by_uid: Dictionary = {}  ## host: walkie charge (seconds) by player uid, for farmhands not in the session now
static var tally_left: Dictionary = {}  ## host: awards tally by uid for farmhands not in the session yet (P4-15 hook)
static var peer_uid: Dictionary = {}  ## host: peer -> uid for everyone seen this match (Net.profiles drops a leaver before `player_left`)
static var _rx: Dictionary = {}  ## client: "season/name" -> {count, parts}


static func root() -> String:
	return Net.user_dir() + "saves/"  # per install (and per `--profile=` copy, so two local copies do not share files)


static func enabled() -> bool:
	return Game.match_started() or OS.get_cmdline_user_args().has("--save")


static func valid_season_id(s: String) -> bool:
	return not s.is_empty() and s.length() <= 64 and s.is_valid_filename() and not s.contains(".") and not s.contains(" ")


static func valid_name(n: String) -> bool:
	if n == "latest.json":
		return true
	var r := RegEx.new()
	r.compile("^dawn_\\d{2}\\.json$")
	return r.search(n) != null


# ---- build ----

## The state at dawn step 6 of `Clock.day`. Pure read; `final` marks the last dawn (the season is over).
static func build(tree: SceneTree, final: bool = false) -> Dictionary:
	var farm := tree.get_first_node_in_group(&"farm")
	var death := tree.get_first_node_in_group(&"death")
	var debt: Node = death.debt if death else null
	var plots := {}
	for id in farm.targets:
		var t: Node = farm.targets[id]
		if t.has_method(&"wire_state"):
			plots[id] = {"state": String(t.state), "crop": String(t.crop), "age": t.age, "watered": t.watered, "locked": t.locked}
	var store: Node = farm.store
	var own := own_by_uid.duplicate(true)
	for p in store.own:
		var uid := uid_of(p)  # a farmhand who left this match keeps their upgrades by uid
		if uid != "":
			own[uid] = _plain(store.own[p])
	var team := {}
	for k in store.team:
		team[String(k)] = int(store.team[k])
	var crows := []
	for i in store.scarecrows.size():
		var c: Vector3 = store.scarecrows[i]
		crows.append([c.x, c.y, c.z, store.scarecrow_yaws[i] if i < store.scarecrow_yaws.size() else 0.0])  # P5-23: 4th value = yaw; old saves have 3
	var s := {
		"day": Clock.day, "phase": "dawn", "over": final, "difficulty": String(Game.difficulty),
		"headcount": farm.headcount, "coins": farm.coins, "final_extra": farm.final_extra, "free_scrap": farm.free_scrap,
		"plots": plots,
		"store": {"team": team, "own": own, "scrap": store.scrap_bought, "flare": store.flare_shots, "crows": crows, "plots": store.plots.duplicate()},
		"roles": Game.roles.duplicate(), "quirks": Game.quirks.duplicate(), "uids": uids(), "season_no": Game.season_no, "traits": Game.traits.duplicate(),
		"extras": {}, "game": {},
	}
	var pz: Node = farm.targets.get("prize_pumpkin")
	if pz:
		s.prize = {"planted": pz.planted, "watered_days": pz.watered_days, "watered": pz.watered, "guarded_nights": pz.guarded_nights,
				"drops": pz.drops, "bites": pz.bites, "judged": pz.judged, "carrier": 0,
				"position": [pz._home.global_position.x, pz._home.global_position.z]}
	if debt:
		s.debt = {"pcts": Array(debt._pcts).duplicate(), "paid": debt.paid, "penalty": debt.penalty, "foreclosed": debt.foreclosed, "lost": debt.lost,
				"first_due": debt.first_due, "first_made": debt.first_made}
	var gen := tree.get_first_node_in_group(&"generator_logic")
	if gen:
		s.generator = {"damaged": gen.damaged}
	var cr := tree.get_first_node_in_group(&"creature")
	if cr:
		s.creature = {"body": String(cr.body)}
	var wk := _walkie()  # P4-14: who owns a walkie is `store.own` (above), the spare pool is `store.team.walkie_battery`; the charges are here
	if wk:
		var bat := battery_by_uid.duplicate()
		for p in wk.battery:  # the Walkie keeps a leaver's charge under their old peer id
			var u := uid_of(p)
			if u != "":
				bat[u] = snappedf(float(wk.battery[p]), 0.01)
		s.walkie = {"battery": bat}
	for n in tree.get_nodes_in_group(&"saveable"):
		s.extras[str(n.save_key)] = n.save_state()
	for k in GAME_FLAGS:
		if Game.get(k) != null:
			s.game[k] = Game.get(k)
	return s


static func uids() -> Array:
	var out: Array = Game.season_uids.duplicate()
	for u in Game.match_roster:
		if not u in out:
			out.append(u)
	for p in Net.profiles:
		var u := str(Net.profiles[p].get("uid", ""))
		if u != "" and not u in out:
			out.append(u)
	out.sort()
	return out


static func _plain(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out


# ---- files ----

static func envelope(state: Dictionary) -> Dictionary:
	return {"schema_version": SCHEMA, "game_build": Game.build_id(), "season_id": Game.season_id,
			"saved_at": Time.get_datetime_string_from_system(true), "state": state}


## Host: dawn step 6. Returns the dawn file name, "" when nothing was written.
static func write(tree: SceneTree, final: bool = false) -> String:
	var s := build(tree, final)
	return write_state(s, Game.season_id, true)


## Writes `state` as `dawn_<NN>.json` plus `latest.json`, keeps the last KEEP dawn files, logs `save_written`, and
## (host) sends it to every client.
static func write_state(state: Dictionary, season_id: String, send: bool) -> String:
	if not valid_season_id(season_id):
		return ""
	var bytes := JSON.stringify(envelope(state), "", true).to_utf8_buffer()
	var fname := "dawn_%02d.json" % int(state.day)
	if not store_bytes(season_id, fname, bytes):
		return ""
	Log.event(&"save_written", {"path_name": fname, "day": int(state.day), "bytes": bytes.size()})
	if send:
		send_to_clients(season_id, fname, bytes)
	return fname


## Atomic: temp file, then rename over the target. Also refreshes latest.json and prunes old dawn files.
static func store_bytes(season_id: String, fname: String, bytes: PackedByteArray) -> bool:
	if not valid_season_id(season_id) or not valid_name(fname) or bytes.size() > MAX_BYTES:
		return false
	var dir := root() + season_id + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	for n in [fname, "latest.json"]:
		var tmp: String = dir + n + ".tmp"
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		if f == null:
			push_error("Save: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
			return false
		f.store_buffer(bytes)
		f.close()
		var target: String = dir + n
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(tmp, target)
	var names := []
	for n in DirAccess.get_files_at(dir):
		if n.begins_with("dawn_") and n.ends_with(".json"):
			names.append(n)
	names.sort()
	while names.size() > KEEP:
		DirAccess.remove_absolute(dir + names.pop_front())
	return true


static func send_to_clients(season_id: String, fname: String, bytes: PackedByteArray) -> void:
	var count := maxi(ceili(bytes.size() / float(CHUNK)), 1)
	for i in count:
		Net.to_peers(&"apply_dawn_save", [season_id, fname, i, count, bytes.slice(i * CHUNK, (i + 1) * CHUNK)])


## Client: one chunk of the host's dawn save. Checks name, size and schema before anything is kept.
static func receive(season_id: String, fname: String, index: int, count: int, bytes: PackedByteArray) -> void:
	if Game.is_host() or not valid_season_id(season_id) or not valid_name(fname) or count < 1 or count > MAX_BYTES / CHUNK + 1 \
			or index < 0 or index >= count or bytes.size() > CHUNK:
		return
	var key := season_id + "/" + fname
	var rx: Dictionary = _rx.get(key, {})
	if rx.is_empty() or int(rx.count) != count:
		rx = {"count": count, "parts": {}}
	rx.parts[index] = bytes
	_rx[key] = rx
	if rx.parts.size() < count:
		return
	_rx.erase(key)
	var all := PackedByteArray()
	for i in count:
		all.append_array(rx.parts[i])
	var env := parse(all.get_string_from_utf8())
	if env.is_empty() or str(env.season_id) != season_id:
		return
	if store_bytes(season_id, fname, all):
		Log.event(&"save_received", {"path_name": fname, "day": int(env.state.get("day", 0)), "bytes": all.size()})


## The envelope, or {} (logged `save_refused`) when it is not JSON, is the wrong schema or lacks a state.
static func parse(text: String) -> Dictionary:
	var j := JSON.new()  # not parse_string: a bad file is an expected input, not an engine error
	var v: Variant = j.data if j.parse(text) == OK else null
	var why := ""
	if not v is Dictionary:
		why = "not_json"
	elif int(v.get("schema_version", -1)) != SCHEMA:
		why = "schema"
	elif not v.get("state") is Dictionary or not valid_season_id(str(v.get("season_id", ""))):
		why = "shape"
	if why != "":
		Log.event(&"save_refused", {"reason": why})
		return {}
	return v


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() > MAX_BYTES:
		Log.event(&"save_refused", {"reason": "missing"})
		return {}
	return parse(FileAccess.get_file_as_string(path))


## Menu: every season's latest.json, newest first: {path, season_id, day, saved_at, players, over}.
static func list() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(root()):
		return out
	for d in DirAccess.get_directories_at(root()):
		var path: String = root() + d + "/latest.json"
		if not FileAccess.file_exists(path):
			continue
		var env := read(path)
		if env.is_empty():
			continue
		var s: Dictionary = env.state
		out.append({"path": path, "season_id": str(env.season_id), "day": int(s.get("day", 0)), "saved_at": str(env.saved_at),
				"players": (s.get("uids", []) as Array).size(), "over": bool(s.get("over", false))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.saved_at > b.saved_at)
	return out


# ---- load ----

## Host, end of Main._ready: push the loaded state into the live nodes. Clock already resumed at the saved dawn.
static func apply_pending(main: Node) -> void:
	if not Game.is_host():
		return
	_track(main)
	if pending.is_empty():
		if not Game.carry.is_empty():  # P5-04: a new season of the campaign
			Campaign.apply_carry(main)
			if enabled():  # P5-24: a crash before the first dawn must not lose the carry
				var st := build(main.get_tree())
				st.season_start = true  # resumes at the start of this day, not its dawn (Game._start_clock)
				st.trait_report_pending = Game.trait_report_pending  # P5-28: only the season-start save owes the trait line
				write_state(st, Game.season_id, true)
		return
	var s := pending
	pending = {}
	var tree := main.get_tree()
	var farm: Node = main.get_node("Farm")
	var death: Node = main.get_node("Death")
	var debt: Node = death.debt
	farm.add_coins(int(s.get("coins", 0)) - farm.coins, &"load", 0)
	farm.final_extra = int(s.get("final_extra", 0))
	farm.free_scrap = int(s.get("free_scrap", 0))
	var plots: Dictionary = s.get("plots", {})
	for id in plots:
		var t: Node = farm.targets.get(id)
		if t == null:
			continue
		var d: Dictionary = plots[id]
		t.state = StringName(str(d.get("state", "empty")))
		t.crop = StringName(str(d.get("crop", "")))
		t.age = int(d.get("age", 0))
		t.watered = bool(d.get("watered", false))
		t.locked = bool(d.get("locked", false))
		t.taint_id = 0  # the Taint source on the ground is not saved (inference: it is cleaned or recreated; see handoff)
		t._refresh()
		farm.plot_changed(t)
	_apply_store(farm, s.get("store", {}), main)
	var pz: Node = farm.targets.get("prize_pumpkin")
	var p: Dictionary = s.get("prize", {})
	if pz and not p.is_empty():
		pz.planted = bool(p.planted)
		pz.watered_days = int(p.watered_days)
		pz.watered = bool(p.watered)
		pz.guarded_nights = int(p.guarded_nights)
		pz.drops = int(p.drops)
		pz.bites = int(p.bites)
		pz.judged = bool(p.judged)
		pz.carrier = 0
		pz._home.global_position = Vector3(float(p.position[0]), 0.0, float(p.position[1]))
		pz._send()
	var db: Dictionary = s.get("debt", {})
	if not db.is_empty():
		debt._pcts.clear()
		for x in db.pcts:
			debt._pcts.append(int(x))
		debt.paid = int(db.paid)
		debt.penalty = int(db.penalty)
		debt.foreclosed = bool(db.foreclosed)
		debt.lost = bool(db.lost)
		debt.first_due = int(db.first_due)
		debt.first_made = bool(db.first_made)
		debt._refresh_owed()
		debt._send()
	var g: Dictionary = s.get("generator", {})
	var gen := tree.get_first_node_in_group(&"generator_logic")
	if gen and bool(g.get("damaged", false)):
		gen.damaged = true
		gen._changed()
	var cr := tree.get_first_node_in_group(&"creature")
	var body := str(s.get("creature", {}).get("body", ""))
	if cr and body != "":  # P4-13: the season keeps its body; Creature._pick_body ran first, this overrides it
		cr.body = StringName(body)
		Log.event(&"creature_body", {"body": body, "forced": "save"})
		cr.state_changed.emit(cr.state, cr.body)
	battery_by_uid = s.get("walkie", {}).get("battery", {}).duplicate()
	_remap(farm.store)
	var ex: Dictionary = s.get("extras", {})
	for n in tree.get_nodes_in_group(&"saveable"):
		if ex.has(str(n.save_key)):
			n.load_state(ex[str(n.save_key)])
	for k in s.get("game", {}):
		if Game.get(k) != null:
			Game.set(k, s.game[k])
	Game.roles = s.get("roles", {}).duplicate()
	Game.quirks = s.get("quirks", {}).duplicate()
	Roles.sync()
	death.step_free_scrap(farm, false)  # the save was written before step 7; the dawn we resume finishes it
	Log.event(&"save_loaded", {"season_id": Game.season_id, "day": int(s.get("day", 0)), "coins": farm.coins, "debt_paid": debt.paid,
			"players": Game.players.keys()})


static func _apply_store(farm: Node, d: Dictionary, main: Node) -> void:
	var st: Node = farm.store
	st.team.clear()
	for k in d.get("team", {}):
		st.team[StringName(k)] = int(d.team[k])
	st.scrap_bought = int(d.get("scrap", 0))
	st.flare_shots = int(d.get("flare", 0))
	st.scarecrows.clear()
	st.scarecrow_yaws.clear()
	for c in d.get("crows", []):
		st.scarecrows.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
		st.scarecrow_yaws.append(float(c[3]) if c.size() > 3 else 0.0)
	st.plots.assign(d.get("plots", []))
	own_by_uid = d.get("own", {}).duplicate(true)
	var cr := main.get_tree().get_first_node_in_group(&"creature")
	if cr and int(st.team.get(&"shed_lock", 0)) > 0:
		cr.shed_lock = true
	st._send()


## P4-15 hook: the season awards tally ({category: {peer: n}}, season_awards_logic.gd `empty_tally`) as
## {category: {uid: n}}. SeasonAwards joins group `saveable` and returns this from `save_state()`.
static func tally_state(t: Dictionary) -> Dictionary:
	var out := tally_left.duplicate(true)  # farmhands who have not rejoined keep their counts
	for cat in t:
		if not out.has(cat):
			out[cat] = {}
		for p in t[cat]:
			var u := str(Net.profiles.get(p, {}).get("uid", ""))
			if u != "":
				out[cat][u] = int(t[cat][p])
	return out


## P4-15 hook: `load_state(d)` calls this to fold a saved tally into the live one. A farmhand not in the session yet
## is merged when they join (their peer id is new each time).
static func tally_load(t: Dictionary, d: Dictionary) -> void:
	tally_left = d.duplicate(true)
	var fold := func() -> void:
		for p in Net.profiles:
			var u := str(Net.profiles[p].get("uid", ""))
			for cat in tally_left:
				if t.has(cat) and tally_left[cat].has(u):
					t[cat][p] = int(t[cat].get(p, 0)) + int(tally_left[cat][u])
					tally_left[cat].erase(u)
	fold.call()
	Game.player_joined.connect(func(_p: int) -> void: fold.call())


## The Walkie node (P4-14, child of Voice); absent where the build has none.
static func _walkie() -> Node:
	return Voice.get_node_or_null("Walkie")


## Host: a peer's player uid, also after they left this match.
static func uid_of(p: int) -> String:
	var u := str(Net.profiles.get(p, {}).get("uid", ""))
	return u if u != "" else str(peer_uid.get(p, ""))


## Host, every Main: note who is here, and on each join hand a returning farmhand their upgrades and walkie charge.
static func _track(main: Node) -> void:
	peer_uid.clear()
	for p in Net.profiles:
		peer_uid[p] = str(Net.profiles[p].get("uid", ""))
	var st: Node = main.get_node("Farm").store
	var cb := func(p: int) -> void:
		peer_uid[p] = str(Net.profiles.get(p, {}).get("uid", ""))
		_remap(st)
	Game.player_joined.connect(cb)
	main.tree_exiting.connect(func() -> void: Game.player_joined.disconnect(cb))


## Host: per-player upgrades and walkie charge follow the player's uid. A farmhand who left and came back (a new peer id)
## gets them from their old peer id this match, or from the loaded save.
static func _remap(st: Node) -> void:
	var wk := _walkie()
	for p in Game.players:
		var u := uid_of(p)
		if u == "":
			continue
		var old := -1  # this farmhand's peer id before they left
		for q in peer_uid:
			if q != p and peer_uid[q] == u and not Game.players.has(q):
				old = q
		if not st.own.has(p):
			if st.own.has(old):
				st.own[p] = st.own[old]
				st.own.erase(old)
				st._send()
			elif own_by_uid.has(u):
				var m := {}
				for k in own_by_uid[u]:
					m[StringName(k)] = true
				st.own[p] = m
				st._send()
		if wk and not wk.battery.has(p):
			if wk.battery.has(old):
				wk.battery[p] = wk.battery[old]
				wk.battery.erase(old)
			elif battery_by_uid.has(u):
				wk.battery[p] = float(battery_by_uid[u])
			wk._sent.erase(p)  # the Walkie resends this peer's state on its next sync
