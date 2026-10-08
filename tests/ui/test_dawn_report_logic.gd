extends SceneTree
## P3-12 unit checks for the Dawn Report builder (doc 01 "Dawn Report", doc 03 section 17), on the
## shipped dawn_report_templates.json.
##   "$GODOT" --headless --path . -s res://tests/ui/test_dawn_report_logic.gd

const Logic := preload("res://game/ui/dawn_report_logic.gd")

var _fails := 0


func _init() -> void:
	var data: Node = preload("res://game/core/data.gd").new()
	data.load_dir("res://data")
	var tpl := {}
	for r in data.records(&"dawn_report_templates"):
		tpl[String(r.id)] = r.text
	data.free()
	var ctx := {"names": {1: "Ann", 2: "Ben"}, "players": [1, 2, -1], "lines": {"over_here": "Over here!"}}
	var ev: Array = [
		["lure_played", {"lure_id": "lure_1", "kind": "clip", "owner": 2, "line_id": "over_here", "clip_id": "over_here", "target": 1,
			"heard_by": 1, "tell": "echo", "ghost": false, "owner_place": "near the yard"}],
		["lure_result", {"lure_id": "lure_1", "moved_m": 12.4}],
		["lure_played", {"lure_id": "lure_2", "kind": "clip", "owner": 2, "line_id": "name:u1", "clip_id": "name_u1", "target": 1,
			"heard_by": 1, "tell": "none", "ghost": false}],
		["lure_result", {"lure_id": "lure_2", "moved_m": 3.0}],
		["lure_played", {"lure_id": "lure_3", "kind": "sound", "owner": -1, "sound_id": "door_fake", "target": 2, "heard_by": -1, "tell": "none"}],
		["chase_started", {"target": 1, "place": "near the pen"}],
		["chase_started", {"target": 2, "place": "near the yard"}],
		["chase_started", {"target": 2, "place": "near the field a"}],
		["death", {"player": 2, "cause": "night_chase", "place_name": "near the field a", "distance": 31}],
		["death", {"player": 1, "cause": "reconnect"}],
		["trap_changed", {"state": "disarmed", "by": 1}],
		["trap_changed", {"state": "set", "by": "creature"}],
		["hold_completed", {"player": -1, "verb": "pry", "target": "trap_1"}],
		["trap_race_result", {"player": 1, "trap_id": "trap_1", "solo": false, "survived": true}],
		["flag_placed", {"player": 1}], ["flag_placed", {"player": 1}],
		["money_changed", {"reason": "dawn_cash_in", "delta": 30}], ["money_changed", {"reason": "dawn_cash_in", "delta": 10}],
		["money_changed", {"reason": "sell", "delta": 99}],
		["medical_bill", {"bill": 60, "paid": 40, "to_final": 20}],
		["dawn_summary", {"day": 3, "coins": 140, "plots_ripe": 4, "farm_damage": 0}],
	]
	var r := Logic.build(ev, ctx, tpl)
	var ids: Array = r.sections.map(func(s: Dictionary) -> String: return s.id)
	_check(ids == ["best_impression", "most_wanted", "cause_of_death", "hero_of_the_night", "lure_replay", "flags_placed"], "section order %s" % [ids])
	_check(r.day == 3, "day from dawn_summary")
	_check(r.ledger[0] == ["Cash-in", 40, false], "cash-in sums dawn_cash_in only")
	_check(r.ledger[1] == ["Medical bill", -40, true] and r.ledger[2][1] == 20, "bill paid in red, rest to the final payment")
	_check(r.ledger[-1] == ["Balance", 140, false], "balance last")
	var s := _sec(r, "best_impression")
	_check("Ben" in s.lines[0] and "Over here!" in s.lines[0] and "Ann" in s.lines[0] and "12 m" in s.lines[0], "best impression: " + s.lines[0])
	_check(s.replays[0].source == "clip:2:over_here" and s.replays[0].tell == "echo", "best impression replays the clip with its tell")
	_check("MOST WANTED: Ben" in _sec(r, "most_wanted").lines[0] and "field a" in _sec(r, "most_wanted").lines[0], "most wanted: chased most, last place")
	_check("2 calls" in _sec(r, "most_wanted").lines[0], "most wanted: fake count")
	s = _sec(r, "cause_of_death")
	_check(s.lines.size() == 1 and "Ben" in s.lines[0] and "31 m" in s.lines[0], "one obituary, reconnect skipped: %s" % [s.lines])
	_check("Bot 1" in _sec(r, "hero_of_the_night").lines[0], "hero: a pry that freed a teammate ties a disarm, lower id wins")
	s = _sec(r, "lure_replay")
	_check(s.replays.size() == 1 and s.replays[0].lure_id == "lure_2" and "Ann!" in s.lines[0], "replays the other targeted lure, name call text")
	_check("Ann planted 2 flags." in _sec(r, "flags_placed").lines, "flags placed")
	# nobody died, nothing happened
	r = Logic.build([["dawn_summary", {"day": 1, "coins": 0}]], ctx, tpl)
	ids = r.sections.map(func(x: Dictionary) -> String: return x.id)
	_check(ids == ["cause_of_death", "flags_placed"], "quiet day: %s" % [ids])
	_check(_sec(r, "cause_of_death").lines[0] == tpl.no_deaths, "no deaths line")
	# full wipe heads the obituaries
	var wipe: Array = [["death", {"player": 1, "cause": "night_trap"}], ["death", {"player": 2, "cause": "deep_corn"}],
		["death", {"player": -1, "cause": "unknown_cause"}], ["dawn_summary", {"day": 2, "coins": 0}]]
	s = _sec(Logic.build(wipe, ctx, tpl), "cause_of_death")
	_check(s.lines[0] == tpl.full_wipe and s.lines.size() == 4, "full wipe first")
	_check("Bot 1 did not see the morning." in s.lines, "unknown cause falls back")
	# a sound lure for an Off player carries their off text
	var off: Array = [["lure_played", {"lure_id": "lure_9", "kind": "sound", "owner": 2, "sound_id": "step_walk_fake", "target": 1, "heard_by": 1}],
		["lure_result", {"lure_id": "lure_9", "moved_m": 5.0}], ["dawn_summary", {"day": 1, "coins": 0}]]
	var rp: Dictionary = _sec(Logic.build(off, ctx, tpl), "best_impression").replays[0]
	_check(rp.source == "sound:step_walk_fake" and rp.off_text == "Ben said something.", "off player: sound plus text")
	print("test_dawn_report_logic: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _sec(r: Dictionary, id: String) -> Dictionary:
	for s: Dictionary in r.sections:
		if s.id == id:
			return s
	return {"lines": [""], "replays": [{}]}


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
