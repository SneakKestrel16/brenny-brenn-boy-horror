extends CanvasLayer
## P4-22 (CEO session): the shipping crate's menu. `interact` at the crate (nothing else aimed) opens it: every
## `store.json` row with its price and a Buy button, then one seed row per crops.json crop. Buy sends the same
## `request_store` the host already validates (store.gd); a seed row only picks `farm.seed_pick`, and the seed is
## still paid at planting, as the simulator does (D-090). Local player only; built by hud.gd.

const Crops := preload("res://game/farming/crops.gd")

var hud: CanvasLayer  ## the player's HUD: its key names and refusal texts
var _panel: Control
var _box: VBoxContainer
var _coins: Label
var _why: Label
var _rows: Array = []  ## [id, kind (&"item" or &"seed"), status Label, Button]
var _open := false


func _ready() -> void:
	layer = 110  # under the pause menu (120)
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size.x = 720
	center.add_child(_box)
	Net.apply_received.connect(_on_apply)


func _farm() -> Node:
	return get_tree().get_first_node_in_group(&"farm")


func _input(event: InputEvent) -> void:
	if _open and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"interact")):
		set_open(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var farm := _farm()
	if _open or Game.console_open or farm == null or not event.is_action_pressed(&"interact") or hud.player.ghost:
		return
	if hud.hold.aimed_verb == &"" and hud.hold.hold_state()[0] == &"" and farm.store.prompt_text(hud.player.global_position) != "":
		set_open(true)


func set_open(on: bool) -> void:
	_open = on
	_panel.visible = on
	Game.console_open = on  # game keys off while the menu is up (as the pause menu)
	if on:
		_rebuild()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Log.event(&"store_menu", {"open": true})
	elif DisplayServer.get_name() != "headless" and not Game.free_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	_rows.clear()
	var farm := _farm()
	_label("The shipping crate", 30)
	_coins = _label("", 20)
	for r in farm.store.items():
		_row(StringName(r.id), &"item", "%s   %d coins" % [r.name, farm.store.price(Game.local_peer(), StringName(r.id))])
	_label("Seeds (one per plot, paid when you plant)", 22)
	for r in Data.records(&"crops"):
		_row(StringName(r.id), &"seed", "%s seed   %d coins" % [r.name, int(r.seed)])
	_why = _label("", 18)
	_why.modulate = Color(1, 0.6, 0.5)
	_label("%s or %s: close" % [hud._key(&"interact"), hud._key(&"pause")], 16)
	_process(0.0)


func _row(id: StringName, kind: StringName, text: String) -> void:
	var h := HBoxContainer.new()
	var n := Label.new()
	n.text = text
	n.custom_minimum_size.x = 300
	h.add_child(n)
	var s := Label.new()
	s.custom_minimum_size.x = 300
	s.modulate = Color(0.8, 0.8, 0.8)
	h.add_child(s)
	var b := Button.new()
	b.custom_minimum_size.x = 100
	b.pressed.connect(_press.bind(id, kind))
	h.add_child(b)
	_box.add_child(h)
	_rows.append([id, kind, s, b])


func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override(&"font_size", size)
	_box.add_child(l)
	return l


func _press(id: StringName, kind: StringName) -> void:
	_why.text = ""
	if kind == &"item":
		Net.to_host(&"request_store", [&"buy", id])
	else:
		_farm().seed_pick = id
		Log.event(&"seed_picked", {"crop": String(id)})


func _process(_delta: float) -> void:
	if not _open:
		return
	var farm := _farm()
	var me := Game.local_peer()
	_coins.text = "Coins %d" % farm.coins
	var pick: StringName = farm.seed_pick if farm.seed_pick != &"" else Crops.default_seed()
	for row in _rows:
		var why := &""
		if row[1] == &"item":
			why = farm.store.why_not(me, row[0], false)  # the host checks again on Buy
			row[3].text = "Buy"
		elif String(Crops.rec(row[0]).harvest_phase) == "night":
			why = &"bed_only"
			row[3].text = "Choose"
		else:
			why = &"" if Crops.is_unlocked(row[0], Clock.day) else &"locked_crop"
			why = &"chosen" if why == &"" and row[0] == pick else why
			row[3].text = "Chosen" if why == &"chosen" else "Choose"
		row[2].text = _status(row[0], why)
		row[3].disabled = why != &""


func _status(id: StringName, why: StringName) -> String:
	match why:
		&"": return ""
		&"chosen": return "planting this"
		&"bed_only": return "plants in the moonflower bed"
		&"locked_item": return "from day %d" % int(Data.record(&"store", id).unlock_day)
		&"locked_crop":
			var r := Data.record(&"crops", id)
			if String(r.unlock_rule) == "first_payment_made":  # doc 02 s10
				return "from dawn %d, if the first payment was made" % int(r.unlock_day)
			return "from day %d" % int(r.unlock_day)
		&"no_coins": return "not enough coins"
	return hud.REFUSED_TEXT.get(why, String(why).replace("_", " "))


## The host's answer to a Buy: a refusal shows under the list; a buy rebuilds nothing (the rows read live state).
func _on_apply(what: StringName, args: Array) -> void:
	if _open and what == &"refused" and args[0] == &"buy":
		_why.text = "Not enough coins" if args[1] == &"no_coins" else hud.REFUSED_TEXT.get(args[1], String(args[1]).replace("_", " "))
