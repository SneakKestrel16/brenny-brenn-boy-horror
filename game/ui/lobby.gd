extends Node3D
## P2-10 lobby (doc 04 section 4, doc 06 section 11): players stand in the dark barn before the match.
## It loads `Game.world_path()` (the full farm with `--full-farm`) under WorldLook at night (every light goes
## through the render layer, doc 07 section 4), the Players node and a text roster. The host starts the match
## with Enter or the pause menu; `Game.match_ready()` is the P2-03 clip pre-share hook.
## Debug: `--lobby-start=<n>` (Game.lobby_autostart) starts when n players are present.

const DISCORD_LINE := "The creature can't hear Discord, and you can't hear where your friends are."
const VOICE_NAMES := {"off": "Off", "lobby_lines": "Lobby lines"}

## P4-09 role cards (doc 01 "Picking a role"): one per role with its perk, a taken one greyed out, "No role" always open.
const PERK_TEXT := {&"farmer": "+1 crop every 5th harvest", &"rancher": "faster round-up, hears animals from further",
		&"mechanic": "repairs and refuels faster", &"tracker": "disarms faster, spots clues further",
		&"carpenter": "builds and fixes fences faster, builds cheaper", &"medic": "frees teammates faster, cheaper bills",
		&"night_owl": "quieter at night, picks moonflowers faster", &"radio_operator": "walkie reaches further, voice carries",
		&"warden": "more flare shots, faster reload", &"medium": "ghost voices through less static"}

var _roster: Label
var _cards: VBoxContainer
var _autostart_t := 0.0


func _ready() -> void:
	var world := (load(Game.world_path()) as PackedScene).instantiate()
	world.name = "World"
	add_child(world)
	Clock.phase = &"night"  # the clock is idle in the lobby; WorldLook reads the phase. Clock.start() resets it at match start.
	var look := Node.new()  # lighting and the building lights come from the render layer, not from here
	look.set_script(load("res://game/render/world_look.gd"))
	look.name = "Look"
	add_child(look)
	var players := Node3D.new()
	players.set_script(load("res://game/player/players.gd"))
	players.name = "Players"
	add_child(players)
	var layer := CanvasLayer.new()
	_roster = Label.new()
	_roster.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_roster.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_roster.offset_top = 60
	_roster.offset_right = -24
	_roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_roster.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	layer.add_child(_roster)
	_cards = VBoxContainer.new()
	_cards.position = Vector2(24, 60)
	layer.add_child(_cards)
	Game.roles_changed.connect(_refresh_cards)
	_refresh_cards()
	add_child(layer)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	Game.player_joined.connect(func(_p: int) -> void: _refresh())
	Game.player_left.connect(func(_p: int) -> void: _refresh())
	Game.voice_setting_changed.connect(func(_p: int) -> void: _refresh())
	_refresh()
	for a in OS.get_cmdline_user_args():  # QA: `--role=<id>` picks a role once the barn is up
		if a.begins_with("--role="):
			get_tree().create_timer(1.0).timeout.connect(pick.bind(StringName(a.get_slice("=", 1))))


func _refresh_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	var mine := Roles.of(Game.local_peer())
	var taken := {}  # role -> true when someone else holds it
	for p in Game.players:
		if p != Game.local_peer() and Roles.of(p) != &"":
			taken[Roles.of(p)] = true
	_card(&"", "No role", "", mine == &"", false)
	for id in Roles.ids():
		_card(id, str(Data.record(&"roles", id).name), PERK_TEXT.get(id, ""), mine == id, taken.has(id))


func _card(id: StringName, title: String, perk: String, mine: bool, taken: bool) -> void:
	var b := Button.new()
	b.text = "%s%s%s" % ["> " if mine else "  ", title, ("  -  " + perk) if perk != "" else ""] + ("  (taken)" if taken else "")
	b.disabled = taken
	b.flat = true
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


## R cycles through the free roles and back to none (the mouse belongs to the camera in the barn).
func _cycle() -> void:
	var order: Array[StringName] = [&""]
	order.append_array(Roles.ids())
	var i := order.find(Roles.of(Game.local_peer()))
	for k in range(1, order.size() + 1):
		var cand := order[(i + k) % order.size()]
		var free := true
		for p in Game.players:
			free = free and (p == Game.local_peer() or cand == &"" or Roles.of(p) != cand)
		if free:
			pick(cand)
			return


func _refresh() -> void:
	var t := "The barn\n"
	for p in Game.players:
		var me := " (you)" if p == Game.local_peer() else ""
		var host := " [host]" if p == 1 else ""
		var who: String = Net.profiles.get(p, {}).get("name", "Player %d" % p)  # one source: Net.profiles (Q-054 item 3)
		var rec := ", recording" if Voice._lit.has(p) else ""  # Voice has no public accessor yet; reads its tally-lamp set
		t += "  %s%s%s: voice %s%s\n" % [who, me, host, VOICE_NAMES.get(Game.voice_setting_of(p), "Off"), rec]
	var code := Net.join_code()  # D-049: the fallback when a rejoin prompt fails
	if code != "":
		t += "\nJoin code: %s" % code
	t += "\n" + DISCORD_LINE + "\n"
	t += "R: pick a role   "
	t += "Enter: start the match   Esc: menu" if Game.is_host() else "Waiting for the host to start. Esc: menu"
	_roster.text = t


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and not Game.console_open:
		_cycle()
	if Game.is_host() and event.is_action_pressed(&"ui_accept"):
		Game.start_match()


func _process(delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_refresh()  # the recording marks change without a signal
	if Game.is_host() and Game.lobby_autostart > 0 and Game.players.size() >= Game.lobby_autostart:
		_autostart_t += delta
		if _autostart_t > 1.5:
			Game.start_match()  # P2-07: retried every frame until `match_ready()` (clip pre-share) lets it go
			if not Game.in_lobby:
				Game.lobby_autostart = 0
