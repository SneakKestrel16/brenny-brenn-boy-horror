extends Control
## P4-24 (CEO session, OPEN_ISSUES item 5): a north-up map of the whole farm in the top-right corner.
## Read from the level's own nodes when the HUD is built (doc 04 names: `Ground/Floor`, `Buildings/*`,
## `Regions/field_*` and `corn_*`, groups `plot_spots`, `well`, `store_crate`, `sell_box`, `cart`), so a
## layout change shows without editing this file. Shows the local player's arrow and every
## placed flag as a small red pennant (P4-24, P4-33; where the flag is now, so a moved flag shows moved).
## Never the creature: nothing here reads the `creature` group. A pure reader, local only.
## Cheap: the farm is drawn once on this Control; only the `_dyn` child (arrow, cart, flags) redraws each frame.
## No teammate dots (D-141, CEO: "dont show players on the minimap").

const SIZE := Vector2(264, 172)  ## px; the 240 x 150 m full farm at about 1 px/m (placeholder)
const PAD := 6.0
const BG := Color(0, 0, 0, 0.55)
const GROUND := Color(0.22, 0.25, 0.18, 0.8)
const CORN := Color(0.42, 0.40, 0.16, 0.8)
const FIELD := Color(0.45, 0.32, 0.20, 0.8)
const PLOT := Color(0.62, 0.46, 0.28)
const BUILDING := Color(0.55, 0.30, 0.22)
const PROPS := [[&"well", "W", Color(0.4, 0.8, 1.0)], [&"store_crate", "S", Color(1.0, 0.85, 0.3)], [&"sell_box", "T", Color(0.9, 0.9, 0.9)]]

var player: Node3D  ## the local Player
var _world: Node3D
var _rect := Rect2()  ## world x/z covered by the map
var _scale := 1.0
var _dyn: Control
var _boxes: Array = []  ## [Rect2 in px, Color]
var _props: Array = []  ## [px, letter, Color]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIZE.x - 16
	offset_right = -16
	offset_top = 16
	offset_bottom = 16 + SIZE.y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dyn = Control.new()
	_dyn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dyn.draw.connect(_draw_dyn)
	add_child(_dyn)
	_world = get_tree().current_scene.get_node_or_null(^"World") if get_tree().current_scene else null
	if _world == null:
		return
	var ground := _world.get_node_or_null(^"Ground/Floor")
	var r := _box(ground) if ground else Rect2()
	_rect = r
	_scale = minf((SIZE.x - PAD * 2.0) / maxf(r.size.x, 1.0), (SIZE.y - PAD * 2.0) / maxf(r.size.y, 1.0))
	_boxes.append([_px_rect(r), GROUND])
	var regions := _world.get_node_or_null(^"Regions")
	for n in regions.get_children() if regions else []:
		if String(n.name).begins_with("corn"):
			_boxes.append([_px_rect(_box(n)), CORN])
		elif String(n.name).begins_with("field"):
			_boxes.append([_px_rect(_box(n)), FIELD])
	for m in get_tree().get_nodes_in_group(&"plot_spots"):
		_boxes.append([Rect2(_px(m.global_position) - Vector2(1.5, 1.5), Vector2(3, 3)), PLOT])
	var buildings := _world.get_node_or_null(^"Buildings")
	for n in buildings.get_children() if buildings else []:
		_boxes.append([_px_rect(_box(n)), BUILDING])
	for g: Array in PROPS:
		for n in get_tree().get_nodes_in_group(g[0]):
			_props.append([_px((n as Node3D).global_position), g[1], g[2]])


## World x/z bounds of every mesh and box shape under `n` (n included).
func _box(n: Node) -> Rect2:
	var out := AABB()
	var first := true
	for c in [n] + n.find_children("*", "", true, false):
		var a := AABB()
		if c is MeshInstance3D and c.mesh:
			a = c.global_transform * c.mesh.get_aabb()
		elif c is CollisionShape3D and c.shape is BoxShape3D:
			a = c.global_transform * AABB(-c.shape.size / 2.0, c.shape.size)
		else:
			continue
		out = a if first else out.merge(a)
		first = false
	return Rect2(out.position.x, out.position.z, out.size.x, out.size.z)


func _px(p: Vector3) -> Vector2:
	return Vector2(PAD, PAD) + (Vector2(p.x, p.z) - _rect.position) * _scale


func _px_rect(r: Rect2) -> Rect2:
	return Rect2(_px(Vector3(r.position.x, 0, r.position.y)), r.size * _scale)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	for b: Array in _boxes:
		draw_rect(b[0], b[1])
	var font := ThemeDB.fallback_font
	for p: Array in _props:
		draw_rect(Rect2(p[0] - Vector2(2.5, 2.5), Vector2(5, 5)), p[2])
		draw_string_outline(font, p[0] + Vector2(4, 4), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		draw_string(font, p[0] + Vector2(4, 4), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, p[2])


func _process(_delta: float) -> void:
	_dyn.queue_redraw()


func _draw_dyn() -> void:
	var cart := get_tree().get_first_node_in_group(&"cart")
	if cart:
		var cp := _px((cart.get_parent() as Node3D).global_position)
		_dyn.draw_rect(Rect2(cp - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.6, 0.2))
		_dyn.draw_string(ThemeDB.fallback_font, cp + Vector2(4, 4), "C", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.6, 0.2))
	var sweep := get_tree().get_first_node_in_group(&"trap_sweep")
	for f in sweep.flags if sweep else []:  # P4-33: a pole and a pennant, about 7 px tall
		var fp := _px(f.pos)
		_dyn.draw_line(fp, fp - Vector2(0, 7), Color(0.9, 0.85, 0.75), 1.0)
		_dyn.draw_colored_polygon(PackedVector2Array([fp - Vector2(0, 7), fp + Vector2(5, -5), fp - Vector2(0, 3)]), Color(0.95, 0.12, 0.08))
	if player:  # the local arrow, pointing where the camera faces (yaw 0 = north, -z)
		var p := _px(player.global_position)
		var f := Vector2(-sin(player.yaw), -cos(player.yaw))
		var s := Vector2(-f.y, f.x)
		_dyn.draw_colored_polygon(PackedVector2Array([p + f * 7.0, p - f * 4.0 + s * 4.0, p - f * 4.0 - s * 4.0]), Color.WHITE)
