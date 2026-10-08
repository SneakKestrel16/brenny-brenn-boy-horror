extends Node3D
## P2-10 lobby (doc 04 section 4, doc 06 section 11): players stand in the dark barn before the match.
## It loads `Game.LOBBY_WORLD` (hook: point it at the full farm), one static warm lantern (only ghosts
## flicker lights, doc 07 section 4), the Players node and a text roster. The host starts the match
## with Enter or the pause menu; `Game.match_ready()` is the P2-03 clip pre-share hook.
## Debug: `--lobby-start=<n>` (Game.lobby_autostart) starts when n players are present.

const DISCORD_LINE := "The creature can't hear Discord, and you can't hear where your friends are."
const VOICE_NAMES := {"off": "Off", "lobby_lines": "Lobby lines"}

var _roster: Label
var _autostart_t := 0.0


func _ready() -> void:
	var world := (load(Game.LOBBY_WORLD) as PackedScene).instantiate()
	world.name = "World"
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.4)
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var lantern := OmniLight3D.new()  # static: it blows out in the recording scene (P2-03), never flickers
	lantern.light_color = Color(1.0, 0.7, 0.4)
	lantern.light_energy = 2.0
	lantern.omni_range = 9.0
	lantern.position = Vector3(0, 2.2, -8)
	add_child(lantern)
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
	add_child(layer)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	Game.player_joined.connect(func(_p: int) -> void: _refresh())
	Game.player_left.connect(func(_p: int) -> void: _refresh())
	Game.voice_setting_changed.connect(func(_p: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var t := "The barn\n"
	for p in Game.players:
		var me := " (you)" if p == Game.local_peer() else ""
		var host := " [host]" if p == 1 else ""
		t += "  Player %d%s%s: voice %s\n" % [p, me, host, VOICE_NAMES.get(Game.voice_setting_of(p), "Off")]
	t += "\n" + DISCORD_LINE + "\n"
	t += "Enter: start the match   Esc: menu" if Game.is_host() else "Waiting for the host to start. Esc: menu"
	_roster.text = t


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_host() and event.is_action_pressed(&"ui_accept"):
		Game.start_match()


func _process(delta: float) -> void:
	if Game.is_host() and Game.lobby_autostart > 0 and Game.players.size() >= Game.lobby_autostart:
		_autostart_t += delta
		if _autostart_t > 1.5:
			Game.lobby_autostart = 0
			Game.start_match()
