extends Node
## Doc 05 section 4: the only loader of data/*.json (CONTRACTS section 6). Loads once at startup.
## Checks: envelope, table == file name, schema_version 1, duplicate ids, source valid, required
## ids present. Failures go to `errors` and push_error (a refusal to start: Game reads `ok`).
## Not a JSON Schema validator; tools/sim runs the full schemas.

const TABLES: Array[StringName] = [&"season", &"labor", &"crops", &"pumpkin", &"debt", &"medical_bill",
		&"player_scaling", &"difficulty", &"store", &"ramp_up", &"traps", &"taint", &"roles",
		&"creature", &"sabotage", &"ai_director", &"voice_lines", &"dawn_report_templates", &"rejoin_lines", &"quirks"]
## Phase 1 content: loaded only with --phase1 (P1-01 handoff; Director approval pending).
const PHASE1_TABLE := &"phase1"
## Must exist for Phase 1 (P1-01 wrote these). The rest load when present.
const REQUIRED_TABLES: Array[StringName] = [&"season", &"labor", &"crops", &"creature", &"voice_lines"]
## doc 02 A.3 ids Phase 1 code asks for (section 4, check 3).
const REQUIRED_IDS := {
	&"labor": [&"plant", &"water", &"water_quiet", &"harvest", &"fill_can", &"wash",
			&"water_prize_pumpkin", &"sell", &"buy", &"disarm_bear", &"pry", &"fill_pit", &"cut_bells",
			&"hang_trap", &"place_flag", &"fill_fuel", &"refuel", &"repair_generator", &"repair_fence",
			&"clear_plot", &"place_scarecrow", &"walk", &"crouch", &"sprint", &"can", &"carry"],
	&"season": [&"day_s", &"dusk_s", &"night_s", &"harvest_moon_cap_s"],
}  # P4-04: no crop id is required here; crops.gd finds crops by what they do (no crop name in code)
const SOURCES := ["doc01", "sim", "placeholder"]

var ok := false
var errors: Array[String] = []
var hash_value := 0  ## of all loaded file text; the host sends it so a client can spot other numbers
var phase1 := not OS.get_cmdline_user_args().has("--no-phase1")  ## P2-24: Phase 1 night data loads by default; `--no-phase1` opts out (`--phase1` still accepted)
var _tables: Dictionary = {}  ## table -> {id: record}
var _order: Dictionary = {}  ## table -> Array[Dictionary] in file order


func _ready() -> void:
	var dir := "res://data"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i].begins_with("--data-dir="):
			dir = args[i].get_slice("=", 1)
		elif args[i] == "--data-dir" and i + 1 < args.size():
			dir = args[i + 1]
		elif args[i] == "--phase1":
			phase1 = true
	load_dir(dir, phase1)
	for e in errors:
		push_error("Data: %s" % e)


## Loads every table file in `dir`. Returns `ok`; reasons are in `errors`.
func load_dir(dir: String, with_phase1: bool = false) -> bool:
	_tables.clear()
	_order.clear()
	errors.clear()
	var texts := ""
	var names: Array[StringName] = TABLES.duplicate()
	if with_phase1:
		names.append(PHASE1_TABLE)
	for t in names:
		var path := "%s/%s.json" % [dir, t]
		if not FileAccess.file_exists(path):
			if t in REQUIRED_TABLES or t == PHASE1_TABLE:
				errors.append("missing file %s" % path)
			continue
		var text := FileAccess.get_file_as_string(path)
		texts += text
		load_text(t, text)
	for t in REQUIRED_IDS:
		for id in REQUIRED_IDS[t]:
			if _tables.has(t) and not _tables[t].has(id):
				errors.append("%s: required id '%s' missing" % [t, id])
	hash_value = texts.hash()
	ok = errors.is_empty()
	return ok


## Parses and checks one table's JSON text; appends to `errors`. Public for the unit checks.
func load_text(table: StringName, text: String) -> bool:
	var before := errors.size()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		errors.append("%s: not a JSON object (%s)" % [table, json.get_error_message()])
		return false
	var d: Dictionary = json.data
	if d.get("table") != String(table):
		errors.append("%s: envelope table is '%s'" % [table, d.get("table")])
	if d.get("schema_version") != 1:
		errors.append("%s: schema_version is not 1" % table)
	if not d.get("records") is Array:
		errors.append("%s: no records array" % table)
		return false
	var by_id := {}
	var list: Array[Dictionary] = []
	for r in d["records"]:
		if not r is Dictionary or not r.get("id") is String:
			errors.append("%s: record without an id" % table)
			continue
		var id := StringName(r["id"])
		if by_id.has(id):
			errors.append("%s: duplicate id '%s'" % [table, id])
			continue
		if not str(r.get("source")) in SOURCES:
			errors.append("%s.%s: bad source '%s'" % [table, id, r.get("source")])
		by_id[id] = r
		list.append(r)
	_tables[table] = by_id
	_order[table] = list
	return errors.size() == before


func has_table(table: StringName) -> bool:
	return _tables.has(table)


func record(table: StringName, id: StringName) -> Dictionary:
	if not _tables.has(table) or not _tables[table].has(id):
		push_error("Data: no record %s.%s" % [table, id])
		return {}
	return _tables[table][id]


func records(table: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_order.get(table, []))
	return out


func value(table: StringName, id: StringName, field: StringName = &"value") -> Variant:
	if table == &"season" and id == &"season_days" and _short():
		return record(&"difficulty", &"short_season").season_days  # P4-12: one place for every season-length reader
	var r := record(table, id)
	if not r.has(field):
		push_error("Data: %s.%s has no field '%s'" % [table, id, field])
		return null
	return r[field]


## P4-12: the short season (difficulty.json `short_season`, doc 02 s16) is on.
func _short() -> bool:
	var g := get_node_or_null(^"/root/Game")
	return g != null and g.difficulty == &"short_season"


func hold_s(verb: StringName) -> float:
	return float(value(&"labor", verb, &"hold_s"))


func speed(move: StringName) -> float:
	return float(value(&"labor", move, &"speed_mps"))


## Doc 02 section 4: ceil(v * pct / 100) in integer math; debt is the one round-to-nearest case
## (D-017). `players` 0 means the session's headcount.
func scaled(v: int, kind: StringName, players: int = 0) -> int:
	if players == 0:
		players = get_node("/root/Game").player_count()
	# D-079: debt payments and medical bills read `payment_pct_by_players` (59/85/101); traps keep `pct_by_players`.
	var key := "payment_pct_by_players" if kind in [&"debt", &"bill"] else "pct_by_players"
	if kind in [&"debt", &"bill"]:  # Q-089: no solo play (doc 01 "One player left"); same clamp as Debt.pct_for and Animals.bill_dusk
		players = clampi(players, 2, get_node("/root/Game").max_players())
	var pct := int(record(&"player_scaling", &"headcount").get(key, {}).get(str(players), 100))
	return difficulty_scaled(scale_pct(v, pct, kind == &"debt"), kind)


## Doc 02 s16 (P4-11): the session difficulty's `trap_pct` / `bill_pct` / `generator_tank_pct`, applied after
## headcount scaling and rounded up. Kinds without a difficulty field pass through.
func difficulty_scaled(v: int, kind: StringName) -> int:
	var field: String = {&"traps": "trap_pct", &"bill": "bill_pct", &"generator_tank": "generator_tank_pct"}.get(kind, "")
	var game := get_node_or_null("/root/Game") if is_inside_tree() else null  # null in unit tests: no difficulty
	if field == "" or game == null or not _tables.get(&"difficulty", {}).has(game.difficulty):
		return v
	return scale_pct(v, int(_tables[&"difficulty"][game.difficulty].get(field, 100)))


static func scale_pct(v: int, pct: int, nearest: bool = false) -> int:
	return (v * pct + 50) / 100 if nearest else (v * pct + 99) / 100
