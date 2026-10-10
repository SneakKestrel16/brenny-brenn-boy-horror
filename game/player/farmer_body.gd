extends Node3D
## P5-13 (D-154, D-159, doc 07 s11.7): the rigged farmer, `char_farmer.glb`, as a node. Front -Z, origin at the
## feet. Plays the glb's animations (idle, walk, run, crouch loop; interact and the emotes are one-shots) and
## tints the `mat_farmer_overalls` surface with the player's colour. The glb's materials are shared between
## instances, so each tinted surface gets its own copy (a surface override).

const MODEL := preload("res://assets/models/char_farmer.glb")
## D-159 (Q-267): up to 6 players. Index = slot.
const COLOURS: Array[Color] = [Color("C04040"), Color("4070C0"), Color("D0B040"), Color("50A050"), Color("8050B0"), Color("D07830")]
const LOOPED: Array[StringName] = [&"idle", &"walk", &"run", &"crouch"]

var _ap: AnimationPlayer
var _slot := 0
var _overalls := Color(0, 0, 0, 0)  ## P5-05 cosmetic overalls colour; alpha 0 = none
var _stained := false  ## P5-23 Taint: sleeves stained
var _overlay: Array[MeshInstance3D] = []
var _att: BoneAttachment3D  ## P5-05 cosmetic hat on the `hat` bone
var _head_mod: HeadScaler  ## P5-42: made on first use


func _init(slot: int = 0) -> void:
	var root: Node = MODEL.instantiate()
	add_child(root)
	_ap = root.find_children("*", "AnimationPlayer", true, false)[0]
	for n in LOOPED:
		_ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	tint(slot)


func _ready() -> void:
	_ap.play(&"idle")


static func colour(slot: int) -> Color:
	return COLOURS[posmod(slot, COLOURS.size())]


func tint(slot: int) -> void:
	_slot = slot
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name == "mat_farmer_overalls":
				var own := mat.duplicate() as StandardMaterial3D
				own.albedo_color = _overalls if _overalls.a > 0.0 else colour(slot)
				m.set_surface_override_material(i, own)
			elif mat and mat.resource_name == "mat_farmer_sleeves":
				var sl: StandardMaterial3D = null
				if _stained:
					sl = mat.duplicate() as StandardMaterial3D
					sl.albedo_color = Color(0.06, 0.05, 0.05)
					sl.roughness = 0.35  # oil: a little sheen
				m.set_surface_override_material(i, sl)


## P5-23 (doc 01 "The Taint", doc 07 s11.7): Taint stains the `mat_farmer_sleeves` surface (sleeves, hands) dark and oily.
## Not emissive, no animation (doc 07 s4.3).
func stain(on: bool) -> void:
	_stained = on
	tint(_slot)


## P5-05 (doc 02 s21.5): cosmetic overalls colour; alpha 0 keeps the player colour (D-159).
## `id` (the cosmetic id) also brings its skinned pattern overlay meshes (`Cosmetics.attach_overlay`); empty removes them.
func set_overalls(c: Color, id: StringName = &"") -> void:
	_overalls = c
	tint(_slot)
	for m in _overlay:
		m.get_parent().remove_child(m)
		m.queue_free()
	_overlay.clear()
	var cos := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Cosmetics")  # by path: -s test scripts compile this without autoloads
	if id != &"" and cos:
		_overlay = cos.attach_overlay(find_children("*", "Skeleton3D", true, false)[0], id)


## The overlay meshes of the worn overalls, on the Skeleton3D.
func overlay() -> Array[MeshInstance3D]:
	return _overlay


## P5-05: a cosmetic hat on the `hat` bone (origin at the hat's band bottom); null takes it off.
func wear_hat(hat: Node3D) -> void:
	if _att:
		_att.get_parent().remove_child(_att)  # frees the name now
		_att.queue_free()
		_att = null
	if hat == null:
		return
	var skel := find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_att = BoneAttachment3D.new()
	_att.name = "HatAttach"
	skel.add_child(_att)
	_att.bone_name = "hat"
	_att.add_child(hat)


## P5-42 (dev toy big heads): the head bone, and so the head texture and any hat, `s` times its size.
func set_head_scale(s: float) -> void:
	if _head_mod == null:
		var sk := find_children("*", "Skeleton3D", true, false)
		if sk.is_empty():
			return  # no rig: nothing to scale
		_head_mod = HeadScaler.new()
		sk[0].add_child(_head_mod)
	_head_mod.factor = s


## A looping animation (no-op when it already plays). `speed` scales it (crouch-walking plays `crouch` faster).
func loop(anim: StringName, speed: float = 1.0) -> void:
	_ap.speed_scale = speed
	if _ap.current_animation != anim:
		_ap.play(anim, 0.15)


## A one-shot (emote, interact); returns its length in seconds. The caller calls `loop` again afterwards.
func shot(anim: StringName) -> float:
	_ap.speed_scale = 1.0
	_ap.play(anim, 0.1)
	return _ap.get_animation(anim).length


func has_anim(anim: StringName) -> bool:
	return _ap.has_animation(anim)
