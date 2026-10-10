class_name DawnReport
extends CanvasLayer
## P3-12 Dawn Report (doc 01 "Dawn Report", doc 05 section 15). Host: keeps the day's report events as
## its log writes them (`Log.logged`), adds places, and after `dawn_summary` (the dawn order's money steps
## are done, doc 01 "Dawn, in this order") builds the report (dawn_report_logic.gd) and sends
## `apply_dawn_report`. Every peer: shows the newspaper card, reveals a section every REVEAL_S or on a
## click, replays the lures from its own clips, and applies nothing. Closes on the second click or at dusk.
## Streamer-safe (no voice replays) is the lobby group option `Game.streamer_safe`; `--streamer-safe` (host) turns it on.

const Logic := preload("res://game/ui/dawn_report_logic.gd")
const REVEAL_S := 3.0  ## doc 07 section 9: sections fade in on click or every 3 s
const REPLAY_GAP_S := 2.5  ## placeholder: room for one lobby line between replays
const KEEP := ["lure_played", "lure_result", "chase_started", "death", "inside_at_night", "flag_placed", "flag_removed", "trap_changed",
		"hold_completed", "trap_race_result", "money_changed", "medical_bill", "dawn_summary", "flare_reloaded"]
const PAPER := Color("#E8DCC0")  ## doc 07 section 9 placeholder card style
const INK := Color("#2B2118")
const RED_INK := Color("#8B1A1A")
const NEUTRAL_CUE := &"sfx_step_dirt"  ## the neutral sound under an Off player's line (doc 06 section 11); placeholder

var _events: Array = []
var _root: Control
var _box: VBoxContainer
var _scroll: ScrollContainer
var _pending: Array = []  # [section Control, replays]
var _report := {}
var _t := 0.0
var _open := false
var _playing: Array = []  # [owner, clip_id] voiced replays, stopped on close


func _ready() -> void:
	layer = 110  # under the pause menu (120)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	card.add_theme_stylebox_override(&"panel", sb)
	card.custom_minimum_size = Vector2(640, 0)
	card.rotation_degrees = 0.5
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	center.add_child(card)
	_scroll = ScrollContainer.new()  # a long night outgrows the screen: the card scrolls to each new section
	_scroll.custom_minimum_size = Vector2(640, 600)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	for c: Control in [_root, dim, center, card, _scroll, _box]:  # PASS: a click nobody takes reaches _unhandled_input
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	Net.apply_received.connect(_on_apply)
	Clock.phase_changed.connect(func(ph: StringName) -> void:
		if ph == &"dusk" and _open:
			_close())
	if Game.is_host():
		Log.logged.connect(_on_logged)


# --- host ----------------------------------------------------------------------------------------

func _on_logged(name: StringName, data: Dictionary) -> void:
	var n := String(name)
	if n == "save_loaded":  # P4-39: the resume's step 7 (flare refill) ran before this; those lines belong to no report
		_events.clear()
		return
	if n not in KEEP:
		return
	var d := data.duplicate()
	match n:
		"lure_played":  # where the voiced teammate really was (doc 03 section 17.1 "{owner_place}")
			var o: Variant = d.get("owner")
			if o != null and Game.players.has(int(o)):
				d.owner_place = _place(Game.players[int(o)].pos)
		"chase_started":
			if Game.players.has(int(d.target)):
				d.place = _place(Game.players[int(d.target)].pos)
		"death":
			var at := Vector3(d.position[0], 0.0, d.position[1])
			d.place_name = _place(at)
			var barn := INF  # the barn lights: the nearest barn spawn marker (inference; doc 04 names no light point)
			for m: Node3D in get_tree().get_nodes_in_group(&"player_spawns"):
				barn = minf(barn, Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(at.x, at.z)))
			d.distance = int(round(barn)) if barn < INF else 0
	_events.append([n, d])
	if n == "dawn_summary":
		_build.call_deferred()  # after every same-frame dawn record (inside_at_night)


func _place(pos: Vector3) -> String:
	var ai := get_parent().get_node_or_null(^"AiDirector")
	var r: String = ai.region_of(pos) if ai else ""
	return "near the " + r.replace("_", " ") if r else "on the farm"


func _build() -> void:
	var names := {}
	for p: int in Game.players:
		if Net.profiles.has(p):
			names[p] = str(Net.profiles[p].get("name", ""))
	var lines := {}
	for r: Dictionary in Data.records(&"voice_lines"):
		lines[r.id] = r.get("text", "")
	var tpl := {}
	for r: Dictionary in Data.records(&"dawn_report_templates"):
		tpl[r.id] = r.text
	var ctx := {"names": names, "players": Game.players.keys(), "lines": lines,
		"streamer_safe": Game.streamer_safe}  # the lobby's group option (P4-11); `--streamer-safe` sets its default
	var report := Logic.build(_events, ctx, tpl)
	_events.clear()
	Net.to_peers(&"apply_dawn_report", [report])
	_show(report)


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	if what == &"dawn_report":
		_show(args[0])


func _show(report: Dictionary) -> void:
	_stop_replays()
	_report = report
	for c in _box.get_children():
		c.queue_free()
	_pending.clear()
	_label("THE HARROW COUNTY GAZETTE", 30, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_label("Day %d" % int(report.day), 16, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_box.add_child(HSeparator.new())
	for row: Array in report.ledger:  # [label, coins, red]; shown as applied, never applied here
		var h := HBoxContainer.new()
		_box.add_child(h)
		var col: Color = RED_INK if row[2] else INK
		_label(row[0], 16, col, HORIZONTAL_ALIGNMENT_LEFT, h)
		var dots := _label(". ".repeat(80), 16, Color(INK, 0.4), HORIZONTAL_ALIGNMENT_LEFT, h)
		dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dots.clip_text = true
		_label("%d" % int(row[1]), 16, col, HORIZONTAL_ALIGNMENT_RIGHT, h)
	var fold := ColorRect.new()  # the paper's fold line
	fold.color = Color(INK, 0.15)
	fold.custom_minimum_size.y = 2
	_box.add_child(fold)
	var replays := 0
	for s: Dictionary in report.sections:
		var v := VBoxContainer.new()
		v.modulate.a = 0.0
		_box.add_child(v)
		if not String(s.lines[0]).begins_with(String(s.title).to_upper()):  # headline templates carry their own title
			_label(String(s.title).to_upper(), 20, INK, HORIZONTAL_ALIGNMENT_LEFT, v)
		for line: String in s.lines:
			_label(line, 15, INK, HORIZONTAL_ALIGNMENT_LEFT, v)
		for r: Dictionary in s.replays:
			if not _voiced(r) and not String(r.off_text).is_empty() and not _muted(r):
				_label(r.off_text, 15, Color(INK, 0.7), HORIZONTAL_ALIGNMENT_LEFT, v)  # doc 01: text for Off players
		_pending.append([v, s.replays])
		replays += s.replays.size()
	if report.get("final", false):  # the last dawn: the season is over (the Season Awards screen is not built)
		_label("THE SEASON IS OVER", 20, RED_INK, HORIZONTAL_ALIGNMENT_CENTER)
		if not Game.is_host():
			Clock.end_season()  # a client learns it here (apply_clock has no season flag); the host's clock ends it after DAWN_S
	_label("Click to read on", 12, Color(INK, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	_open = true
	_root.visible = true
	Game.console_open = true  # game keys off while the card is up (as the pause menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_t = REVEAL_S  # the first section shows at once
	Log.event(&"dawn_report_shown", {"day": report.day, "sections": report.sections.map(func(s: Dictionary) -> String: return s.id),
		"replays": replays, "streamer_safe": report.streamer_safe})


func _process(delta: float) -> void:
	if not _open or _pending.is_empty():
		return
	_t += delta
	if _t >= REVEAL_S:
		_reveal(true)


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var mb := event as InputEventMouseButton
	if (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed(&"ui_accept"):
		if _pending.is_empty():
			_close()
		else:  # skippable: a click shows the rest at once, without their replays
			while not _pending.is_empty():
				_reveal(false)
		get_viewport().set_input_as_handled()


func _reveal(play: bool) -> void:
	var e: Array = _pending.pop_front()
	create_tween().tween_property(e[0], ^"modulate:a", 1.0, 0.4)
	_scroll.ensure_control_visible.call_deferred(e[0])
	_t = 0.0
	if not play:
		return
	_t = -REPLAY_GAP_S * maxi(e[1].size() - 1, 0)  # the next section waits for this one's replays
	for i in e[1].size():
		get_tree().create_timer(REPLAY_GAP_S * i + 0.4).timeout.connect(_replay.bind(e[1][i]))


func _close() -> void:
	Log.event(&"dawn_report_closed", {"day": int(_report.get("day", 0))})  # D-081 item 2: the soundscape listens
	_open = false
	_pending.clear()
	_stop_replays()
	_root.visible = false
	Game.console_open = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A clip replays in its owner's voice only if streamer-safe is off, the owner's current setting is
## `live_clips` (`Game.replays_voice`, doc 06 section 11 "Coverage") and this listener has not muted them (D-047).
func _voiced(r: Dictionary) -> bool:
	var src: String = r.source
	return src.begins_with("clip:") and not _report.get("streamer_safe", false) and Game.replays_voice(int(r.owner))


func _muted(r: Dictionary) -> bool:
	return int(r.owner) != 0 and Settings.peer_volume(int(r.owner)) <= 0.0


## Every peer plays its own copy: the clip through its tell's bus, the stranger's line, or the sound the
## creature faked for an Off player. The ghost flag rides along for P3-10's ghost chain (not built).
func _replay(r: Dictionary) -> void:
	if not _open or _muted(r):
		return
	var src: String = r.source
	if src == "stranger":
		Soundscape.play_2d(Soundscape.STRANGER_LINES[hash(r.lure_id) % Soundscape.STRANGER_LINES.size()])
	elif _voiced(r):
		var parts := src.split(":", true, 2)
		var p := VoiceChain.play_clip(int(parts[1]), parts[2], StringName(r.tell))
		if p:
			p.volume_db = linear_to_db(Settings.peer_volume(int(parts[1])))
			_playing.append([int(parts[1]), parts[2]])
	else:  # Off, streamer-safe, or a sound lure: text (shown) plus the faked sound or a neutral cue
		var lures: Dictionary = load("res://game/creature/creature.gd").get_script_constant_map().get("SOUND_LURES", {})
		var s: Array = lures.get(src.trim_prefix("sound:"), [NEUTRAL_CUE, 2, 0.5])
		for i in mini(int(s[1]), 4):
			if not is_inside_tree() or not _open:
				return
			Soundscape.play_2d(s[0])
			await get_tree().create_timer(maxf(float(s[2]), 0.3)).timeout


func _stop_replays() -> void:
	for e: Array in _playing:
		Voice.clips.stop(e[0], e[1])
	_playing.clear()


func _label(text: String, size: int, col: Color, align: HorizontalAlignment, parent: Control = _box) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	if parent is VBoxContainer:  # a wrapping label in a row would shrink to nothing
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	parent.add_child(l)
	return l
