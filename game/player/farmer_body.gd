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
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name == "mat_farmer_overalls":
				var own := mat.duplicate() as StandardMaterial3D
				own.albedo_color = colour(slot)
				m.set_surface_override_material(i, own)


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
