class_name TrapGlint
extends Node3D
## The `trap_glint` card on a set bear trap (doc 01 "Night Traps": glinting metal; P5-22, doc 07 s11.4).
## Never a blink: its size is a pure function of where the viewer stands (view elevation and distance), so it only
## changes while the player moves. It always faces the camera about Y, floats 0.3 m over the trap and is not emissive.

const MIN_M := 2.0  ## closer than this the trap itself reads
const MAX_M := 14.0  ## farther than this the card is gone
const FULL_ELEV := 0.35  ## view elevation (rad above the horizon) at and below which the card is full size

var _card: Node3D


func _ready() -> void:
	_card = (load("res://assets/models/trap_glint.glb") as PackedScene).instantiate()
	_card.position.y = 0.3
	add_child(_card)
	set_process(true)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_visible_in_tree():
		return
	var d := cam.global_position - _card.global_position
	var flat := Vector2(d.x, d.z).length()
	if flat < 0.01:
		return
	var elev := atan2(d.y, flat)
	var by_angle := 1.0 - smoothstep(FULL_ELEV, 1.2, elev)  # looking down from above hides it
	var by_dist := smoothstep(MIN_M, MIN_M + 2.0, flat) * (1.0 - smoothstep(MAX_M - 4.0, MAX_M, flat))
	_card.scale = Vector3.ONE * maxf(by_angle * by_dist, 0.001)
	_card.rotation.y = atan2(d.x, d.z)
