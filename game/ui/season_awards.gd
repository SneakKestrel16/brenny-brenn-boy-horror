class_name SeasonAwards
extends CanvasLayer
## P4-15 Season Awards and season end (doc 01 "Season Awards", doc 03 section 17.4, doc 05 section 15, card style
## doc 07 section 9: the Dawn Report's paper with the masthead "SEASON'S END"). Host: tallies the season's log
## events (season_awards_logic.gd); on `Clock.season_ended` builds the awards and sends `apply_season_awards`.
## Every peer: shows the card (a client learns the end from that message, its own clock ends early at the final
## Dawn Report), reveals a line every REVEAL_S or on a click, and leads back to the menu. Applies nothing.
## Win or loss (Q-130, doc 01 "Winning and losing"): won = the final payment made and the cart out the gate with one
## player alive; lost = the final payment missed (`Debt.lost`) or everyone dead on the Harvest Moon before the cart is
## out. A Foreclosure alone is not a loss.

const Logic := preload("res://game/ui/season_awards_logic.gd")
const REVEAL_S := 3.0  ## doc 07 section 9: lines fade in on click or every 3 s
const PAPER := Color("#E8DCC0")
const INK := Color("#2B2118")
const RED_INK := Color("#8B1A1A")
const WIN_HEAD := "THE DEBT IS PAID"  ## placeholder copy (Game Designer to word)
const LOSS_HEAD := "THE BANK TOOK THE FARM"  ## placeholder copy

var _tally := Logic.empty_tally()
var _root: Control
var _box: VBoxContainer
var _pending: Array = []
var _t := 0.0
var _open := false
var _hm_wipe := false  ## host: everyone died on the Harvest Moon before the cart was out
var save_key := "season_awards"  ## P4-10 (Q-123): the dawn save keeps `_tally` and `_hm_wipe` (group `saveable`, host)


func _ready() -> void:
	layer = 115  # over the Dawn Report (110), under the pause menu (120)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	card.add_theme_stylebox_override(&"panel", sb)
	card.custom_minimum_size = Vector2(640, 0)
	card.rotation_degrees = -0.5
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(card)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 8)
	_box.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(_box)
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		add_to_group(&"saveable")
		Log.logged.connect(_on_log)
		Clock.season_ended.connect(_host_end)


## P4-10 (Q-123): the tally by player uid, so a loaded season counts every night, not only those since the load.
func save_state() -> Dictionary:
	return {"tally": Save.tally_state(_tally), "hm_wipe": _hm_wipe}


func load_state(d: Dictionary) -> void:
	_hm_wipe = bool(d.get("hm_wipe", false))
	Save.tally_load(_tally, d.get("tally", {}))


func _on_log(n: StringName, d: Dictionary) -> void:
	Logic.tally(_tally, String(n), d)
	if n == &"death" and d.get("phase") == "harvest_moon" and not _cart_out():  # Death logs before the ghost flag is set
		_hm_wipe = Game.players.keys().all(func(p: int) -> bool: return p == int(d.player) or Game.is_ghost(p))


## The festival cart (game/items/cart.gd, group `cart`) holds the host flag `cart_out` (Q-130, Q-131).
func _cart() -> Node:
	var cart := get_tree().get_first_node_in_group(&"cart")
	return cart if cart != null and "cart_out" in cart else null


func _cart_out() -> bool:
	var cart := _cart()
	return cart != null and bool(cart.cart_out)


func _host_end() -> void:
	var names := {}
	for p: int in Game.players:
		if Net.profiles.has(p):
			names[p] = str(Net.profiles[p].get("name", ""))
	var tpl := {}
	for r: Dictionary in Data.records(&"dawn_report_templates"):
		tpl[r.id] = r.text
	var debt := get_tree().get_first_node_in_group(&"debt")
	var lost: bool = (debt != null and debt.lost) or _hm_wipe
	if _cart() != null:
		lost = lost or not _cart_out()
	# else no CartRoute (Phase 1 farm, unit tests): no cart, so a paid debt with no Harvest Moon wipe wins
	Game.season_lost = lost  # P5-04: only a won season carries
	var res := Logic.build(_tally, {"names": names, "players": Game.players.keys(), "day": Clock.day}, tpl, lost)
	if Game.quirks_on:  # P5-09 (D-161): every quirk is named at season end, from the host's table
		for p: int in names:  # current names win; players who left keep the last name `Quirks.sync` saw
			Quirks.last_name[str(Net.profiles[p].get("uid", ""))] = names[p]
		res["quirks"] = Quirks.reveal(Game.quirks, Quirks.last_name)
	Net.to_peers(&"apply_season_awards", [res])
	show_card(res)


func _on_apply(what: StringName, args: Array) -> void:
	if what == &"season_awards":
		show_card(args[0])


func show_card(res: Dictionary) -> void:
	for c in _box.get_children():
		c.queue_free()
	_pending.clear()
	var lost: bool = res.lost
	_label("SEASON'S END", 32, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label(LOSS_HEAD if lost else WIN_HEAD, 22, RED_INK if lost else INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label("Day %d" % int(res.day), 16, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_box.add_child(HSeparator.new())
	for a: Dictionary in res.awards:
		var l := _label(a.line, 18, INK, HORIZONTAL_ALIGNMENT_LEFT)
		l.modulate.a = 0.0
		_pending.append(l)
	var qs: Array = res.get("quirks", [])
	if not qs.is_empty():  # P5-09: the quirks, named at last (only when the option was on)
		_box.add_child(HSeparator.new())
		for q: String in qs:
			var l := _label(q, 16, INK, HORIZONTAL_ALIGNMENT_LEFT)
			l.modulate.a = 0.0
			_pending.append(l)
	_box.add_child(HSeparator.new())
	if lost:
		_label("Nothing carries over.", 14, INK, HORIZONTAL_ALIGNMENT_CENTER)  # placeholder copy
	elif Game.season_no >= Campaign.seasons_max():
		_label("The farm is yours. The campaign is over.", 14, INK, HORIZONTAL_ALIGNMENT_CENTER)  # placeholder copy
	elif Game.is_host():  # P5-04 (doc 01 "Next season"): the host starts it
		var n := Button.new()
		n.text = "Start season %d" % (Game.season_no + 1)
		n.pressed.connect(Game.start_next_season)
		_box.add_child(n)
	else:
		_label("Waiting for the host to start season %d." % (Game.season_no + 1), 14, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var b := Button.new()
	b.text = "Back to menu"
	b.pressed.connect(Game.leave_session)
	_box.add_child(b)
	_open = true
	_root.visible = true
	Game.console_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_t = REVEAL_S
	Log.event(&"season_awards_shown", {"day": int(res.day), "lost": lost, "awards": res.awards.map(func(a: Dictionary) -> String: return a.id)})


func _process(delta: float) -> void:
	if not _open or _pending.is_empty():
		return
	_t += delta
	if _t >= REVEAL_S:
		_reveal()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if _open and not _pending.is_empty() and ((mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept")):
		while not _pending.is_empty():  # skippable: a click shows the rest
			_reveal()
		get_viewport().set_input_as_handled()
	elif _open and mb:
		get_viewport().set_input_as_handled()  # the final report under the card takes no clicks


func _reveal() -> void:
	var l: Label = _pending.pop_front()
	create_tween().tween_property(l, ^"modulate:a", 1.0, 0.4)
	Soundscape.play_2d(&"ui_award_reveal")
	_t = 0.0


func _label(text: String, size: int, col: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	_box.add_child(l)
	return l
