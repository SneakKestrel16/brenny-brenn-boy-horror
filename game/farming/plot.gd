extends "res://game/interaction/interactable.gd"
## Doc 05 section 9: one plot. States: empty, growing, ripe, wilted, dead. Any crop in crops.json (P4-04,
## doc 02 section 5); the crop's numbers come from the table, no crop name lives here. A field plot plants the
## crop the player picked (`plant:<crop>`, plain `plant` is the default seed); the night-crop bed (the plot
## marker's `field` meta equals the night crop's id) plants only that crop. Planting uses one of the team's
## seeds bought at the crate (P4-22, D-093). Visible state is the information.

const Crops := preload("res://game/farming/crops.gd")

var state: StringName = &"empty"
var watered := false  ## watered_today
var age := 0  ## growth days earned
var crop: StringName = &""  ## what is in the ground (empty while `state` is `empty`)
var locked := false  ## the upgrade row starts locked (doc 04 section 9)
var bed := false  ## the night-crop bed (doc 04 section 5.2)
var taint_id := 0  ## host: the Taint source a dead crop left (doc 01 Crops: moonflower)
var _mesh: MeshInstance3D


func _ready() -> void:
	var night := Crops.night_crop()
	bed = night != &"" and String(get_parent().get_meta(&"field", "")) == String(night)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	(get_parent() as Node3D).add_child(_mesh)
	_refresh()


func verbs_for(_st: Dictionary) -> Array[StringName]:
	if locked:
		var refuse: Array[StringName] = [&"plant"]  # P2-24: offer a verb so the hold is refused with "locked"
		return refuse
	match state:
		&"empty":
			var pick: StringName = farm.planting_seed() if farm and not bed else &""
			var v: Array[StringName] = [&"plant" if pick == &"" or pick == Crops.default_seed() else StringName("plant:" + pick)]
			return v
		&"growing":
			var out: Array[StringName] = []
			if not watered:
				out.append(&"water_quiet" if farm and farm.store.owns(Game.local_peer(), &"quiet_watering_can") else &"water")  # P4-06
			return out
		&"ripe": return [&"harvest"]
		&"wilted", &"dead": return [&"clear_plot"]
	return []


## The crop a `plant` verb puts in: the bed's night crop, or the picked seed, or the default seed.
func crop_for(verb: StringName) -> StringName:
	if bed:
		return Crops.night_crop()
	var s := String(verb)
	return StringName(s.get_slice(":", 1)) if ":" in s else Crops.default_seed()


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if locked:
		return &"locked"
	match base(verb):
		&"plant":
			if state != &"empty":
				return &"not_empty"
			var c := crop_for(verb)
			var r := Crops.rec(c)
			if r.is_empty() or (String(r.harvest_phase) == "night") != bed:
				return &"wrong_crop"
			if not Crops.is_unlocked(c, Clock.day):
				return &"locked_crop"
			return &"" if farm.store.seed_count(c) > 0 else &"no_seeds"
		&"water", &"water_quiet":
			if base(verb) == &"water_quiet" and not farm.store.owns(int(st.get("peer", 0)), &"quiet_watering_can"):
				return &"no_quiet_can"
			if st.get("held_kind", &"") != &"water":
				return &"no_can"
			if state != &"growing":
				return &"not_growing"
			if watered:
				return &"already_watered"
			return &"" if int(st.get("can", 0)) > 0 else &"can_empty"
		&"harvest":
			if state != &"ripe":
				return &"not_ripe"
			return &"" if int(st.get("bag", 0)) < Quirks.carry_cap(st) else &"bag_full"  # P5-09 Hoarding disorder
		&"clear_plot":
			return &"" if state in [&"wilted", &"dead"] else &"not_dead"
	return &"no_such_verb"


func recheck(verb: StringName, st: Dictionary) -> StringName:
	return can_start(verb, st)  # P4-18/Q-160: another hold used the last seed, or finished first on this plot


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	var pos := target_pos()
	match base(verb):
		&"plant":
			crop = crop_for(verb)
			farm.store.use_seed(crop)  # D-093: paid for at the crate, not here
			state = &"growing"
			watered = false
			age = 0
			NoiseBus.emit_kind(&"tool_plant", pos, peer)
		&"water", &"water_quiet":
			watered = true
			st.can = int(st.can) - 1
			NoiseBus.emit_kind(&"tool_water", pos, peer, 0.5 if base(verb) == &"water_quiet" else 1.0)  # doc 03 s3.1: the quiet can x0.5
			_ripen_at_night()
		&"harvest":
			Crops.bag_add(st, crop)
			if Roles.harvest_bonus(st):  # P4-09 Farmer: +1 crop every 5th harvest (may pass bag capacity by one)
				Crops.bag_add(st, crop)
			Log.event(&"harvest", {"player": peer, "plot": id, "crop": String(crop)})
			_reset()
			NoiseBus.emit_kind(&"tool_harvest", pos, peer)
		&"clear_plot":
			_reset()
	farm.plot_changed(self)


func _reset() -> void:
	if taint_id > 0:
		farm.get_tree().get_first_node_in_group(&"taint").remove_source(taint_id)
		taint_id = 0
	state = &"empty"
	crop = &""
	watered = false
	age = 0


## What the crop in the ground is worth if sold now (trample damage, the end-of-season sale at a share).
func sell_value() -> int:
	return Crops.sell(crop) if state in [&"growing", &"ripe"] else 0


## Host: a night crop that is grown and watered ripens once night falls (doc 01 Crops: picked at night).
func _ripen_at_night() -> void:
	if state == &"growing" and watered and Clock.phase in [&"night", &"harvest_moon"] and bed and age >= int(Crops.rec(crop).grow_days):
		state = &"ripe"


## Host, on a phase change.
func on_phase(ph: StringName) -> void:
	if ph in [&"night", &"harvest_moon"] and bed:
		_ripen_at_night()
		farm.plot_changed(self)


## Host, dawn step 5: a night crop wilts. Picked it is gone; ripe and left it is dead and Tainting; never grown
## it is just wilted (doc 01 Crops, doc 02 section 5). True when this plot changed.
func dawn_wilt() -> bool:
	if state not in [&"growing", &"ripe"] or not bool(Crops.rec(crop).get("wilts_at_dawn", false)):
		return false
	var dead := state == &"ripe"
	state = &"dead" if dead else &"wilted"
	watered = false
	if dead and bool(Crops.rec(crop).get("dead_plot_taints", false)):
		taint_id = farm.get_tree().get_first_node_in_group(&"taint").add_source(&"dead_plot", target_pos())
	farm.plot_changed(self)
	return true


## Host, at day start: a crop grows one day only if it was watered the day before (doc 02 section 5).
func advance_day() -> void:
	if state == &"growing" and watered and not bed:
		age += 1
		if age >= int(Crops.rec(crop).get("grow_days", 1)):  # a test that sets `growing` by hand has no crop
			state = &"ripe"
	watered = false
	farm.plot_changed(self)


## `p_state` may carry the crop as `state:crop` (plot_changed has no crop argument, Q-085).
func apply_state(p_state: StringName, p_watered: bool, p_age: int) -> void:
	var s := String(p_state)
	state = StringName(s.get_slice(":", 0))
	crop = StringName(s.get_slice(":", 1)) if ":" in s else &""
	watered = p_watered
	age = p_age
	_refresh()


func wire_state() -> StringName:
	return StringName("%s:%s" % [state, crop]) if crop != &"" and state != &"empty" else state


## Placeholder look until the Technical Artist's plot art: a sprout in the crop's own hue, blue when watered,
## big when ripe, grey when wilted, black when dead.
func _refresh() -> void:
	if _mesh == null:
		return
	var m := StandardMaterial3D.new()
	var h := 0.0
	var hue := fposmod(float(hash(String(crop))), 360.0) / 360.0
	match state:
		&"growing":
			h = 0.3
			m.albedo_color = Color(0.1, 0.3, 0.6) if watered else Color.from_hsv(hue, 0.7, 0.7)
		&"ripe":
			h = 0.6
			m.albedo_color = Color.from_hsv(hue, 0.8, 0.95)
		&"wilted":
			h = 0.15
			m.albedo_color = Color(0.45, 0.4, 0.3)
		&"dead":
			h = 0.2
			m.albedo_color = Color(0.05, 0.03, 0.05)
	_mesh.visible = h > 0.0
	(_mesh.mesh as BoxMesh).size = Vector3(0.6, maxf(h, 0.01), 0.6)
	_mesh.position.y = h / 2.0
	_mesh.material_override = m
