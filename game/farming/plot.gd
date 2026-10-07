extends "res://game/interaction/interactable.gd"
## Doc 05 section 9: one plot. States: empty, growing, ripe (wilted/dead are later phases). Turnips only
## (Phase 1, doc 02 section 5). Visible state is the information; no HUD.

var state: StringName = &"empty"
var watered := false  ## watered_today
var age := 0  ## growth days earned
var locked := false  ## the upgrade row starts locked (doc 04 section 9)
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	(get_parent() as Node3D).add_child(_mesh)
	_refresh()


func verbs_for(_st: Dictionary) -> Array[StringName]:
	if locked:
		return []
	match state:
		&"empty": return [&"plant"]
		&"growing": return [] if watered else [&"water"]
		&"ripe": return [&"harvest"]
	return []


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if locked:
		return &"locked"
	match verb:
		&"plant":
			return &"" if state == &"empty" else &"not_empty"
		&"water":
			if state != &"growing":
				return &"not_growing"
			if watered:
				return &"already_watered"
			return &"" if int(st.get("can", 0)) > 0 else &"can_empty"
		&"harvest":
			if state != &"ripe":
				return &"not_ripe"
			return &"" if int(st.get("bag", 0)) < int(Data.value(&"labor", &"carry", &"capacity")) else &"bag_full"
	return &"no_such_verb"


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	var pos := target_pos()
	match verb:
		&"plant":
			state = &"growing"
			watered = false
			age = 0
			NoiseBus.emit_kind(&"tool_plant", pos, peer)
		&"water":
			watered = true
			st.can = int(st.can) - 1
			NoiseBus.emit_kind(&"tool_water", pos, peer)  # noisy can: mult 1.0 (quiet can x0.5 is bought, later)
		&"harvest":
			state = &"empty"
			watered = false
			age = 0
			st.bag = int(st.bag) + 1
			NoiseBus.emit_kind(&"tool_harvest", pos, peer)
	farm.plot_changed(self)


## Host, at dawn: a crop grows one day only if it was watered the day before (doc 02 section 5).
func advance_day() -> void:
	if state == &"growing" and watered:
		age += 1
		if age >= int(Data.value(&"crops", &"turnip", &"grow_days")):
			state = &"ripe"
	watered = false
	farm.plot_changed(self)


func apply_state(p_state: StringName, p_watered: bool, p_age: int) -> void:
	state = p_state
	watered = p_watered
	age = p_age
	_refresh()


## Placeholder look until the Technical Artist's plot art: green sprout, darker when watered, big orange when ripe.
func _refresh() -> void:
	if _mesh == null:
		return
	var m := StandardMaterial3D.new()
	var h := 0.0
	match state:
		&"growing":
			h = 0.3
			m.albedo_color = Color(0.1, 0.3, 0.6) if watered else Color(0.3, 0.7, 0.2)
		&"ripe":
			h = 0.6
			m.albedo_color = Color(0.9, 0.6, 0.2)
	_mesh.visible = h > 0.0
	(_mesh.mesh as BoxMesh).size = Vector3(0.6, maxf(h, 0.01), 0.6)
	_mesh.position.y = h / 2.0
	_mesh.material_override = m
