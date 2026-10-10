class_name HeldTools
extends Node
## P5-27: `tool_hoe` and `tool_whistle` in the hands, on every peer (children of the camera's held node, like the other
## P5-22 props, so the owner and everyone else see them at the same spot). Visual only; no input here.
## - Hoe: in hand while its owner holds a `plant` or `clear_plot` chore. The host watches the HoldRegistry (game/core/world_props.gd)
##   and sends `apply_tool` on a change; a client never decides it.
## - Whistle: raised for WHISTLE_SHOW_S when `apply_whistle` names the owner (the host's accepted whistle, so a refused one shows nothing).

const HOE_VERBS: Array[StringName] = [&"plant", &"clear_plot"]
const WHISTLE_SHOW_S := 1.0  ## placeholder: about the length of a short whistle
const MODEL := "res://assets/models/%s.glb"

var peer := 0
var _hoe: Node3D
var _whistle: Node3D
var _whistle_until := 0.0


## Adds the component to `player` (its `peer`), the props under `held`.
static func attach(player: Node, held: Node3D) -> void:
	var h := HeldTools.new()
	h.name = "HeldTools"
	h.peer = player.peer
	h._hoe = h._prop(held, "tool_hoe", Vector3(0.15, 0.0, -0.3), Vector3(-70.0, 0.0, 0.0), 0.75)  # 1.39 m, stands upright: blade low, handle away
	h._whistle = h._prop(held, "tool_whistle", Vector3(-0.1, 0.25, -0.35), Vector3(0.0, 0.0, 0.0), 2.5)  # 0.09 m: scaled up to read in the hand
	player.add_child(h)


func _prop(held: Node3D, model: String, pos: Vector3, rot_deg: Vector3, s: float) -> Node3D:
	var m := (load(MODEL % model) as PackedScene).instantiate() as Node3D
	m.position = pos
	m.rotation_degrees = rot_deg
	m.scale = Vector3.ONE * s
	m.visible = false
	held.add_child(m)
	return m


func _ready() -> void:
	Net.apply_received.connect(_on_apply)


func _on_apply(what: StringName, args: Array) -> void:
	if what not in [&"tool", &"whistle"] or int(args[0]) != peer:
		return
	if what == &"tool":
		_hoe.visible = args[1] == &"hoe"
	else:
		_whistle.visible = true
		_whistle_until = Time.get_ticks_msec() / 1000.0 + WHISTLE_SHOW_S


func _process(_delta: float) -> void:
	if _whistle.visible and Time.get_ticks_msec() / 1000.0 >= _whistle_until:
		_whistle.visible = false
