extends Control
## P2-10, P4-23, P4-35 lobby (doc 05 section 16, D-140): the menu lobby. Nobody spawns until the host starts
## the season; then everyone changes to Main and spawns at the barn spawn markers. Behind the menus a dark
## barn at night where every connected player's farmer stands in a line, the local player in the centre
## spotlight, each with name, role and READY / NOT READY overhead (class `LineUp`, the scene's `Players`).
## Left panel: the role cards (P4-09). Right panel: voice settings of the roster, join code, the group settings
## (P4-11, doc 01 "Difficulty and group settings"; the host sets them, everyone sees them), Settings and Leave.
## Bottom right: Ready (clients) or Start the season (host, once every other human is ready).
## `Game.match_ready()` is the P2-03 clip pre-share hook.
## Debug: `--lobby-start=<n>` (Game.lobby_autostart) starts when n players are present, ready or not;
## `--lobby-ready` goes through Ready and Start the season instead; `--role=<id>` picks a role.

const DISCORD_LINE := "The creature can't hear Discord, and you can't hear where your friends are."
const FarmerBody := preload("res://game/player/farmer_body.gd")
const VOICE_NAMES := {"off": "Off", "live_clips": "Live clips"}
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"nightmare"]

## P4-09 role cards (doc 01 "Picking a role"): one per role with its perk, a taken one greyed out, "No role" always open.
const PERK_TEXT := {&"farmer": "+1 crop every 5th harvest", &"rancher": "faster round-up, hears animals from further",
		&"mechanic": "repairs and refuels faster", &"tracker": "disarms faster, spots clues further",
		&"carpenter": "builds and fixes fences faster, builds cheaper", &"medic": "frees teammates faster, cheaper bills",
		&"night_owl": "quieter at night, picks moonflowers faster", &"radio_operator": "walkie reaches further, voice carries",
		&"warden": "more flare shots, faster reload", &"medium": "ghost voices through less static"}

## Placeholder palette (doc 07 s1 night: dark, warm lantern accents; D-140: no bright colours from the reference).
const INK := Color(0.86, 0.8, 0.68)  ## parchment text
const EMBER := Color(0.95, 0.62, 0.25)  ## lantern amber
const READY_COL := Color(0.62, 0.78, 0.5)  ## muted green
const NOT_READY_COL := Color(0.78, 0.3, 0.24)  ## dried red

var _roster: Label
var _name_edit: LineEdit
var _cards: VBoxContainer
var _difficulty: OptionButton
var _streamer: CheckBox
var _quirks: CheckBox
var _imposter: CheckBox
var _go: Button  ## host: Start the season; client: Ready
var _lineup: LineUp
var _autostart_t := 0.0
var _qa_ready := false


## P4-35 (D-140): the `Players` node of the lobby. One placeholder farmer per player, in a row with the local
## player at x = 0 and the others stepping outward and back. Voice hangs each speaker's emitter on
## `player(peer)`, so lobby voice is placed at that farmer; the listener is the stage camera.
class LineUp extends Node3D:
	## Six farmers (doc 01 "Format" cap) fit between the side panels with the stage camera in `_stage`.
	const SPACING := 0.9  ## m between farmers (placeholder)
	const STEP_BACK := 0.3  ## m further back per slot from the centre (placeholder)
	## Tag lines: node name, height over the farmer (m), font size. Odd slots lift theirs by TAG_LIFT so
	## neighbouring tags stagger instead of overlapping.
	const TAGS := [["Name", 2.56, 56], ["Role", 2.36, 36], ["Status", 2.2, 36]]
	const TAG_LIFT := 0.6
	## Placeholder role hats until the 3D Artist's hat_<role>.glb files land (D-144, P4-36): colour, brim radius, crown height.
	const HATS := {&"farmer": [Color(0.6, 0.48, 0.26), 0.3, 0.14], &"rancher": [Color(0.4, 0.27, 0.16), 0.34, 0.16],
			&"mechanic": [Color(0.25, 0.3, 0.36), 0.2, 0.1], &"tracker": [Color(0.3, 0.33, 0.2), 0.26, 0.12],
			&"carpenter": [Color(0.55, 0.36, 0.18), 0.22, 0.1], &"medic": [Color(0.7, 0.68, 0.62), 0.2, 0.12],
			&"night_owl": [Color(0.16, 0.16, 0.22), 0.26, 0.2], &"radio_operator": [Color(0.32, 0.36, 0.24), 0.2, 0.1],
			&"warden": [Color(0.3, 0.2, 0.14), 0.3, 0.18], &"medium": [Color(0.3, 0.16, 0.28), 0.24, 0.24]}

	## Called by Voice, the recording light and the lobby; makes the farmer if `peer` is in the game.
	func player(peer: int) -> Node3D:
		var n := get_node_or_null(str(peer)) as Node3D
		if n == null and Game.players.has(peer):
			n = _farmer(peer)
		return n

	## Adds joiners, frees leavers (their voice emitter goes with them), re-slots, and rewrites every tag.
	func sync() -> void:
		for c in get_children():
			if not Game.players.has(int(String(c.name))):
				remove_child(c)
				c.queue_free()
		var others: Array = Game.players.keys().filter(func(p: int) -> bool: return p != Game.local_peer())
		others.sort()
		var order := [Game.local_peer()] + others
		for i in order.size():
			var f := player(order[i])
			if f == null:
				continue
			if f.get_meta(&"slot", -1) != _rank(order[i]):  # the host changed the slot
				f.set_meta(&"slot", _rank(order[i]))
				(f.get_node("Body") as FarmerBody).tint(_rank(order[i]))
			var slot := ((i + 1) >> 1) * (1 if i % 2 == 1 else -1)  # 0, +1, -1, +2, -2, ...
			f.position = Vector3(slot * SPACING, 0.0, -absf(slot) * STEP_BACK)
			for t in TAGS:
				(f.get_node(t[0]) as Node3D).position.y = t[1] + (TAG_LIFT if absi(slot) % 2 == 1 else 0.0)
			_tag(f, order[i])

	## D-159, D-165: the farmer colour is the host's slot (it arrives with the role table); until then the place in the sorted roster.
	func _rank(peer: int) -> int:
		var ids: Array = Game.players.keys()
		ids.sort()
		var s := Game.colour_of(peer)
		return s if s >= 0 else maxi(ids.find(peer), 0)

	func _farmer(peer: int) -> Node3D:
		var f := Node3D.new()
		f.name = str(peer)
		f.rotation.y = PI  # face the camera at +Z; models and hats front -Z (Q-242)
		add_child(f)
		var body := FarmerBody.new(_rank(peer))  # P5-13: the in-game rigged farmer, in the colour the game gives
		body.name = "Body"
		f.add_child(body)
		for line in TAGS:
			var l := Label3D.new()
			l.name = line[0]
			l.position.y = line[1]
			l.font_size = line[2]
			l.pixel_size = 0.005
			l.outline_size = 14
			l.outline_modulate = Color(0, 0, 0, 0.85)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			f.add_child(l)
		return f

	func _tag(f: Node3D, peer: int) -> void:
		var role := Roles.of(peer)
		var name_l: Label3D = f.get_node("Name")
		name_l.text = str(Net.profiles.get(peer, {}).get("name", "Player %d" % peer))  # one source: Net.profiles (Q-054 item 3)
		name_l.modulate = INK
		var role_l: Label3D = f.get_node("Role")
		role_l.text = (str(Data.record(&"roles", role).name) if role != &"" else "No role").to_upper()
		role_l.modulate = EMBER
		var st: Label3D = f.get_node("Status")
		var ready := peer < 0 or Game.lobby_ready.has(peer)  # bots count as ready (Game.all_ready)
		st.text = "HOST" if peer == 1 else ("READY" if ready else "NOT READY")
		st.modulate = EMBER if peer == 1 else (READY_COL if ready else NOT_READY_COL)
		if f.get_meta(&"hat", &"-") != role:
			f.set_meta(&"hat", role)
			var old := f.get_node_or_null("Hat")
			if old:
				old.free()
			if HATS.has(role):
				f.add_child(_hat(role))

	## The role's hat: the 3D Artist's `hat_<role>.glb` (P4-36, D-144; origin at the band centre) when it
	## exists, else the placeholder primitives from HATS.
	func _hat(role: StringName) -> Node3D:
		var path := "res://assets/models/hat_%s.glb" % role
		var hat: Node3D = (load(path) as PackedScene).instantiate() if ResourceLoader.exists(path) else _hat_placeholder(HATS[role])
		hat.name = "Hat"
		hat.position.y = 1.74
		return hat

	func _hat_placeholder(h: Array) -> Node3D:
		var hat := Node3D.new()
		var brim := CylinderMesh.new()
		brim.top_radius = h[1]
		brim.bottom_radius = h[1]
		brim.height = 0.025
		hat.add_child(_mesh(brim, h[0], Vector3.ZERO))
		var crown := CylinderMesh.new()
		crown.top_radius = 0.13
		crown.bottom_radius = 0.16
		crown.height = h[2]
		hat.add_child(_mesh(crown, h[0], Vector3(0, h[2] / 2.0, 0)))
		return hat

	func _mesh(m: Mesh, col: Color, at: Vector3) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = at
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.9
		mi.material_override = mat
		return mi


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Clock.phase = &"night"  # the clock is idle in the lobby; Clock.start() resets it at match start
	_stage()
	_lineup = LineUp.new()
	_lineup.name = "Players"
	add_child(_lineup)
	_ui()
	Game.roles_changed.connect(_refresh_cards)
	_refresh_cards()
	var pause := PauseMenu.new()  # Esc, voice volumes, and the host-left card
	pause.name = "PauseMenu"
	add_child(pause)
	Game.player_joined.connect(func(_p: int) -> void: _refresh())
	Game.player_left.connect(func(_p: int) -> void: _refresh_cards(); _refresh())  # a leaver frees their role card and farmer
	Game.voice_setting_changed.connect(func(_p: int) -> void: _refresh())
	Game.roles_changed.connect(_refresh)
	Net.names_changed.connect(_refresh)
	if not Game.is_host():
		Net.to_host(&"request_lobby_ready", [false])  # the host answers with everyone's ready marks
	_refresh()
	for a in OS.get_cmdline_user_args():  # QA: `--role=<id>` picks a role once the lobby is up
		if a.begins_with("--role="):
			get_tree().create_timer(1.0).timeout.connect(pick.bind(StringName(a.get_slice("=", 1))))
		elif a == "--lobby-ready":  # QA: a client presses Ready; the host presses Start once a teammate is in and all are ready
			_qa_ready = true
			if not Game.is_host():
				get_tree().create_timer(1.0).timeout.connect(_on_go)


## The barn at night behind the menus (placeholder boxes, doc 07 s3 "Barn lobby"): plank floor and wall, a
## moonlit window, hay, three lanterns and a warm spotlight on the centre farmer. No light here changes on its own.
func _stage() -> void:
	var stage := Node3D.new()
	stage.name = "Stage"
	add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.25, 0.4)
	env.ambient_light_energy = 0.25  # doc 07 s5: the night ambient floor
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.08)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 8.2)  # far enough back for six full bodies between the panels (QA P4-35)
	cam.rotation_degrees.x = -3.0
	cam.fov = 48.0
	stage.add_child(cam)
	cam.make_current()
	var ear := AudioListener3D.new()  # lobby voice is placed at each speaker's farmer
	cam.add_child(ear)
	ear.make_current()
	var wood := Color(0.16, 0.1, 0.06)
	_box(stage, Vector3(20, 0.1, 16), Vector3(0, -0.05, 4.5), Color(0.12, 0.08, 0.05))  # floor
	for i in 31:  # back wall planks, two tones
		_box(stage, Vector3(0.58, 7.0, 0.12), Vector3(-9.0 + i * 0.6, 3.5, -3.2), wood * (0.8 if i % 2 else 1.0))
	for x in [-3.6, 3.6]:  # posts and the beam the lanterns hang from
		_box(stage, Vector3(0.28, 4.2, 0.28), Vector3(x, 2.1, -1.0), wood * 1.2)
	_box(stage, Vector3(7.8, 0.3, 0.3), Vector3(0, 3.6, -1.0), wood * 1.2)
	var window := _box(stage, Vector3(1.2, 1.0, 0.05), Vector3(2.4, 3.1, -3.12), Color(0.1, 0.13, 0.22))
	(window.material_override as StandardMaterial3D).emission_enabled = true
	(window.material_override as StandardMaterial3D).emission = Color(0.25, 0.32, 0.55)
	(window.material_override as StandardMaterial3D).emission_energy_multiplier = 0.6
	_box(stage, Vector3(1.4, 0.06, 0.06), Vector3(2.4, 3.1, -3.08), wood)  # window cross
	_box(stage, Vector3(0.06, 1.0, 0.06), Vector3(2.4, 3.1, -3.08), wood)
	for hay in [[Vector3(-4.6, 0.35, -2.4), 8.0], [Vector3(-4.3, 1.05, -2.5), -5.0], [Vector3(4.7, 0.35, -2.2), -12.0]]:
		var b := _box(stage, Vector3(1.3, 0.7, 0.8), hay[0], Color(0.42, 0.34, 0.16))
		b.rotation_degrees.y = hay[1]
	# The moon and the spot are authored in lobby.tscn: only game/render/ sets light energy in code (doc 07 s4.4 rule 3).
	($Moon as Node3D).rotation_degrees = Vector3(-40, 150, 0)  # moonlight through the window
	for at in [Vector3(-3.0, 3.2, -1.0), Vector3(3.0, 3.2, -1.0), Vector3(0, 3.3, -1.0)]:
		var rig := LightRig.new()
		rig.ground_pool = false
		rig.range_m = 6.0
		rig.position = at
		stage.add_child(rig)
	var spot := $Spot as Node3D  # the local player's spotlight
	spot.position = Vector3(0, 5.0, 1.6)
	spot.look_at_from_position(spot.position, Vector3(0, 0.6, 0))


func _box(parent: Node3D, size: Vector3, at: Vector3, col: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Side panels and the big button over the stage (layout from D-140).
func _ui() -> void:
	var title := Label.new()
	title.text = "THE LOBBY"
	title.add_theme_font_size_override(&"font_size", 44)
	title.add_theme_color_override(&"font_color", INK)
	title.position = Vector2(32, 20)
	add_child(title)
	var left := _panel(Control.PRESET_LEFT_WIDE, 300)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	_heading(lv, "Pick a role (kept for the season)")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)
	var right := _panel(Control.PRESET_RIGHT_WIDE, 300)
	right.offset_bottom = -130  # the big button sits under it
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override(&"separation", 8)
	right.add_child(rv)
	_heading(rv, "Farmhands")
	_name_edit = LineEdit.new()  # P5-20: your name; saved to Settings, sent to the host
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = Net.NAME_MAX
	_name_edit.text = Net._clean_name(str(Settings.get_value(&"player_name")))
	_name_edit.text_submitted.connect(rename)
	_name_edit.focus_exited.connect(func() -> void: rename(_name_edit.text))
	rv.add_child(_name_edit)
	_roster = Label.new()
	_roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roster.add_theme_font_size_override(&"font_size", 14)
	_roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(_roster)
	_heading(rv, "Group settings")
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Difficulty"
	row.add_child(l)
	_difficulty = OptionButton.new()
	_difficulty.item_selected.connect(func(i: int) -> void:
		Game.set_group_settings(StringName(_difficulty.get_item_metadata(i)), Game.streamer_safe))
	row.add_child(_difficulty)
	rv.add_child(row)
	_streamer = CheckBox.new()
	_streamer.text = "Streamer-safe (no voice replays in the Dawn Report)"
	_streamer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_streamer.toggled.connect(func(on: bool) -> void: Game.set_group_settings(Game.difficulty, on))
	rv.add_child(_streamer)
	_quirks = CheckBox.new()
	_quirks.text = "Quirks (each player gets a private quirk; revealed at season end)"
	_quirks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quirks.toggled.connect(Quirks.set_on)
	rv.add_child(_quirks)
	_imposter = CheckBox.new()  # P5-11: off by default (D-158); needs 4 players (D-161)
	_imposter.text = "Imposter mode (4+ players; one may secretly work against the farm)"
	_imposter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_imposter.toggled.connect(func(on: bool) -> void: Imposter.set_enabled(on))
	rv.add_child(_imposter)
	var menu := HBoxContainer.new()
	var settings := Button.new()
	settings.text = "Settings"
	settings.pressed.connect(func() -> void: add_child(SettingsMenu.new()))
	menu.add_child(settings)
	var leave := Button.new()
	leave.text = "Leave to menu"
	leave.pressed.connect(Game.leave_session)
	menu.add_child(leave)
	rv.add_child(menu)
	_go = Button.new()
	_go.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_go.offset_left = -332
	_go.offset_top = -110
	_go.offset_right = -32
	_go.offset_bottom = -32
	_go.add_theme_font_size_override(&"font_size", 26)
	for s in [[&"normal", Color(0.3, 0.13, 0.04, 0.92)], [&"hover", Color(0.42, 0.19, 0.06, 0.95)],
			[&"pressed", Color(0.22, 0.09, 0.03, 0.95)], [&"disabled", Color(0.1, 0.09, 0.08, 0.85)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = s[1]
		sb.set_border_width_all(2)
		sb.border_color = EMBER * Color(1, 1, 1, 0.3 if s[0] == &"disabled" else 0.8)
		_go.add_theme_stylebox_override(s[0], sb)
	_go.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.6))
	_go.add_theme_color_override(&"font_hover_color", Color(1.0, 0.92, 0.75))
	_go.pressed.connect(_on_go)
	add_child(_go)


## A dark side panel on the left or right, `width` px, below the title.
func _panel(preset: Control.LayoutPreset, width: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(preset)
	if preset == Control.PRESET_LEFT_WIDE:
		p.offset_left = 32
		p.offset_right = 32 + width
	else:
		p.offset_left = -32 - width
		p.offset_right = -32
	p.offset_top = 90
	p.offset_bottom = -32
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.03, 0.028, 0.84)
	sb.set_border_width_all(1)
	sb.border_color = EMBER * Color(1, 1, 1, 0.35)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override(&"panel", sb)
	add_child(p)
	return p


func _heading(parent: Control, text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override(&"font_size", 20)
	h.add_theme_color_override(&"font_color", EMBER)
	parent.add_child(h)


func _refresh_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	var mine := Roles.of(Game.local_peer())
	var taken := {}  # role -> true when someone else holds it
	for p in Game.players:
		if p != Game.local_peer() and Roles.of(p) != &"":
			taken[Roles.of(p)] = true
	var locked := Roles.locked()  # a loaded season keeps its roles (Roles.on_request refuses)
	if locked:
		var l := Label.new()
		l.text = "Roles are kept from the saved season."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_cards.add_child(l)
	_card(&"", "No role", "", mine == &"", false, locked)
	for id in Roles.ids():
		_card(id, str(Data.record(&"roles", id).name), PERK_TEXT.get(id, ""), mine == id, taken.has(id), locked)


func _card(id: StringName, title: String, perk: String, mine: bool, taken: bool, locked := false) -> void:
	var b := Button.new()
	b.text = "%s%s" % [title, "  (taken)" if taken and not mine else ""] + ("\n" + perk if perk != "" else "")
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override(&"font_size", 13)
	b.disabled = taken or locked
	b.flat = not mine
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if mine:
		b.add_theme_color_override(&"font_color", EMBER)
	b.pressed.connect(pick.bind(id))
	_cards.add_child(b)

## P5-20: keep `text` as the player's name (Settings) and ask the host to use it. The host may add a number
## to keep names apart: the roster and name tag show it; the field keeps what was typed,
## so Settings never saves the suffix.
func rename(text: String) -> void:
	var n := Net._clean_name(text)
	if n == str(Settings.get_value(&"player_name")):  # unchanged (focus-out after Enter, or the host's "Farmer 2" kept apart)
		return
	Settings.set_value(&"player_name", n)
	Settings.save()
	Net.to_host(&"request_name", [n])


## Ask the host for `id` (empty = no role); the host refuses a taken role or a started match.
func pick(id: StringName) -> void:
	if Game.is_host():
		Roles.on_request(1, id)
	else:
		Net.to_host(&"request_role", [String(id)])


func _refresh() -> void:
	_lineup.sync()
	var t := ""
	for p in Game.players:
		var me := " (you)" if p == Game.local_peer() else ""
		var host := " [host]" if p == 1 else ""
		var who: String = Net.profiles.get(p, {}).get("name", "Player %d" % p)
		var rec := ", recording" if Voice._lit.has(p) else ""  # Voice has no public accessor yet; reads its tally-lamp set
		t += "%s%s%s: voice %s%s\n" % [who, me, host, VOICE_NAMES.get(Game.voice_setting_of(p), "Off"), rec]
	var code := Net.join_code()  # D-049: the fallback when a rejoin prompt fails
	if code != "":
		t += "\nJoin code: %s" % code
	t += "\n" + DISCORD_LINE
	_roster.text = t
	var opts: Array[StringName] = DIFFICULTIES.duplicate()
	if not Game.difficulty in opts:
		opts.append(Game.difficulty)  # e.g. `--short-season`
	if _difficulty.item_count != opts.size():
		_difficulty.clear()
		for d in opts:
			_difficulty.add_item(String(d).capitalize())
			_difficulty.set_item_metadata(_difficulty.item_count - 1, String(d))
	_difficulty.select(opts.find(Game.difficulty))
	_difficulty.disabled = not Game.is_host()
	_streamer.set_pressed_no_signal(Game.streamer_safe)
	_streamer.disabled = not Game.is_host()
	_quirks.set_pressed_no_signal(Game.quirks_on)
	_quirks.disabled = not Game.is_host()
	_imposter.set_pressed_no_signal(Imposter.enabled)
	_imposter.disabled = not Game.is_host() or Game.humans() < Imposter.min_players()
	if Game.is_host():
		_go.text = "START THE SEASON" if Game.all_ready() else "Waiting for everyone\nto be ready"
		_go.disabled = not Game.all_ready()
	else:
		_go.text = "READY\nwaiting for the host" if Game.lobby_ready.has(Game.local_peer()) else "READY"
		_go.disabled = false


## Host: start the season (clips may still hold it, doc 06 s12). Client: toggle ready.
func _on_go() -> void:
	if Game.is_host():
		if Game.all_ready():
			Game.start_match()
	else:
		Net.to_host(&"request_lobby_ready", [not Game.lobby_ready.has(Game.local_peer())])


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_host() and event.is_action_pressed(&"ui_accept"):
		_on_go()


func _process(delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_refresh()  # the recording marks and ready marks change without a signal
	if _qa_ready and Game.is_host() and Game.players.size() > 1 and Game.all_ready():
		_on_go()
	if Game.is_host() and Game.lobby_autostart > 0 and Game.players.size() >= Game.lobby_autostart:
		_autostart_t += delta
		if _autostart_t > 1.5:
			Game.start_match()  # P2-07: retried every frame until `match_ready()` (clip pre-share) lets it go
			if not Game.in_lobby:
				Game.lobby_autostart = 0
