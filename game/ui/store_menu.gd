extends CanvasLayer
## P4-22 (CEO session): the shipping crate's menu. `interact` at the crate (nothing else aimed) opens it: every
## `store.json` row with its price and a Buy button, then one seed row per crops.json crop with Buy 1 and Buy 5.
## Every button sends a `request_store` the host validates (store.gd); seeds go into the team's stock and planting
## uses one (D-093). Local player only; built by hud.gd.

const Crops := preload("res://game/farming/crops.gd")

var hud: CanvasLayer  ## the player's HUD: its key names and refusal texts
var _panel: Control
var _box: VBoxContainer
var _coins: Label
var _why: Label
var _rows: Array = []  ## [id, kind (&"item" or &"seed"), status Label, Buttons, counts]
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
		_row(StringName(r.id), &"item", "%s   %d coins" % [r.name, farm.store.price(Game.local_peer(), StringName(r.id))], [1])
	_label("Seeds (planting uses one; %s picks which)" % hud._key(&"cycle_seed"), 22)
	for r in Data.records(&"crops"):
		_row(StringName(r.id), &"seed", "%s seed   %d coins" % [r.name, int(r.seed)], [1, 5])
	_why = _label("", 18)
	_why.modulate = Color(1, 0.6, 0.5)
	_label("%s or %s: close" % [hud._key(&"interact"), hud._key(&"pause")], 16)
	_process(0.0)


func _row(id: StringName, kind: StringName, text: String, counts: Array) -> void:
	var h := HBoxContainer.new()
	var n := Label.new()
	n.text = text
	n.custom_minimum_size.x = 300
	h.add_child(n)
	var s := Label.new()
	s.custom_minimum_size.x = 300
	s.modulate = Color(0.8, 0.8, 0.8)
	h.add_child(s)
	var buttons := []
	for k in counts:
		var b := Button.new()
		b.custom_minimum_size.x = 100
		b.text = "Buy" if kind == &"item" else "Buy %d" % k
		b.pressed.connect(_press.bind(id, kind, k))
		h.add_child(b)
		buttons.append(b)
	_box.add_child(h)
	_rows.append([id, kind, s, buttons, counts])


func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override(&"font_size", size)
	_box.add_child(l)
	return l


func _press(id: StringName, kind: StringName, n: int) -> void:
	_why.text = ""
	Net.to_host(&"request_store", [&"buy", id] if kind == &"item" else [&"seeds", StringName("%s:%d" % [id, n])])


func _process(_delta: float) -> void:
	if not _open:
		return
	var farm := _farm()
	var me := Game.local_peer()
	_coins.text = "Coins %d" % farm.coins
	for row in _rows:  # the host checks again on Buy
		for i in row[3].size():
			var why: StringName = farm.store.why_not(me, row[0], false) if row[1] == &"item" else farm.store.seed_why_not(me, row[0], row[4][i], false)
			row[3][i].disabled = why != &""
			if i == 0:
				row[2].text = _status(row[0], why)
		if row[1] == &"seed" and (row[2].text == "" or row[2].text == "not enough coins"):
			var bed := " (moonflower bed)" if String(Crops.rec(row[0]).harvest_phase) == "night" else ""
			row[2].text = "have %d%s%s" % [farm.store.seed_count(row[0]), bed, "" if row[2].text == "" else ", not enough coins"]


func _status(id: StringName, why: StringName) -> String:
	match why:
		&"": return ""
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
	if _open and what == &"refused" and args[0] in [&"buy", &"seeds"]:
		_why.text = "Not enough coins" if args[1] == &"no_coins" else hud.REFUSED_TEXT.get(args[1], String(args[1]).replace("_", " "))
