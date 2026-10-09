extends Node
## Doc 05 section 11 (P2-11): the sweep tools' shared state. Flags (world objects every peer sees,
## `apply_flags`; each remembers who placed it, so the limit counts it; anyone pulls one up, and a leaver's
## flags go with them, P4-33, D-142) and the shed pegboard (`apply_pegboard_changed`: which `pegboard_slots` hold a bear
## trap). The host owns both and broadcasts the whole list on every change; a late joiner gets them on
## `farm_state`. The disarm and fill holds are in `trap_target.gd`; the pegboard and flag holds are
## `peg_target.gd` and `flag_spot.gd`. For P2-05 (the creature steals a trap): `take_trap()`.
## Debug: `-- --pegboard-empty` starts the pegboard empty (QA: the real start is full, doc 02 section 12).

const FlagSpot := preload("res://game/traps_player/flag_spot.gd")
const PegTarget := preload("res://game/traps_player/peg_target.gd")
const PICK_FROM_M := 0.7  ## a flag's pick body starts above a set trap's 0.6 m pick box, so the trap wins the aim
const START_FILLED := true  ## doc 02 section 12: the starting pegboard holds its bear traps (placeholder)

var farm: Node
var flags: Array = []  ## every peer: {pos: Vector3, by: peer} per flag
var filled: Array = []  ## every peer: bool per slot, slots sorted by marker name
var _flag_root: Node3D
var _slots: Array = []
var _slot_mesh: Array = []


func _ready() -> void:
	add_to_group(&"trap_sweep")
	farm = get_parent().get_node("Farm")
	_flag_root = Node3D.new()
	_flag_root.name = "Flags"
	add_child(_flag_root)
	_slots = get_tree().get_nodes_in_group(&"pegboard_slots")
	_slots.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	var full := START_FILLED and not OS.get_cmdline_user_args().has("--pegboard-empty")
	for s in _slots:
		filled.append(full)
		_slot_mesh.append(_make_slot(s))
	_paint()
	var board := get_tree().get_first_node_in_group(&"pegboard_spots")
	if board != null:
		var t := PegTarget.new()
		t.sweep = self
		t.range_m = 3.0
		farm._attach(board, t, "pegboard", Vector3(4.0, 1.6, 1.0))
	Net.apply_received.connect(_on_apply)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sweep-shot=") and Game.is_host():
			_shots.call_deferred(a.trim_prefix("--sweep-shot="))
	if Game.is_host():
		Game.player_left.connect(_drop_flags_of)
		Net.request_received.connect(func(what: StringName, peer: int, _a: Array) -> void:
			if what == &"farm_state":  # a late joiner sees the flags and the pegboard
				Net.to_peers(&"apply_flags", [flags], [peer])
				Net.to_peers(&"apply_pegboard_changed", [filled], [peer]))


# --- host ----------------------------------------------------------------------------------------

func flag_near(p: Vector3, gap: float) -> bool:
	for f in flags:
		if _flat(f.pos, p) < gap:
			return true
	return false


## Flags out per player at once (doc 01 "Flags", D-120; labor.json `place_flag.max_per_player`, placeholder).
func limit() -> int:
	return int(Data.record(&"labor", &"place_flag").get("max_per_player", 3))


func count_of(peer: int) -> int:
	return flags.filter(func(f: Dictionary) -> bool: return f.by == peer).size()


## The index of the flag at `p` (the wire rounds to 0.1 m), or -1.
func flag_at(p: Vector3) -> int:
	for i in flags.size():
		if _flat(flags[i].pos, p) < 0.1:
			return i
	return -1


func add_flag(p: Vector3, peer: int) -> void:
	flags.append({"pos": p, "by": peer})
	Log.event(&"flag_placed", {"player": peer, "position": [p.x, p.z], "trap_id": null, "flags": flags.size(), "mine": count_of(peer)})
	_send_flags()


## P4-33, D-142: `peer` (anyone) pulls a flag up; its owner's slot frees.
func remove_flag(i: int, peer: int) -> void:
	if i < 0 or i >= flags.size():
		return
	var p: Vector3 = flags[i].pos
	var by: int = flags[i].by
	flags.remove_at(i)
	Log.event(&"flag_removed", {"player": peer, "owner": by, "position": [p.x, p.z], "trap_id": null,
			"flags": flags.size(), "mine": count_of(by)})
	_send_flags()


## D-142: a player who leaves or drops takes their flags with them.
func _drop_flags_of(peer: int) -> void:
	var keep: Array = flags.filter(func(f: Dictionary) -> bool: return f.by != peer)
	if keep.size() != flags.size():
		Log.event(&"flags_dropped", {"player": peer, "count": flags.size() - keep.size()})
		flags = keep
		_send_flags()


## A flag is cleared when a trap beside it is disarmed or filled (the sweep for that spot is done); its
## owner gets the slot back.
func remove_flags_near(p: Vector3, radius: float) -> void:
	var keep: Array = flags.filter(func(f: Dictionary) -> bool: return _flat(f.pos, p) > radius)
	if keep.size() != flags.size():
		flags = keep
		_send_flags()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## `peer` hangs the trap in their hands on the first free slot (the registry has checked there is one).
func hang(peer: int) -> void:
	var i := filled.find(false)
	if i < 0:
		return
	filled[i] = true
	var st: Dictionary = farm.pstate(peer)
	farm.set_hands(peer, bool(st.get("shovel", false)), false)
	Log.event(&"pegboard_changed", {"change": "hung", "slot": i, "by": peer, "filled": filled.count(true)})
	_send_peg()


## P2-05: the creature takes one trap off the pegboard. False if none hangs.
func take_trap() -> bool:
	var i := filled.find(true)
	if i < 0:
		return false
	filled[i] = false
	Log.event(&"pegboard_changed", {"change": "taken", "slot": i, "by": 0, "filled": filled.count(true)})
	_send_peg()
	return true


## Host: a one-off hold target for `flag:<x>,<z>` (the registry frees it).
func flag_spot(wire: String) -> Node:
	var s := FlagSpot.new()
	s.id = wire
	s.pos = FlagSpot.from_id(wire)
	s.sweep = self
	s.farm = farm
	return s


func _send_flags() -> void:
	Net.to_peers(&"apply_flags", [flags])
	Net.apply_received.emit(&"flags", [flags])


func _send_peg() -> void:
	Net.to_peers(&"apply_pegboard_changed", [filled])
	Net.apply_received.emit(&"pegboard_changed", [filled])


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	match what:
		&"flags":
			flags = args[0].duplicate()
			Log.event(&"apply_flags", {"count": flags.size()})
			_draw_flags()
		&"pegboard_changed":
			filled = args[0].duplicate()
			Log.event(&"apply_pegboard_changed", {"filled": filled.count(true), "slots": filled.size()})
			_paint()


func _draw_flags() -> void:
	for c in _flag_root.get_children():
		c.free()
	for fl in flags:
		var f: Vector3 = fl.pos
		var at := Node3D.new()  # P4-33: a player aims at the flag to pull it up
		at.position = f + Vector3(0, PICK_FROM_M, 0)
		_flag_root.add_child(at)
		var spot := FlagSpot.new()
		spot.id = FlagSpot.make_id(f)
		spot.pos = f
		spot.by = int(fl.by)
		spot.sweep = self
		at.add_child(spot)
		spot.add_pick_body(Vector3(0.25, 1.8 - PICK_FROM_M, 0.25))  # a thin pole up to the cloth, above the trap
		var pole := MeshInstance3D.new()  # placeholder art: a thin pole with a red cloth, visible from far
		var pm := CylinderMesh.new()
		pm.top_radius = 0.025
		pm.bottom_radius = 0.025
		pm.height = 1.6
		pole.mesh = pm
		pole.material_override = _mat(Color(0.35, 0.25, 0.15))
		pole.position = Vector3(f.x, f.y + 0.8, f.z)
		_flag_root.add_child(pole)
		var cloth := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.45, 0.3, 0.02)
		cloth.mesh = cm
		cloth.material_override = _mat(Color(0.85, 0.08, 0.06))
		cloth.position = Vector3(f.x + 0.25, f.y + 1.4, f.z)
		_flag_root.add_child(cloth)


func _make_slot(marker: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.6, 0.6, 0.12)
	mi.mesh = b
	mi.position = Vector3(0, 0, -0.1)  # the board faces local -Z
	var art := TrapArt.bear()  # Q-058: a hung trap is the bear trap hanging flat on the board (a hung trap is always a bear)
	art.rotation.x = -PI / 2.0
	art.scale = Vector3.ONE * 0.5
	mi.add_child(art)
	marker.add_child(mi)
	return mi


## A hung trap is the bear trap on its hook; an empty slot is a pale outline-ish slab.
func _paint() -> void:
	for i in _slot_mesh.size():
		var full: bool = filled[i] if i < filled.size() else false
		var m := _slot_mesh[i] as MeshInstance3D
		m.get_child(0).visible = full
		m.material_override = _mat(Color(0.2, 0.17, 0.14) if full else Color(0.75, 0.7, 0.6, 0.35), not full)
		(m.mesh as BoxMesh).size = Vector3(0.6, 0.6, 0.02)


func _mat(c: Color, alpha: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# --- QA screenshots (`-- --sweep-shot=<dir>`, windowed; with --creature-test) ------------------------
# Host only. Frames the first set bear trap and the first set pit from 4 m (the clue range, doc 03 section 3.3),
# then a flag and a hung trap on the pegboard, saves PNGs into <dir> and quits.

func _shots(dir: String) -> void:
	var race := get_tree().get_first_node_in_group(&"trap_race")
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var id := ""
	while id == "":
		await get_tree().create_timer(0.5).timeout
		for k in race.traps:
			if race.traps[k].kind == &"bear" and race.traps[k].state == &"set":
				id = k
	await _shot_at(cam, farm.targets[id].target_pos(), Vector3(0, 2.6, 1.6), dir, "clue_bear")
	var f := Vector3(-12.0, 0.0, 22.0)  # east of the shed, in the open
	add_flag(f, 1)
	await _shot_at(cam, f, Vector3(0, 0, -5), dir, "flag")
	filled[2] = true
	_send_peg()
	var board := (get_tree().get_first_node_in_group(&"pegboard_spots") as Node3D).global_position
	await _shot_at(cam, board, Vector3(0, -0.3, -2.5), dir, "pegboard")
	id = ""
	while id == "":
		await get_tree().create_timer(0.5).timeout
		for k in race.traps:
			if race.traps[k].kind == &"pit" and race.traps[k].state == &"set":
				id = k
	await _shot_at(cam, farm.targets[id].target_pos(), Vector3(0, 2.6, 1.6), dir, "clue_pit")
	get_tree().quit()


func _shot_at(cam: Camera3D, at: Vector3, off: Vector3, dir: String, name: String) -> void:
	cam.global_position = at + off + Vector3(0, 1.4, 0)
	cam.look_at(at + Vector3(0, 0.3, 0))
	for c in get_parent().get_children():  # the pause menu opens on focus loss
		if c is CanvasLayer and str(c.get_script().resource_path).ends_with("pause_menu.gd"):
			c.hide()
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
