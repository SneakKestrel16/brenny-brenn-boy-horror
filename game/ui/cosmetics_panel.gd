class_name CosmeticsPanel
extends VBoxContainer
## P5-05 (doc 02 s21.5): the hats and overalls list. `can_buy` shows the unowned ones with a Buy button while the
## debt is paid (the shipping crate menu and the Season's End card); every use lists the ones the local player owns
## with a Wear / Take off button (the lobby and pause menu). Buttons only send `request_cosmetic`; the host decides.
## Empty (hidden) when there is nothing to show.

var can_buy := false
var _rows: Array = []  ## [id, status Label, Buy Button, Wear Button]
var _key := ""


func _init(p_can_buy: bool = false) -> void:
	can_buy = p_can_buy


func _ready() -> void:
	Cosmetics.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_rows.clear()
	var me := Game.local_peer()
	var sold := can_buy and Cosmetics.sold_now()
	var owned := Cosmetics.owned_of(me)
	for id in Cosmetics.ids():
		if not sold and not id in owned:
			continue
		var r := Cosmetics.rec(id)
		var h := HBoxContainer.new()
		var n := Label.new()
		n.text = "%s   %d coins" % [r.name, int(r.price)] if sold and not id in owned else str(r.name)
		n.custom_minimum_size.x = 300
		h.add_child(n)
		var s := Label.new()
		s.custom_minimum_size.x = 120
		s.modulate = Color(0.8, 0.8, 0.8)
		h.add_child(s)
		var buy := Button.new()
		buy.text = "Buy"
		buy.custom_minimum_size.x = 100
		buy.pressed.connect(func() -> void: Net.to_host(&"request_cosmetic", [&"buy", id, &""]))
		var wear := Button.new()
		wear.custom_minimum_size.x = 100
		wear.pressed.connect(func() -> void:
			var on: bool = Cosmetics.look(me).get(Cosmetics.slot_of(id), &"") == id
			Net.to_host(&"request_cosmetic", [&"wear", &"" if on else id, Cosmetics.slot_of(id)]))
		h.add_child(buy)
		h.add_child(wear)
		add_child(h)
		_rows.append([id, s, buy, wear])
	visible = not _rows.is_empty()
	_key = _state_key()
	if visible:
		var t := Label.new()
		t.text = "Hats and overalls (no effect on play)"
		add_child(t)
		move_child(t, 0)


func _state_key() -> String:
	return "%s|%s" % [Cosmetics.sold_now(), Cosmetics.owned_of(Game.local_peer())]


func _process(_delta: float) -> void:
	if _state_key() != _key:
		_rebuild()  # the debt got paid, or something was bought
		return
	var me := Game.local_peer()
	var farm := get_tree().get_first_node_in_group(&"farm")
	var look := Cosmetics.look(me)
	for row in _rows:
		var id: StringName = row[0]
		var has := id in Cosmetics.owned_of(me)
		var on: bool = look.get(Cosmetics.slot_of(id), &"") == id
		row[1].text = "worn" if on else ("owned" if has else "")
		row[2].visible = not has
		row[2].disabled = farm == null or farm.coins < int(Cosmetics.rec(id).price)
		row[3].visible = has
		row[3].text = "Take off" if on else "Wear"
