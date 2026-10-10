class_name TaintLook
extends RefCounted
## P3-08, doc 01 "The Taint" cue, doc 05 section 10, doc 07 section 8: how Taint looks. taint.gd calls in:
## `show_on` when a player's Taint changes (every peer), `mark` for a Taint source on the ground (every peer).
## - Hands and sleeves: two forearms under the camera (like the held props, so the owner sees them at the
##   bottom of the screen and everyone else sees them in front of the body), oil stained to the elbow. They
##   show only while Tainted: there is no hands model yet (3D Artist), so a clean pair would be new art.
## - Screen: the Tainted player alone gets edge smudges and a faint dark fog (taint_screen.gdshader).
## - Ground: leavings are an oil puddle, strange seeds a dark scatter, a dead crow a dark lump (placeholder
##   until its model). "Black stains underfoot" (P3-08 acceptance) is read as these sources (inference: no doc
##   names Tainted footprints; the Game Designer settles it).
## Nothing here is a light or emissive, and the screen fade is slow (doc 07 section 4.3).

const FADE_S := 3.0  ## placeholder: "change slowly" (doc 07 section 4.3)
const ARM_LEN := 0.47  ## tool_hands: elbow pivot to fingertip (P5-17 handoff, aabb z -0.47)
const HANDS := preload("res://game/render/taint_hands.gdshader")
const GROUND := preload("res://game/render/taint_ground.gdshader")
const SCREEN := preload("res://game/render/taint_screen.gdshader")


## Shows or hides `pl`'s stained hands, and on the local player fades the screen smudge in or out.
static func show_on(pl: Node3D, on: bool) -> void:
	var cam: Camera3D = pl.get("_cam")
	if cam == null:
		return
	var arms := cam.get_node_or_null(^"TaintArms") as Node3D
	if arms == null:
		arms = _arms(bool(pl.get("is_local")))
		cam.add_child(arms)
	arms.visible = on
	if not pl.get("is_local"):
		return
	var layer := pl.get_node_or_null(^"TaintSmudge") as CanvasLayer
	if layer == null:
		layer = _smudge()
		pl.add_child(layer)
	var rect := layer.get_child(0) as ColorRect
	if not rect.is_inside_tree():
		return
	var mat := rect.material as ShaderMaterial
	if rect.has_meta(&"fade"):
		(rect.get_meta(&"fade") as Tween).kill()
	var tw := rect.create_tween()
	rect.set_meta(&"fade", tw)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"strength", v),
			float(mat.get_shader_parameter(&"strength")), 1.0 if on else 0.0, FADE_S)


## Placeholder poses read from screenshots. Local: elbows low at the screen corners, fingers forward and in.
## Others: thicker and further out, so the hands clear the 0.35 m body capsule and read at a distance.
static func _arms(local: bool) -> Node3D:
	# P5-22: the tool_hands model (HandL/HandR, elbow pivots at +-0.19, arms along -Z) in the stained-sleeve shader.
	var arms := (load("res://assets/models/tool_hands.glb") as PackedScene).instantiate() as Node3D
	arms.name = "TaintArms"
	var mat := ShaderMaterial.new()
	mat.shader = HANDS
	mat.set_shader_parameter(&"arm_len", ARM_LEN)
	mat.set_shader_parameter(&"model_axis", true)
	for mi in arms.find_children("*", "MeshInstance3D"):
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if local:  # elbows low at the screen corners, fingers forward and up
		arms.position = Vector3(0, -0.5, -0.175)
		arms.rotation.x = deg_to_rad(28.0)
	else:  # others see them in front of the body, scaled out to clear the 0.35 m capsule
		arms.position = Vector3(0, -0.55, -0.25)
		arms.rotation.x = deg_to_rad(10.0)
		arms.scale = Vector3(1.4, 1.4, 1.0)
	return arms


static func _smudge() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "TaintSmudge"
	layer.layer = -1  # over the world and the post pass (-2, grain and vignette), under every UI layer (default 1): Taint is last in the stack (doc 07 s6)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SCREEN
	mat.set_shader_parameter(&"strength", 0.0)  # unset reads back as null
	rect.material = mat
	layer.add_child(rect)
	return layer


## A Taint source's look on the ground. The caller adds and places it (at ground height).
static func mark(kind: StringName, id := 0) -> Node3D:
	if kind == &"dead_crow":  # P5-22: prop_dead_crow replaces the dark lump
		var crow := (load("res://assets/models/prop_dead_crow.glb") as PackedScene).instantiate() as Node3D
		crow.name = "Taint_%s" % kind
		crow.rotation.y = id * 2.399  # the source id, so every peer lays the crow the same way
		return crow
	var mi := MeshInstance3D.new()
	mi.name = "Taint_%s" % kind
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := PlaneMesh.new()
	p.size = Vector2(1.1, 1.1) if kind == &"leavings" else Vector2(0.6, 0.6)
	mi.mesh = p
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	mat.set_shader_parameter(&"seed", randf())
	mat.set_shader_parameter(&"speckle", 1.0 if kind == &"strange_seeds" else 0.0)
	mi.material_override = mat
	mi.rotation.y = randf() * TAU
	return mi
