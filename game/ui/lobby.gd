extends Control
## P2-10, P4-23 lobby (doc 05 section 16): a menu screen before the match. Nobody spawns until the host starts
## the season; then everyone changes to Main and spawns on the farm. Left: the role cards (P4-09). Right: the
## roster with each player's ready mark and voice setting, the join code, the group settings (P4-11, doc 01
## "Difficulty and group settings"; the host sets them, everyone sees them), Ready (clients) and Start the
## season (host, once every other human is ready). `Game.match_ready()` is the P2-03 clip pre-share hook.
## Debug: `--lobby-start=<n>` (Game.lobby_autostart) starts when n players are present, ready or not;
## `--lobby-ready` goes through Ready and Start the season instead; `--role=<id>` picks a role.

const DISCORD_LINE := "The creature can't hear Discord, and you can't hear where your friends are."
const VOICE_NAMES := {"off": "Off", "lobby_lines": "Lobby lines"}
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"nightmare"]

## P4-09 role cards (doc 01 "Picking a role"): one per role with its perk, a taken one greyed out, "No role" always open.
const PERK_TEXT := {&"farmer": "+1 crop every 5th harvest", &"rancher": "faster round-up, hears animals from further",
		&"mechanic": "repairs and refuels faster", &"tracker": "disarms faster, spots clues further",
		&"carpenter": "builds and fixes fences faster, builds cheaper", &"medic": "frees teammates faster, cheaper bills",
		&"night_owl": "quieter at night, picks moonflowers faster", &"radio_operator": "walkie reaches further, voice carries",
		&"warden": "more flare shots, faster reload", &"medium": "ghost voices through less static"}

var _roster: Label
var _cards: VBoxContainer
var _difficulty: OptionButton
var _streamer: CheckBox
var _go: Button  ## host: Start the season; client: Ready
var _autostart_t := 0.0
var _qa_ready := false


## P4-23: no bodies in the lobby. Voice hangs each speaker's emitter on `Players.player(peer)`; here they all
## stand at the listener, so the lobby still talks (unplaced).
class Voices extends Node3D:
	func _ready() -> void:
		var ear := AudioListener3D.new()
		add_child(ear)
		ear.make_current()

	func player(peer: int) -> Node:
		var n := get_node_or_null(str(peer))
		if n == null and Game.players.has(peer):
			n = Node3D.new()
			n.name = str(peer)
			add_child(n)
		return n


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Clock.phase = &"night"  # the clock is idle in the lobby; Clock.start() resets it at match start
	var voices := Voices.new()
	voices.name = "Players"
	add_child(voices)
	var bg := ColorRect.new()  # the main menu's colour
	bg.color = Color(0.03, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 40)
	margin.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	_heading(left, "Pick a role (kept for the season)")
	_cards = VBoxContainer.new()
	left.add_child(_cards)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 10)
	cols.add_child(right)
	_heading(right, "The lobby")
	_roster = Label.new()
	_roster.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_roster)
	_heading(right, "Settings")
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Difficulty"
	row.add_child(l)
	_difficulty = OptionButton.new()
	_difficulty.item_selected.connect(func(i: int) -> void:
		Game.set_group_settings(StringName(_difficulty.get_item_metadata(i)), Game.streamer_safe))
	row.add_child(_difficulty)
	right.add_child(row)
	_streamer = CheckBox.new()
	_streamer.text = "Streamer-safe (no voice replays in the Dawn Report)"
	_streamer.toggled.connect(func(on: bool) -> void: Game.set_group_settings(Game.difficulty, on))
	right.add_child(_streamer)
	_go = Button.new()
	_go.custom_minimum_size.y = 40
	_go.pressed.connect(_on_go)
	right.add_child(_go)
	var menu := HBoxContainer.new()
	var settings := Button.new()
	settings.text = "Settings"
	settings.pressed.connect(func() -> void: add_child(SettingsMenu.new()))
	menu.add_child(settings)
	var leave := Button.new()
	leave.text = "Leave to menu"
	leave.pressed.connect(Game.leave_session)
	menu.add_child(leave)
	right.add_child(menu)
	Game.roles_changed.connect(_refresh_cards)
	_refresh_cards()
	var pause := PauseMenu.new()  # Esc, voice volumes, and the host-left card
	pause.name = "PauseMenu"
	add_child(pause)
	Game.player_joined.connect(func(_p: int) -> void: _refresh())
	Game.player_left.connect(func(_p: int) -> void: _refresh_cards(); _refresh())  # a leaver frees their role card
	Game.voice_setting_changed.connect(func(_p: int) -> void: _refresh())
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


func _heading(parent: Control, text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override(&"font_size", 24)
	parent.add_child(h)


func _refresh_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	var mine := Roles.of(Game.local_peer())
	var taken := {}  # role -> true when someone else holds it
	for p in Game.players:
		if p != Game.local_peer() and Roles.of(p) != &"":
			taken[Roles.of(p)] = true
	var locked := not Game.season_uids.is_empty()  # a loaded season keeps its roles (Roles.on_request refuses)
	_card(&"", "No role", "", mine == &"", locked)
	for id in Roles.ids():
		_card(id, str(Data.record(&"roles", id).name), PERK_TEXT.get(id, ""), mine == id, taken.has(id) or locked)
	if locked:
		var l := Label.new()
		l.text = "Roles are kept from the saved season."
		_cards.add_child(l)


func _card(id: StringName, title: String, perk: String, mine: bool, taken: bool) -> void:
	var b := Button.new()
	b.text = "%s%s%s" % ["> " if mine else "  ", title, ("  -  " + perk) if perk != "" else ""] + ("  (taken)" if taken and not mine else "")
	b.disabled = taken
	b.flat = not mine
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(pick.bind(id))
	_cards.add_child(b)


## Ask the host for `id` (empty = no role); the host refuses a taken role or a started match.
func pick(id: StringName) -> void:
	if Game.is_host():
		Roles.on_request(1, id)
	else:
		Net.to_host(&"request_role", [String(id)])


func _refresh() -> void:
	var t := ""
	for p in Game.players:
		var me := " (you)" if p == Game.local_peer() else ""
		var host := " [host]" if p == 1 else ""
		var who: String = Net.profiles.get(p, {}).get("name", "Player %d" % p)  # one source: Net.profiles (Q-054 item 3)
		var rec := ", recording" if Voice._lit.has(p) else ""  # Voice has no public accessor yet; reads its tally-lamp set
		var ready := "" if p == 1 else ("  READY" if Game.lobby_ready.has(p) else "  not ready")
		var role := Roles.of(p)
		var role_name := str(Data.record(&"roles", role).name) if role != &"" else "no role"
		t += "%s%s%s: %s, voice %s%s%s\n" % [who, me, host, role_name, VOICE_NAMES.get(Game.voice_setting_of(p), "Off"), rec, ready]
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
	if Game.is_host():
		_go.text = "Start the season" if Game.all_ready() else "Waiting for everyone to be ready"
		_go.disabled = not Game.all_ready()
	else:
		_go.text = "Ready (waiting for the host)" if Game.lobby_ready.has(Game.local_peer()) else "Ready"
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
