class_name Imposter
extends RefCounted
## P5-11, doc 01 "Imposter mode", doc 02 s22, data/imposter.json. Static state, like `Roles`.
##
## The secret: only the host knows `uid` (who). The one imposter's own client learns `me` through a message
## sent to that peer alone (`Net.apply_imposter_secret`); nobody else is ever told "no" or "who". The uid is
## never saved (the dawn save goes to every client, Save.send_to_clients), never broadcast, never in a
## client log. A rejoiner is matched by profile uid at admit (`sync_to`), so the status survives a drop.
## The toggle (`enabled`) is public: it is a lobby setting (default off, D-158) and every peer sees it.
## Wins ONLY when the final payment is missed (D-155): `Debt.lost`, not a first-payment Foreclosure Notice
## and not a Harvest Moon wipe. Needs `min_players` humans (D-161): the lobby box is disabled below that and
## `pick` ignores the toggle below it. The imposter never kills and keeps role and perks (imposter.json).

const KINDS: Array[StringName] = [&"whistle_throw", &"gate_prop"]  ## kit pieces built (pegboard_mark, door_prop cut: Q-303)

static var enabled := false  ## every peer: the lobby toggle
static var me := false  ## the imposter's own client only: "I am the imposter"
static var uid := ""  ## HOST ONLY: the imposter's profile uid, "" for none
static var picked_name := ""  ## HOST ONLY: their display name at pick time (they may have left by season end)
static var picked := false  ## HOST ONLY: a roll happened this season
static var forced := ""  ## HOST ONLY, dev setting (D-044): "" none, "none" no imposter, else a profile uid
static var _used: Dictionary = {}  ## HOST ONLY: "kind|day|night" -> count
static var _last_ms: Dictionary = {}  ## HOST ONLY: kind -> msec of last use


static func rule() -> Dictionary:
	return Data.record(&"imposter", &"rule")


static func min_players() -> int:
	return int(rule().get("min_players", 4))


## Pure: does a match with `humans` players, the toggle `on`, and a roll `r` in [0,1) get an imposter? (doc 01: 50%)
static func rolls(on: bool, humans: int, r: float, chance_pct: float, min_n: int) -> bool:
	return on and humans >= min_n and r * 100.0 < chance_pct


## Pure: the season-end sentence. `who` "" means nobody was picked. `won`: the final payment was missed.
static func line(who: String, won: bool) -> String:
	if who == "":
		return "There was no imposter."
	return "THE IMPOSTER WAS %s. The imposter %s." % [who, "won" if won else "lost"]


static func reset() -> void:
	enabled = false
	me = false
	uid = ""
	picked_name = ""
	picked = false
	forced = ""
	_used.clear()
	_last_ms.clear()


# --- lobby toggle --------------------------------------------------------------------------------

## Host, lobby only: the toggle. Every client gets it (a late joiner at admit).
static func set_enabled(on: bool) -> void:
	if not Game.is_host() or not Game.in_lobby:
		return
	enabled = on
	Net.to_peers(&"apply_imposter_toggle", [on])
	Log.event(&"group_settings_imposter", {"enabled": on})


# --- pick (host) ---------------------------------------------------------------------------------

## Host: roll the season's imposter after roles are locked (`Game.start_match`, and P5-04 at each next
## season). Re-rolls each season (imposter.json `rerolled_each_season`).
static func pick() -> void:
	if not Game.is_host():
		return
	var who := ""
	var humans: Array = []
	for p in Game.players:
		if p > 0 and Net.profiles.has(p):
			humans.append(p)
	if forced == "none":
		who = ""
	elif forced != "":  # dev setting: forced even below the minimum (Q-304)
		who = forced
	elif rolls(enabled, humans.size(), randf(), float(rule().get("chance_pct", 50)), min_players()):
		who = str(Net.profiles[humans[randi() % humans.size()]].uid)
	uid = who
	picked = true
	me = false
	if Game.is_host() and Net.has_method("to_peers"):
		Net.to_peers(&"apply_imposter_toggle", [enabled])  # clears a previous imposter's `me` everywhere
	_used.clear()
	_last_ms.clear()
	picked_name = ""
	if who != "":
		for p in humans:
			if Net.profiles[p].uid == who:
				picked_name = str(Net.profiles[p].name)
		Log.event(&"imposter_picked", {"season": Game.season_id, "roster_id": who, "forced": forced != ""})  # host log only
		_tell(who)


## Host: send the secret to the peer whose profile uid is `who`, and to nobody else.
static func _tell(who: String) -> void:
	for p in Net.profiles:
		if Net.profiles[p].get("uid") == who and Game.players.has(p):
			if p == 1:
				me = true
			else:
				Net.to_peers(&"apply_imposter_secret", [], [p])


## Host: `id` just joined or rejoined. It gets the toggle, and the secret only if it is the imposter.
static func sync_to(id: int) -> void:
	Net.to_peers(&"apply_imposter_toggle", [enabled], [id])
	if uid != "" and Net.profiles.get(id, {}).get("uid") == uid:
		_tell(uid)


static func peer() -> int:
	for p in Net.profiles:
		if uid != "" and Net.profiles[p].get("uid") == uid and Game.players.has(p):
			return p
	return 0


## Host: the final payment was missed and an imposter was in play (D-155).
static func won() -> bool:
	if uid == "":
		return false
	var debt := (Engine.get_main_loop() as SceneTree).get_first_node_in_group(&"debt")
	return debt != null and debt.lost


## Host: the season-end line, "" when the toggle was off and nobody was forced (nothing to reveal).
static func reveal_line() -> String:
	if not picked or (not enabled and forced == ""):
		return ""
	return line(picked_name, won())


# --- kit (host validates, imposter's client only asks) ---------------------------------------------

## Host: the imposter asks for kit piece `kind` at `at` (world position; ignored by gate_prop). Anyone else, and
## every refusal, is dropped without an answer, so a probe learns nothing.
static func act(sender: int, kind: StringName, at: Vector3) -> void:
	if uid == "" or sender != peer() or Game.is_ghost(sender) or not kind in KINDS or not Game.players[sender].has("pos"):
		return
	var rec := Data.record(&"imposter", kind)
	var night: bool = Clock.phase in [&"night", &"harvest_moon"]
	var per_night: bool = night and rec.has("max_per_night")  # no max_per_night: one count per day (doc 02 s22.4)
	var key := "%s|%d|%s" % [kind, Clock.day, per_night]
	var cap := int(rec.get("max_per_night" if per_night else "max_per_day", 99))
	if int(_used.get(key, 0)) >= cap:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(kind, -1000000)) < int(float(rec.get("cooldown_s", 0)) * 1000.0):
		return
	var here: Vector3 = Game.players[sender].pos
	var tree := Engine.get_main_loop() as SceneTree
	match kind:
		&"whistle_throw":
			var d := Vector3(at.x - here.x, 0.0, at.z - here.z)
			var r := float(rec.range_m)
			if d.length() > r:
				d = d.normalized() * r
			var pt := here + d
			NoiseBus.emit_kind(&"whistle", pt, sender)  # the creature hears noise_whistle there (creature.json)
			Net.to_peers(&"apply_whistle", [0, pt])  # peer 0: no body animates, the sound is just there
			Net.apply_received.emit(&"whistle", [0, pt])
		&"gate_prop":
			var animals := tree.get_first_node_in_group(&"animals")
			var gates := tree.get_nodes_in_group(&"pen_gates")
			if animals == null or gates.is_empty():
				return
			var g: Vector3 = (gates[0] as Node3D).global_position
			if Vector2(here.x - g.x, here.z - g.z).length() > 4.0:
				return
			var best := -1
			var bd := INF
			for s in animals.fence_points():  # the section nearest the gate stands open (frees animals like a break)
				var dd: float = (s[1] as Vector3).distance_to(g)
				if dd < bd:
					bd = dd
					best = s[0]
			if best < 0 or animals.break_fence(best) == 0:
				return
	_used[key] = int(_used.get(key, 0)) + 1
	_last_ms[kind] = now
	Log.event(&"imposter_action", {"kind": String(kind), "position": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)]})  # host log only


# --- hidden dev setting (D-044) ---------------------------------------------------------------------

## Host, `DevGate.unlocked()` already checked by the caller: `imposter <peer id | name | me | none | off>` forces
## the season's pick (even below the minimum, Q-304). In a running match the pick happens now and only that
## peer is told; nothing is broadcast, so the other players see nothing different. Returns the console reply
## (host's own screen only).
static func dev_force(arg: String) -> String:
	if arg == "":
		return "? imposter <peer id|name|me|none|off>"
	if arg == "off":
		forced = ""
		return "imposter forced pick cleared"
	var who := ""
	if arg == "none":
		who = "none"
	else:
		for p in Net.profiles:
			var n := str(Net.profiles[p].get("name", ""))
			if str(p) == arg or n.to_lower() == arg.to_lower() or (arg == "me" and p == Game.local_peer()):
				who = str(Net.profiles[p].uid)
	if who == "":
		return "? no such player"
	forced = who
	if Game.match_started():
		pick()
	return "imposter forced (%s)%s" % [arg, "" if Game.match_started() else ", applies at match start"]
