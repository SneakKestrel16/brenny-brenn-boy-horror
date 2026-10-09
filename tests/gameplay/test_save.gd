extends SceneTree
## P4-10 (doc 05 s17): the dawn save, load, name checks, chunk receipt, headcount clamp and the D-079 case.
## One host, no client.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_save.gd -- --host --phase1 --port=53701 --free-mouse

const SEASON := "test_save_p410"

var _t := 0.0
var _done := false
var _fails := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	if main == null or main.get_node_or_null("Death") == null:
		if _t > 20.0:
			print("test_save: FAIL (no Main after 20 s)")
			quit(1)
		return false
	if _done:
		return false
	_done = true
	var Debt: GDScript = load("res://game/farming/debt.gd")
	var Save: GDScript = load("res://game/core/save.gd")  # not the class_name: -s compiles this file before the autoloads exist
	var game: Node = root.get_node("Game")
	var data: Node = root.get_node("Data")
	var farm: Node = main.get_node("Farm")
	var death: Node = main.get_node("Death")
	var d: Node = death.debt

	# doc 09 s3 / D-079: one dawn at 101%, then 85%: total 1135, first payment 223
	var total: int = Debt.total_for([101], 85, 3)
	_check(total == 1135 and Debt.first_of(total) == 223, "D-079 case: %d / %d" % [total, Debt.first_of(total)])
	# Q-089: a solo bill reads the 2-player percentage
	_check(data.scaled(100, &"bill", 1) == data.scaled(100, &"bill", 2) and data.scaled(100, &"bill", 2) == 59, "solo bill clamps to 2 players (59%)")

	# name and id checks (path traversal)
	_check(Save.valid_name("dawn_03.json") and Save.valid_name("latest.json"), "good file names")
	for bad in ["../x.json", "dawn_3.json", "dawn_03.json.tmp", "x/dawn_03.json", "", "dawn_03.JSON"]:
		_check(not Save.valid_name(bad), "refused name '%s'" % bad)
	for bad in ["", "..", "a/b", "a.b", "a b", "a\\b"]:
		_check(not Save.valid_season_id(bad), "refused season id '%s'" % bad)

	# build, write, read
	game.season_id = SEASON
	game.roles = {"uid_a": "scout"}
	farm.coins = 321
	farm.final_extra = 7
	d.paid = 99
	d.penalty = 12
	d._pcts.assign([101, 85])
	clock_day(5)
	var s: Dictionary = Save.build(main.get_tree(), false)
	var name: String = Save.write_state(s, SEASON, false)
	_check(name == "dawn_05.json", "wrote %s" % name)
	var env: Dictionary = Save.read(Save.root() + SEASON + "/latest.json")
	_check(not env.is_empty() and int(env.state.coins) == 321 and int(env.state.day) == 5, "latest.json reads back")
	var text := FileAccess.get_file_as_string(Save.root() + SEASON + "/latest.json")
	_check(not text.contains("voice") and not text.contains("clip") and not text.contains("lobby"), "no voice, clip or lobby keys")
	_check(not FileAccess.file_exists(Save.root() + SEASON + "/dawn_05.json.tmp"), "no temp file left")
	for day in [6, 7, 8, 9]:
		s.day = day
		Save.write_state(s, SEASON, false)
	var dawns := 0
	for f in DirAccess.get_files_at(Save.root() + SEASON):
		dawns += int(f.begins_with("dawn_"))
	_check(dawns == Save.KEEP, "kept the last %d dawn files (%d)" % [Save.KEEP, dawns])
	_check(Save.parse("not json").is_empty() and Save.parse('{"schema_version": 99, "state": {}}').is_empty(), "bad text and bad schema are refused")
	_check(Save.parse('{"schema_version": 1, "season_id": "x", "state": 3}').is_empty(), "bad shape is refused")

	# chunk receipt is for clients only (the 2-instance run covers the client side)
	Save.receive(SEASON, "dawn_77.json", 0, 1, JSON.stringify(Save.envelope(s)).to_utf8_buffer())
	_check(not FileAccess.file_exists(Save.root() + SEASON + "/dawn_77.json"), "the host ignores a received save")

	# load: mutate, then apply the saved state
	farm.coins = 1
	d.paid = 0
	d.penalty = 0
	d._pcts.clear()
	game.roles = {}
	s.day = 5
	Save.pending = s
	Save.apply_pending(main)
	_check(farm.coins == 321 and farm.final_extra == 7, "coins and final_extra restored")
	_check(d.paid == 99 and d.penalty == 12 and d._pcts == [101, 85], "debt restored (paid %d, penalty %d, pcts %s)" % [d.paid, d.penalty, d._pcts])
	_check(game.roles.get("uid_a") == "scout", "roles restored")
	_check(Save.pending.is_empty(), "pending cleared")

	# P4-15 hook: the tally goes by uid
	var t := {"disarmed": {1: 3}, "coins": {1: 40}}
	var ts: Dictionary = Save.tally_state(t)
	var uid := str(root.get_node("Net").profiles.get(1, {}).get("uid", ""))
	_check(uid == "" or ts.disarmed.get(uid) == 3, "tally saved by uid")

	# P4-15: the real SeasonAwards' `_tally` and `_hm_wipe` through build / apply_pending (Q-123)
	var net: Node = root.get_node("Net")
	var had_profiles: Dictionary = net.profiles.duplicate(true)
	net.profiles[1] = {"uid": "uid_host", "name": "H"}
	net.profiles[2] = {"uid": "uid_b", "name": "B"}  # peer 2 is in the session, uid_c is not
	var aw: Node = null
	for n in get_nodes_in_group(&"saveable"):
		if str(n.save_key) == "season_awards":
			aw = n
	_check(aw != null and aw.get_parent() == main, "SeasonAwards is in group saveable")
	if aw == null:
		quit(1)
		return false
	aw._tally = {"disarmed": {1: 3, 2: 1}, "fooled": {}, "coins": {1: 40, 2: 15}, "inside": {2: 9}}
	aw._hm_wipe = true
	Save.tally_left = {"coins": {"uid_c": 77}}  # a farmhand absent from this session keeps their count
	var s2: Dictionary = Save.build(main.get_tree(), false)
	var ex: Dictionary = s2.extras.get("season_awards", {})
	_check(ex.get("hm_wipe") == true and ex.tally.coins.get("uid_b") == 15 and ex.tally.coins.get("uid_c") == 77, "tally and hm_wipe in the save by uid")
	var text2 := JSON.stringify(Save.envelope(s2))
	var back: Dictionary = Save.parse(text2)  # through real JSON: ints come back as floats, keys as strings
	_check(not back.is_empty(), "the save with the tally parses")
	aw._tally = {"disarmed": {}, "fooled": {}, "coins": {}, "inside": {}}
	aw._hm_wipe = false
	Save.tally_left = {}
	Save.pending = back.state
	Save.apply_pending(main)
	_check(aw._hm_wipe == true, "hm_wipe restored")
	_check(aw._tally.disarmed.get(1) == 3 and aw._tally.disarmed.get(2) == 1 and aw._tally.coins.get(1) == 40 and aw._tally.coins.get(2) == 15 and aw._tally.inside.get(2) == 9, "tally restored by peer: %s" % [aw._tally])
	_check(Save.tally_left.coins.get("uid_c") == 77, "absent farmhand's count kept for when they join")
	_check(Save.tally_state(aw._tally).coins.get("uid_c") == 77, "and re-saved at the next dawn")
	Save.tally_left = {}

	# P4-14 walkie (Q-121): a leaver's upgrades and charge stay in the save by uid; a rejoiner (new peer id) gets them back
	var wk: Node = root.get_node("Voice").get_node("Walkie")
	var st: Node = farm.store
	game.players[2] = {}
	Save.peer_uid[2] = "uid_b"
	st.own[2] = {&"walkie_talkie": true}
	wk.battery[2] = 42.0
	st.team[&"walkie_battery"] = 2
	net.profiles.erase(2)  # as Net does before `player_left`
	game.players.erase(2)
	wk._on_player_left(2)
	var s3: Dictionary = Save.build(main.get_tree(), false)
	_check(s3.store.own.get("uid_b", {}).has("walkie_talkie") and is_equal_approx(float(s3.walkie.battery.get("uid_b", 0)), 42.0), "leaver's walkie and charge saved by uid: %s %s" % [s3.store.own, s3.walkie])
	_check(int(s3.store.team.get("walkie_battery", 0)) == 2, "spare batteries saved in the team pool")
	net.profiles[5] = {"uid": "uid_b", "name": "B"}
	game.players[5] = {}
	game.player_joined.emit(5)
	_check(st.owns(5, &"walkie_talkie") and is_equal_approx(float(wk.battery.get(5, 0)), 42.0) and not st.own.has(2), "rejoiner gets walkie and charge back")
	game.players.erase(5)
	st.own.erase(5)
	wk.battery.erase(5)
	net.profiles = had_profiles

	# tidy
	for f in DirAccess.get_files_at(Save.root() + SEASON):
		DirAccess.remove_absolute(Save.root() + SEASON + "/" + f)
	DirAccess.remove_absolute(Save.root() + SEASON)
	print("test_save: ", "PASS" if _fails == 0 else "FAIL")
	quit(1 if _fails > 0 else 0)
	return false


func clock_day(n: int) -> void:
	root.get_node("Clock").day = n


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL", what)
