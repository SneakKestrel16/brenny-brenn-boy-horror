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
var _crop_node: Node3D  ## P5-22: the crop_<id>_<stage>.glb now standing in the plot
var _crop_key := ""
var _glow: Node3D  ## the ripe moonflower's steady 3 m light (doc 07 s5)
var _soil: Node3D

const SOIL_Y := 0.18  ## crop models' origin is the soil surface; crop_plot.glb's top (P5-16 handoff)
const MODEL := "res://assets/models/crop_%s_%s.glb"


func _ready() -> void:
	var night := Crops.night_crop()
	bed = night != &"" and String(get_parent().get_meta(&"field", "")) == String(night)
	var slab := get_parent().get_node_or_null(^"Mesh") as MeshInstance3D  # P5-13: the scene's flat slab becomes crop_plot.glb
	if slab:
		slab.visible = false
		_soil = (load("res://assets/models/crop_plot.glb") as PackedScene).instantiate()
		get_parent().add_child(_soil)
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


## Which crop model shows (P5-22, doc 07 s11.5). Growing: stage 0 dry, +1 once watered, +1 per growth day, never the
## last (ripe) stage; ripe: the last stage (3 for turnip and pumpkin, 2 for the moonflower); wilted and dead have their own.
func _model_key() -> String:
	var c := String(crop)
	var last := 3 if ResourceLoader.exists(MODEL % [c, "stage3"]) else 2
	match state:
		&"growing": return "stage%d" % mini(age + (1 if watered else 0), last - 1)
		&"ripe": return "stage%d" % last
		&"wilted": return "wilted"
		&"dead": return "taint" if ResourceLoader.exists(MODEL % [c, "taint"]) else "rotten"
	return ""


func _refresh() -> void:
	if _soil:  # dry or wet soil: the glb's vertex colours, darkened and cooled when watered (doc 07 s11, `mat_soil_wet`)
		for mi in _soil.find_children("*", "MeshInstance3D", true, false):
			var src := (mi as MeshInstance3D).mesh.surface_get_material(0)
			var key := &"soil_wet" if watered else &"soil_dry"  # one dry and one wet copy, kept on the shared source material
			if not src.has_meta(key):
				var own := src.duplicate() as StandardMaterial3D
				own.albedo_color = Color(0.55, 0.58, 0.7) if watered else Color.WHITE
				src.set_meta(key, own)
			(mi as MeshInstance3D).set_surface_override_material(0, src.get_meta(key))
	var k := _model_key()
	var path := MODEL % [crop, k]
	var want := "%s/%s" % [crop, k] if k != "" and ResourceLoader.exists(path) else ""
	if want != _crop_key:
		_crop_key = want
		if _crop_node:
			_crop_node.queue_free()
			_crop_node = null
		if want != "":
			_crop_node = (load(path) as PackedScene).instantiate() as Node3D
			_crop_node.position.y = SOIL_Y
			get_parent().add_child(_crop_node)
	# Moonflower glow: steady, no pulse. Own power (lights.gd skips it); only the ghost system dims it.
	var glowing := crop == &"moonflower" and want == "moonflower/stage2"
	if glowing and _glow == null:
		_glow = Node3D.new()
		_glow.set_meta(&"own_power", true)
		var rig := LightRig.new()
		rig.color = Color("7FE6D8")
		rig.range_m = 3.0
		rig.energy = 0.5
		rig.ground_pool = false
		_glow.add_child(rig)
		_glow.position.y = 0.4
		rig.ready.connect(func() -> void:  # the flower is the lamp: hide the rig's gray-box bulb
			for m in rig.get_children():
				if m is MeshInstance3D:
					(m as MeshInstance3D).visible = false)
		get_parent().add_child(_glow)
	elif not glowing and _glow:
		_glow.queue_free()
		_glow = null
