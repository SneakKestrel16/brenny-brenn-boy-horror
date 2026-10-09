extends RefCounted
## P3-12 Dawn Report rules (doc 01 "Dawn Report", doc 03 section 17, doc 05 section 15), pure so
## tests/ui/test_dawn_report_logic.gd checks them headless. `build` turns one day's host log events into
## the report dictionary that `apply_dawn_report` carries: text and lure references only, never audio.
##
## events: [[name: String, data: Dictionary], ...] in log order, with the host's additions (DawnReport):
##   lure_played.owner_place, chase_started.place, death.place_name and death.distance.
## ctx: {day, names: {peer: name}, players: [peer], lines: {line_id: text}, plots_ripe, streamer_safe}.
## templates: {id: text} from dawn_report_templates.json.

const REPLAY_CAP := 3  ## lure replays beyond the Best Impression (placeholder: doc 01 gives no count)
const HERO_SCORE := {"disarmed": 3, "freed": 3, "refueled": 2, "stayed_out": 1}  ## placeholder weights (doc 03 section 17.3 "picked by score")
## ponytail: copy with no template yet (Q-066); move to dawn_report_templates.json when the Game Designer writes it.
const HERO_FREED := "pried {teammate} out of a trap"
const HERO_REFUELED := "kept the generator fed"
const FLAGS_LINE := "{name} planted {n} flags."
const NO_FLAGS := "Nobody marked a trap."


static func build(events: Array, ctx: Dictionary, templates: Dictionary) -> Dictionary:
	var names: Dictionary = ctx.get("names", {})
	var lures := {}  # lure_id -> lure_played data plus moved_m from lure_result
	var order: Array = []
	var chases := {}
	var chase_place := {}
	var deaths: Array = []
	var inside := {}
	var flags := {}
	var disarms := {}
	var refuels := {}
	var pries: Array = []  # [peer, trap_id]
	var victims := {}  # trap_id -> victim of a race survived with help
	var cash := 0
	var sale := 0  # the final dawn's end-of-season sale (doc 02 s9 step 2)
	var bill := {}
	var summary := {}
	for e: Array in events:
		var d: Dictionary = e[1]
		match String(e[0]):
			"lure_played":
				lures[d.lure_id] = d.duplicate()
				order.append(d.lure_id)
			"lure_result":
				if lures.has(d.lure_id):
					lures[d.lure_id].moved_m = float(d.moved_m)
			"chase_started":
				chases[d.target] = chases.get(d.target, 0) + 1
				chase_place[d.target] = d.get("place", "")
			"death":
				if d.cause != "reconnect":
					deaths.append(d)
			"inside_at_night":
				inside[d.player] = float(d.seconds)
			"flag_placed":
				flags[d.player] = flags.get(d.player, 0) + 1
			"flag_removed":  # P4-33: count the flags still out, not every placement (pull-up and replant)
				var by = d.get("owner", d.player)
				flags[by] = flags.get(by, 0) - 1
				if flags[by] <= 0:
					flags.erase(by)
			"trap_changed":
				if d.get("state") in ["disarmed", "filled"] and d.get("by") is int:
					disarms[d.by] = disarms.get(d.by, 0) + 1
			"hold_completed":
				if d.verb == "refuel":
					refuels[d.player] = refuels.get(d.player, 0) + 1
				elif d.verb == "pry":
					pries.append([d.player, d.target])
			"trap_race_result":
				if d.survived and not d.solo:
					victims[d.trap_id] = d.player
			"money_changed":
				if d.reason == "dawn_cash_in":
					cash += int(d.delta)
				elif d.reason == "end_of_season_sale":
					sale += int(d.delta)
			"medical_bill":
				bill = d
			"dawn_summary":
				summary = d
	var report := {"day": ctx.get("day", summary.get("day", 0)), "streamer_safe": ctx.get("streamer_safe", false),
		"ledger": _ledger(cash, bill, summary, sale), "final": bool(summary.get("final", false)), "sections": []}
	var sections: Array = report.sections
	# Best Impression: the lure that moved its target furthest (doc 01: "the best lure").
	var best := ""
	for id: String in order:
		if float(lures[id].get("moved_m", 0.0)) > 0.0 and (best.is_empty() or float(lures[id].moved_m) > float(lures[best].moved_m)):
			best = id
	if not best.is_empty():
		var l: Dictionary = lures[best]
		var f := _lure_fields(l, names, ctx)
		f.moved_m = int(round(float(l.moved_m)))
		sections.append({"id": "best_impression", "title": "Best Impression",
			"lines": [_fmt(templates, "best_impression", f)], "replays": [_replay(l, f, names, templates)]})
	# Most Wanted: who was chased most (doc 01); ties and a chase-free day fall back to who was faked most.
	var fakes := {}
	for id: String in order:
		if lures[id].get("owner") != null:
			fakes[int(lures[id].owner)] = fakes.get(int(lures[id].owner), 0) + 1
	var wanted := _top(chases, fakes)
	if wanted == 0:
		wanted = _top(fakes, {})
	if wanted != 0:
		var place: String = chase_place.get(wanted, "")
		if place.is_empty():
			for id: String in order:
				if lures[id].get("owner") != null and int(lures[id].owner) == wanted:
					place = lures[id].get("owner_place", "")
		sections.append({"id": "most_wanted", "title": "Most Wanted", "replays": [], "lines": [_fmt(templates, "most_wanted",
			{"owner_name": _name(names, wanted), "place_name": place if place else "nowhere in particular", "fake_count": fakes.get(wanted, 0)})]})
	# Cause of Death: a full wipe heads the obituaries; none at all gets the suspicious-town line.
	var obits: Array = []
	var players: Array = ctx.get("players", [])
	var dead := {}
	for d: Dictionary in deaths:
		dead[d.player] = true
	if not players.is_empty() and players.all(func(p: int) -> bool: return dead.has(p)):
		obits.append(_fmt(templates, "full_wipe", {}))
	for d: Dictionary in deaths:
		var mate := "nobody"
		for p: int in players:
			if p != d.player:
				mate = _name(names, p)
				break
		obits.append(_fmt(templates, "obit_" + String(d.cause), {"name": _name(names, d.player), "place_name": d.get("place_name", "the farm"),
			"n": ctx.get("plots_ripe", summary.get("plots_ripe", 0)), "teammate": mate, "distance": d.get("distance", 0)}, "{name} did not see the morning."))
	if obits.is_empty():
		obits.append(_fmt(templates, "no_deaths", {}))
	sections.append({"id": "cause_of_death", "title": "Cause of Death", "lines": obits, "replays": []})
	# Hero of the Night: highest score from the actions built so far (doc 03 section 17.3).
	var score := {}
	var action := {}
	var fx := func(p: int, pts: int, text: String) -> void:
		score[p] = score.get(p, 0) + pts
		if not action.has(p) or pts > int(action[p][0]):  # their biggest deed names them
			action[p] = [pts, text]
	for p: int in disarms:
		fx.call(p, HERO_SCORE.disarmed * disarms[p], _fmt(templates, "hero_disarmed", {"n": disarms[p]}))
	for pr: Array in pries:
		if victims.has(pr[1]) and victims[pr[1]] != pr[0]:
			fx.call(pr[0], HERO_SCORE.freed, HERO_FREED.format({"teammate": _name(names, victims[pr[1]])}))
	for p: int in refuels:
		fx.call(p, HERO_SCORE.refueled * refuels[p], HERO_REFUELED)
	if inside.size() > 1:
		var most: float = inside.values().max()
		var least: float = inside.values().min()
		for p: int in inside:
			if most > least and inside[p] == least and not dead.has(p):
				fx.call(p, HERO_SCORE.stayed_out, _fmt(templates, "hero_stayed_out", {}))
	var hero := _top(score, {})
	if hero != 0:
		sections.append({"id": "hero_of_the_night", "title": "Hero of the Night", "replays": [],
			"lines": [_fmt(templates, "hero_of_the_night", {"name": _name(names, hero), "hero_action": action[hero][1]})]})
	# Lure replay: the other targeted lures (doc 01 "Targeted lures are revealed here").
	var lines: Array = []
	var replays: Array = []
	for id: String in order:
		var l: Dictionary = lures[id]
		if id == best or int(l.get("heard_by", -1)) < 0 or replays.size() >= REPLAY_CAP:
			continue
		var f := _lure_fields(l, names, ctx)
		lines.append(_fmt(templates, "lure_replay", f))
		replays.append(_replay(l, f, names, templates))
	if not replays.is_empty():
		sections.append({"id": "lure_replay", "title": "Heard in the Corn", "lines": lines, "replays": replays})
	# Flags placed (doc 05 section 15): one line per player who marked a trap.
	var fl: Array = []
	for p: int in flags:
		fl.append(FLAGS_LINE.format({"name": _name(names, p), "n": flags[p]}))
	sections.append({"id": "flags_placed", "title": "Flags Placed", "lines": fl if fl else [NO_FLAGS], "replays": []})
	return report


## Doc 01 "Dawn, in this order": cash-in, medical bill, payment, farm damage. Rows: [label, coins, red ink].
static func _ledger(cash: int, bill: Dictionary, summary: Dictionary, sale: int = 0) -> Array:
	var rows: Array = [["Cash-in", cash, false]]
	if bool(summary.get("final", false)):
		rows.append(["Crops left in the ground, half price", sale, false])
	if not bill.is_empty():
		rows.append(["Medical bill", -int(bill.paid), true])
		if int(bill.to_final) > 0:
			rows.append(["Added to the final payment", int(bill.to_final), true])
	rows.append(["Farm damage", -int(summary.get("farm_damage", 0)), int(summary.get("farm_damage", 0)) > 0])
	rows.append(["Balance", int(summary.get("coins", 0)), false])
	return rows


## The peer with the highest count; ties broken by `tie`, then the lower id. 0 when `counts` is empty.
static func _top(counts: Dictionary, tie: Dictionary) -> int:
	var best := 0
	for p: int in counts:
		if best == 0 or counts[p] > counts[best] or (counts[p] == counts[best] and
				(tie.get(p, 0) > tie.get(best, 0) or (tie.get(p, 0) == tie.get(best, 0) and p < best))):
			best = p
	return best


static func _lure_fields(l: Dictionary, names: Dictionary, ctx: Dictionary) -> Dictionary:
	var owner: Variant = l.get("owner")
	var text := "something"  # a sound lure says nothing
	if l.kind != "sound":
		var line: String = str(l.get("line_id", ""))
		text = _name(names, int(l.target)) + "!" if line.begins_with("name:") else ctx.get("lines", {}).get(line, "...")
	return {"owner_name": "a stranger" if owner == null else _name(names, int(owner)), "line_text": text,
		"target_name": _name(names, int(l.target)), "owner_place": l.get("owner_place", "nowhere near it") if owner != null else "nowhere at all"}


## A lure reference for the replay (no audio): every peer plays its own copy of the clip (doc 05 section 15).
static func _replay(l: Dictionary, f: Dictionary, names: Dictionary, templates: Dictionary) -> Dictionary:
	var source := "stranger"
	if l.kind == "clip":
		source = "clip:%d:%s" % [int(l.owner), l.clip_id]
	elif l.kind == "sound":
		source = "sound:" + str(l.sound_id)
	var owner: int = int(l.owner) if l.get("owner") != null else 0
	return {"lure_id": l.lure_id, "source": source, "tell": l.get("tell", "none"), "ghost": l.get("ghost", false), "owner": owner,
		"off_text": _fmt(templates, "off_player", {"name": f.owner_name}) if owner != 0 else ""}


static func _fmt(templates: Dictionary, id: String, f: Dictionary, fallback := "") -> String:
	return String(templates.get(id, fallback if fallback else id)).format(f)


static func _name(names: Dictionary, p: int) -> String:
	return names.get(p, "Bot %d" % -p if p < 0 else "Player %d" % p)
