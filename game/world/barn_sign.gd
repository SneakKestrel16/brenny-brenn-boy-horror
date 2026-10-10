class_name BarnSign
extends Node
## P5-34 (CEO STOP 6): the how-to-play signboard on the barn's west wall, readable from a few metres. Text is doc 01
## (Core Loop, The Taint, Night Traps, Nights, Season and Numbers), no new rules. Built in code on every peer from static
## text, so nothing is synced. Only the full farm has a barn; Phase 1 finds none and does nothing.

const CENTRE := Vector3(-7.7, 2.45, -10.0)  ## on the inside of the west wall, between the spawns and the lantern
const BOARD := Vector2(4.8, 4.3)  ## m
const PIXEL_SIZE := 0.0036  ## m per font pixel: 36 px lines are 0.13 m, legible from about 5 m
const LEFT := "HOW TO PLAY\n\nGOAL\nPay the bank in 7 days. Make the final payment and get the festival cart out the gate with someone alive.\n\nDAY\nRead the pegboard. Sweep and disarm traps. Plant, water, harvest, sell at the town stand.\n\nDUSK\nThe bell rings three times. Harvest and top up the generator."
const RIGHT := "NIGHT\nThe creature hunts and copies voices. It never enters a lit building. Keep the generator fuelled (the drum by the shed is free). Moonflowers are picked in the dark only.\n\nCORRUPTED\nCreature leavings, stolen tools, items left out at dusk and unpicked moonflowers. Wash at the well: about 10 s of noisy pumping.\n\nTRAPS\nBear trap: pry free, a teammate helps. Pit: fill it. Disarm kneeling still. Flags mark rows, free and honest.\n\nDAWN\nSelling, medical bill, payments, farm damage: all on the Dawn Report."


func _ready() -> void:
	var barn := get_parent().get_node_or_null(^"World/Buildings/Barn")
	if barn == null:
		return
	var root := Node3D.new()
	root.name = "HowToPlaySign"
	root.position = CENTRE
	root.rotation.y = PI / 2.0  # faces +x, into the barn
	barn.add_child(root)
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BOARD.x, BOARD.y, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.25, 0.14)  # weathered planks
	mat.roughness = 1.0
	box.material = mat
	board.mesh = box
	root.add_child(board)
	_column(root, LEFT, -BOARD.x / 2.0 + 0.1)
	_column(root, RIGHT, 0.2)


func _column(root: Node3D, text: String, x: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = PIXEL_SIZE
	l.font_size = 36
	l.outline_size = 0
	l.modulate = Color(0.95, 0.9, 0.75)
	l.width = int((BOARD.x / 2.0 - 0.3) / PIXEL_SIZE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.position = Vector3(x, BOARD.y / 2.0 - 0.12, 0.04)
	root.add_child(l)
