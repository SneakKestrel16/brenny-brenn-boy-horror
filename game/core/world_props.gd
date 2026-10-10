class_name WorldProps
extends Node
## P5-27 (doc 07 s11 and s4): the farm's dressing that follows the clock. Every peer, from the same clock, so nothing is synced.
## - `prop_window_glow` on each `WindowGlow_n` empty of the barn, farmhouse and tool shed: shown at dusk, night and harvest moon
##   while the generator has power. Steady emission, shown or hidden, never animated (doc 01 "Photosensitivity safety").
## - A LightRig at each `prop_road_lamp` `LightRig` empty: on at dusk, night and harvest moon (own power, the road is not on the
##   generator; lights.gd drives it, never set here). Its gray-box bulb is hidden, the lamp glass is the model's.
## - A perched `animal_crow` (clip `idle`, looped) at each `crow_perches` marker. The ghost's crow and the fake-out burst use the
##   same markers; the models are scenery.
## Only the full farm has these nodes; Phase 1 finds none and does nothing.

const Lights := preload("res://game/core/lights.gd")
const WINDOW_SIZE := {"Barn": Vector2(0.9, 1.1), "Farmhouse": Vector2(0.8, 1.3), "ToolShed": Vector2(0.7, 0.7)}  ## window w x h in metres (build_p5_14.py)
const NIGHT_PHASES: Array[StringName] = [&"dusk", &"night", &"harvest_moon"]
const LAMP_FADE_S := 0.5  ## a little over LightRig.SLEW_S, so the rig has faded out before it is hidden

var _windows: Array[Node3D] = []
var _lamps: Array[Node3D] = []
var _lamp_on := false
var _since := 0.0
var _gen: Node
var _tools := {}  ## host: peer -> the tool last announced


func _ready() -> void:
	var world := get_parent().get_node_or_null(^"World")
	if world == null:
		return
	var glow := load("res://assets/models/prop_window_glow.glb") as PackedScene
	for e: Node3D in world.find_children("WindowGlow_*", "Node3D", true, false):
		var m := glow.instantiate() as Node3D
		var size: Vector2 = WINDOW_SIZE.get(String(e.get_parent().get_parent().name), Vector2.ONE)
		m.scale = Vector3(size.x, size.y, 1.0)  # the empty's transform as is; the card is 1 m nominal
		e.add_child(m)
		_windows.append(m)
	for e: Node3D in world.find_children("LightRig", "Node3D", true, false):
		if e.get_parent().name.begins_with("RoadLamp"):
			_lamps.append(_make_lamp(e))
	var crow := load("res://assets/models/animal_crow.glb") as PackedScene
	for i in get_tree().get_nodes_in_group(&"crow_perches").size():
		var perch := get_tree().get_nodes_in_group(&"crow_perches")[i] as Node3D
		var c := crow.instantiate() as Node3D
		var ap := c.find_children("*", "AnimationPlayer")[0] as AnimationPlayer
		ap.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
		ap.play(&"idle")
		c.rotation.y = i * 2.4  # fixed per index: the same on every peer
		perch.add_child(c)
	_gen = get_tree().get_first_node_in_group(&"generator_logic")
	_update()


func _make_lamp(at: Node3D) -> Node3D:
	var holder := Node3D.new()
	holder.set_meta(&"own_power", true)  # lights.gd skips it: the road lamp is not on the generator
	var rig := LightRig.new()
	rig.range_m = 7.0
	rig.energy = 1.0
	holder.add_child(rig)
	rig.ready.connect(func() -> void:
		for m in rig.get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).mesh is BoxMesh:
				(m as MeshInstance3D).visible = false)  # the lamp glass is the model's
	holder.visible = false
	at.add_child(holder)
	return holder


func _process(delta: float) -> void:
	if Game.is_host():
		_watch_tools()
	_since += delta
	if _since >= 0.5:  # the generator's fuel runs out between signals on the host, so look twice a second
		_since = 0.0
		_update()


func _update() -> void:
	var night := Clock.phase in NIGHT_PHASES
	var windows_on: bool = night and (_gen == null or _gen.powered())
	for w in _windows:
		w.visible = windows_on
	if night != _lamp_on:
		_lamp_on = night
		for h in _lamps:
			h.visible = true
			Lights.set_own(h.get_child(0), night)
		if not night:
			get_tree().create_timer(LAMP_FADE_S).timeout.connect(func() -> void:
				if not _lamp_on:
					for h in _lamps:
						h.visible = false)


## Host: `apply_tool` for each player whose chore needs the hoe, when it starts or ends (game/player/held_tools.gd).
func _watch_tools() -> void:
	var farm := get_tree().get_first_node_in_group(&"farm")
	if farm == null or farm.registry == null:
		return
	var now := {}
	for p: int in farm.registry.holds:
		if HeldTools.HOE_VERBS.has(farm.registry.Interactable.base(farm.registry.holds[p].verb)):
			now[p] = &"hoe"
	for p: int in _tools.keys() + now.keys():
		var t: StringName = now.get(p, &"")
		if _tools.get(p, &"") != t:
			_tools[p] = t
			Net.to_peers(&"apply_tool", [p, t])
			Net.apply_received.emit(&"tool", [p, t])
