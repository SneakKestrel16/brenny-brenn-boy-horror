class_name LoreProps
extends Node
## P5-48 (doc 11 s5, s6.1, s6.3): the road sign at the farm gate and the pinned 1958 notes, one per verb, at their places.
## Built in code on every peer from data/lore.json (like BarnSign), so nothing is synced and the CEO edits text in data.
## Text only: no image of the boy, nothing says the day is safe (doc 11 s1). Every text is physical (CEO 2026-10-10): a paper
## card pinned flat on a wall, or on a stake driven into the ground, with the Label3D lying on the card face (not a billboard).
## A note's anchor is a node path under the farm scene, so a moved prop (the well, P5-47) moves its note.
## Note record: offset = x/z metres from the anchor, y = height above ground; facing = yaw degrees (0 faces +z, 180 faces -z,
## 90 faces +x, -90 faces -x); mount = "wall" (card only) or "post" (card on a wooden stake).

const INK := Color(0.16, 0.11, 0.07)
const PAPER := Color(0.86, 0.8, 0.64)
const CHILD_INK := Color(0.2, 0.1, 0.35)
const WOOD := Color(0.32, 0.22, 0.13)
const NOTE_PIXEL := 0.005  ## m per font pixel: 30 px lines are 0.15 m, legible from about 5 m
const NOTE_WIDTH_M := 1.5
const READ_RANGE_M := 7.0  ## a note is drawn only this close, so the farm is not littered with distant text
const CARD_THICK := 0.03
const POST_W := 0.1


func _ready() -> void:
	var world := get_parent().get_node_or_null(^"World")
	if world == null or world.get_node_or_null(^"Buildings/Barn") == null:
		return  # Phase 1 farm: no gate sign, no notes
	_road_sign(world)
	for n: Dictionary in Data.record(&"lore", &"notes").get("notes", []):
		var anchor := world.get_node_or_null(NodePath(String(n.anchor))) as Node3D
		if anchor == null:
			push_warning("lore note %s: no anchor %s" % [n.id, n.anchor])
			continue
		var o: Array = n.offset
		var at := Vector3(anchor.global_position.x + float(o[0]), float(o[1]), anchor.global_position.z + float(o[2]))
		var face := float(n.get("facing", 0.0))
		var child := bool(n.get("child", false))
		var card := _card(world, "LoreNote_" + String(n.id), at, face, String(n.text), CHILD_INK if child else INK, PAPER, NOTE_PIXEL, 30, float(n.get("width", NOTE_WIDTH_M)))
		card.visibility_range_end = READ_RANGE_M
		if String(n.get("mount", "wall")) == "post":
			_post(world, at, face, 0.0, at.y + 0.3)


## Two boards on two posts: the old farm name (faded paint) over the bank's notice. Stacked, clear of each other and of the corn.
func _road_sign(world: Node) -> void:
	var rec := Data.record(&"lore", &"road_sign")
	var face := -90.0  # faces -x: read from the farm gate (105) looking east
	var xz: Array = rec.get("at", [110.0, -5.0])  # layout in data/lore.json: lane centre between the gate poles (105, -8 and -2)
	var sign_at := Vector3(float(xz[0]), 0.0, float(xz[1]))
	var notice := _card(world, "LoreRoadNotice", sign_at + Vector3(0, float(rec.get("notice_y", 3.4)), 0), face, String(rec.get("notice", "")), Color(0.35, 0.05, 0.05), Color(0.92, 0.9, 0.85), 0.0045, 64, 3.4)
	var title := _card(world, "LoreRoadTitle", sign_at + Vector3(0, float(rec.get("title_y", 4.85)), 0), face, String(rec.get("title", "")), Color(0.2, 0.12, 0.05), Color(0.62, 0.5, 0.3), 0.006, 96, 4.0)
	for c: Node3D in [notice, title]:
		c.visibility_range_end = 0.0
	var right := Vector3(0, 0, 1)  # along the board
	for side: float in [-float(rec.get("post_half", 2.0)), float(rec.get("post_half", 2.0))]:
		var at := sign_at + right * side
		_post(world, at, face, 0.0, float(rec.get("post_top", 5.5)))


## A stake behind a card: ground to just above the card. Sits 0.04 m behind the card plane so the card is never inside it.
func _post(world: Node, card_at: Vector3, face_deg: float, _unused: float, top: float) -> void:
	var yaw := deg_to_rad(face_deg)
	var back := -Vector3(sin(yaw), 0, cos(yaw)) * (CARD_THICK * 0.5 + POST_W * 0.5 + 0.005)
	var p := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(POST_W, top, POST_W)
	p.mesh = m
	p.material_override = _mat(WOOD)
	p.name = "LorePost"
	world.add_child(p)
	p.global_position = Vector3(card_at.x, top * 0.5, card_at.z) + back
	p.rotation.y = yaw


## Thin paper box with the text lying on its front face. The card centre is `at`; the label is sized from the wrapped text.
func _card(world: Node, nm: String, at: Vector3, face_deg: float, text: String, ink: Color, paper: Color, pixel: float, font_px: int, width_m: float) -> MeshInstance3D:
	var wrap_px := int(width_m / pixel)
	var sz := ThemeDB.fallback_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, wrap_px, font_px)
	var w := minf(sz.x, wrap_px) * pixel + 0.16
	var h := sz.y * pixel + 0.14
	var card := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, CARD_THICK)
	card.mesh = box
	card.material_override = _mat(paper)
	card.name = nm
	world.add_child(card)
	card.global_position = at
	card.rotation.y = deg_to_rad(face_deg)
	var l := Label3D.new()
	l.text = text
	l.position = Vector3(0, 0, CARD_THICK * 0.5 + 0.004)
	l.pixel_size = pixel
	l.font_size = font_px
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = false
	l.shaded = true
	l.modulate = ink
	l.outline_size = 0
	l.width = wrap_px
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(l)
	return card


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
