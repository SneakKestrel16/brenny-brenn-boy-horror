class_name DevConsole
extends CanvasLayer
## Dev command console (D-031), for building and playtesting until the game ships. Opens with the
## backquote key (`) in editor/debug runs, or in any build started with `--dev`. Commands that change
## the session run on the host only (CONTRACTS section 5); a client gets "host only". Every command is
## logged as `dev_command`, so a playtest log shows when the session was changed by hand.
## `--dev-exec="phase night; coins 50"` runs commands once the session starts (scripted QA runs).
## Removed (or compiled out) before release: tracked in DECISIONS D-031.

const TOGGLE_KEY := KEY_QUOTELEFT
const PHASES: Array[StringName] = [&"day", &"dusk", &"night", &"dawn"]
const CREATURE_STATES: Array[StringName] = [&"lurk", &"stalk", &"chase", &"retreat"]
const HELP := """Commands (host only unless marked):
  help                      this list (any peer)
  status                    phase, time, coins, fuel, creature, players (any peer)
  skip                      end the current phase now
  phase day|dusk|night|dawn jump to that phase (advances through the ones between)
  time <s>                  set seconds into the current phase
  day <n>                   set the day number (scares and events that open on a day)
  tension <n>               set the AI Director's tension meter (0 to 100)
  length <phase> <s>        set a phase's length for this session
  coins <n>                 add n coins (negative takes them away)
  fuel [s]                  add s seconds of fuel (default: fill the tank)
  gen damage|repair         break or fix the generator
  creature <state> [peer]   force lurk, stalk, chase or retreat (target defaults to you)
  grow [ripe|growing|empty] set every planted plot to a stage (default ripe)
  scare <kind> [peer]       play a scare now, past the AI Director: jumpscare, shed, whisper, own_voice,
                            wrong_count, hallucination, disarm_lunge, fake_out (target defaults to you)
  trap [bear|pit]           creature sets a trap at the free trap spot nearest you (default bear)
  whistle [peer]            whistle as a player, through the host checks (default: you)
  emote <kind> [peer]       wave, point, shrug or scream as a player (default: you)
  kill [peer]               kill a player (default: you)
  respawn [peer]            bring a ghost back (default: you)
  ghost light|crow|rustle|caw [peer] [id]  a ghost power as that ghost, host rules apply (id: light or perch)
  taint [peer] [off]        Taint a player, or wash them clean with off (default: you)
  taint_source [kind]       leavings, dead_crow or strange_seeds 2 m north of you (default leavings)
  shaken [peer]             Shaken for taint.json's 60 s (default: you)
  debug                     toggle the debug view (F3)
  clear                     clear this console (any peer)"""

var _panel: PanelContainer
var _out: RichTextLabel
var _in: LineEdit
var _history: PackedStringArray = []
var _hist_i := 0
var _mouse_before := Input.MOUSE_MODE_CAPTURED


static func enabled() -> bool:
	return OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev")


func _ready() -> void:
	layer = 100
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.offset_bottom = 300.0
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_out = RichTextLabel.new()
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.scroll_following = true
	_out.selection_enabled = true
	box.add_child(_out)
	_in = LineEdit.new()
	_in.placeholder_text = "dev command (help)"
	_in.text_submitted.connect(_submit)
	_in.gui_input.connect(_on_line_input)
	box.add_child(_in)
	add_child(_panel)
	_panel.visible = false
	_print("Dev console. Type help. %s" % ("You are the host." if Game.is_host() else "You are a client: most commands are host only."))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dev-exec="):
			_exec_later.call_deferred(a.substr("--dev-exec=".length()))


func _exec_later(lines: String) -> void:
	await get_tree().create_timer(0.5).timeout  # after Main's siblings finish _ready and the clock starts
	for line in lines.split(";", false):
		if line.strip_edges().begins_with("wait "):  # `wait <s>`: let joiners connect before the next command
			await get_tree().create_timer(line.strip_edges().substr(5).to_float()).timeout
			continue
		var reply := run(line.strip_edges())
		_print("> %s\n%s" % [line.strip_edges(), reply])
		print("[dev] %s -> %s" % [line.strip_edges(), reply.replace("\n", " | ")])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		_toggle()
		get_viewport().set_input_as_handled()


func _on_line_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		TOGGLE_KEY, KEY_ESCAPE:
			_toggle()
			_in.accept_event()
		KEY_UP, KEY_DOWN:
			if _history.is_empty():
				return
			_hist_i = clampi(_hist_i + (-1 if event.keycode == KEY_UP else 1), 0, _history.size())
			_in.text = _history[_hist_i] if _hist_i < _history.size() else ""
			_in.caret_column = _in.text.length()
			_in.accept_event()


func _toggle() -> void:
	_panel.visible = not _panel.visible
	Game.console_open = _panel.visible  # Player and HoldController ignore game input while typing
	if _panel.visible:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_in.clear()
		_in.call_deferred(&"grab_focus")
	else:
		_in.release_focus()
		Input.mouse_mode = _mouse_before


func _submit(line: String) -> void:
	_in.clear()
	line = line.strip_edges()
	if line.is_empty():
		return
	_history.append(line)
	_hist_i = _history.size()
	_print("> " + line)
	_print(run(line))


## Runs one command line and returns the reply. Public so tests and scripts can drive it.
func run(line: String) -> String:
	var a := line.split(" ", false)
	if a.is_empty():
		return ""
	var cmd := a[0].to_lower()
	var args := a.slice(1)
	match cmd:
		"help":
			return HELP
		"clear":
			_out.clear()
			return ""
		"status":
			return _status()
	if not Game.is_host():
		return "host only: ask the host to run it"
	var reply := _host(cmd, args)
	if not reply.begins_with("?"):
		Log.event(&"dev_command", {"peer": Game.local_peer(), "line": line})
	return reply


func _host(cmd: String, a: PackedStringArray) -> String:
	var main := get_parent()
	match cmd:
		"skip":
			Clock.t_phase = Clock.length_of(Clock.phase)
			return "ending %s" % Clock.phase
		"phase":
			if a.is_empty() or not StringName(a[0]) in PHASES:
				return "? phase day|dusk|night|dawn"
			var want := StringName(a[0])
			var guard := 0
			while Clock.phase != want and guard < PHASES.size():
				Clock.dev_advance()
				guard += 1
			return "now %s, day %d" % [Clock.phase, Clock.day]
		"time":
			if a.is_empty() or not a[0].is_valid_float():
				return "? time <seconds>"
			Clock.t_phase = clampf(a[0].to_float(), 0.0, Clock.length_of(Clock.phase))
			return "%s at %.0f s of %.0f" % [Clock.phase, Clock.t_phase, Clock.length_of(Clock.phase)]
		"day":
			if a.is_empty() or not a[0].is_valid_int() or a[0].to_int() < 1:
				return "? day <n>"
			Clock.day = a[0].to_int()
			Clock._broadcast()
			return "day %d" % Clock.day
		"tension":
			var dir := main.get_node("AiDirector")
			if a.is_empty() or not a[0].is_valid_float():
				return "? tension <n>"
			dir._add(a[0].to_float() - dir.meter)
			return "tension %.0f, %s" % [dir.meter, dir.phase]
		"length":
			if a.size() < 2 or not StringName(a[0]) in [&"day", &"dusk", &"night"] or not a[1].is_valid_float() or a[1].to_float() <= 0.0:
				return "? length day|dusk|night <seconds>"
			Clock.set_length(StringName(a[0]), a[1].to_float())
			return "%s is now %.0f s on the host (a client's countdown still shows its own length)" % [a[0], a[1].to_float()]
		"coins":
			if a.is_empty() or not a[0].is_valid_int():
				return "? coins <n>"
			var farm := main.get_node_or_null("Farm")
			farm.add_coins(a[0].to_int(), &"dev", Game.local_peer())
			return "coins %d" % farm.coins
		"fuel":
			var gen := main.get_node_or_null("Generator")
			var s: float = a[0].to_float() if not a.is_empty() and a[0].is_valid_float() else gen.tank_s
			gen.add_fuel(s)
			return "fuel %.0f / %.0f s" % [gen.fuel_s, gen.tank_s]
		"gen":
			var gen := main.get_node_or_null("Generator")
			if a.is_empty() or not a[0] in ["damage", "repair"]:
				return "? gen damage|repair"
			if a[0] == "damage":
				gen.damage()
			else:
				gen.repair()
			return "generator %s" % ("damaged" if gen.damaged else "repaired")
		"creature":
			if a.is_empty() or not StringName(a[0]) in CREATURE_STATES:
				return "? creature lurk|stalk|chase|retreat [peer]"
			var target := _peer_arg(a, 1)
			if target == 0:
				return "? no such peer"
			main.get_node("Creature").force_state(StringName(a[0]), &"dev", target)
			return "creature %s, target %d" % [a[0], target]
		"grow":
			var stage := StringName(a[0]) if not a.is_empty() else &"ripe"
			if not stage in [&"ripe", &"growing", &"empty"]:
				return "? grow ripe|growing|empty"
			var farm := main.get_node_or_null("Farm")
			var n := 0
			for t in farm.targets.values():
				if t.has_method(&"advance_day") and t.state != &"empty" and t.state != stage:
					t.state = stage
					t.watered = false
					if t.crop == &"":  # an empty plot being grown by hand gets the default seed
						t.crop = t.crop_for(&"plant")
					t.age = 0 if stage != &"ripe" else int(Data.value(&"crops", t.crop, &"grow_days"))
					farm.plot_changed(t)
					n += 1
			return "%d plots set to %s" % [n, stage]
		"trap":
			var kind := StringName(a[0]) if not a.is_empty() else &"bear"
			if not kind in [&"bear", &"pit"]:
				return "? trap bear|pit"
			var creature := main.get_node("Creature")
			var me: Vector3 = Game.players[Game.local_peer()].pos
			var best: Node3D = null
			for n: Node3D in get_tree().get_nodes_in_group(&"trap_spots"):
				if creature._traps.has(String(n.name)) or (kind == &"pit" and n.get_meta("kind", "") == "deep"):
					continue
				if best == null or n.global_position.distance_to(me) < best.global_position.distance_to(me):
					best = n
			if best == null:
				return "? no free trap spot"
			creature._arm(best, kind, {"dev": true})
			return "%s set at %s, %.0f m away" % [kind, best.name, best.global_position.distance_to(me)]
		"scare":
			var scares := main.get_node("Scares")
			var target := _peer_arg(a, 1)
			if a.is_empty() or not scares._d.has(StringName(a[0])):
				return "? scare <kind> [peer] (help)"
			if a[0] == "fake_out":
				return "fake-out" if scares._fake_out(true) else "? no living player outdoors (or no crow perch)"
			if target == 0:
				return "? no such peer"
			var why: String = scares.fits(StringName(a[0]), target)
			if why == "not_built" or why == "not_alive":
				return "? scare %s on %d: %s" % [a[0], target, why]
			scares.fire(StringName(a[0]), target, {}, true)
			return "scare %s on %d%s" % [a[0], target, " (forced past: %s)" % why if why else ""]
		"whistle":
			var p := _peer_arg(a, 0)
			if p == 0:
				return "? no such peer"
			var why: StringName = main.get_node("WhistleEmotes").whistle(p)
			return "%d whistled" % p if why == &"" else "refused: %s" % why
		"emote":
			var p := _peer_arg(a, 1)
			if a.is_empty() or p == 0:
				return "? emote wave|point|shrug|scream [peer]"
			var why: StringName = main.get_node("WhistleEmotes").emote(p, StringName(a[0]))
			return "%d: %s" % [p, a[0]] if why == &"" else "refused: %s" % why
		"kill":
			var p := _peer_arg(a, 0)
			if p == 0 or Game.is_ghost(p):
				return "? no living peer %s" % (a[0] if not a.is_empty() else "")
			main.get_node("Death").die(p, &"dev")
			return "killed %d" % p
		"respawn":
			var p := _peer_arg(a, 0)
			if p == 0 or not Game.is_ghost(p):
				return "? peer is not a ghost"
			main.get_node("Death").respawn(p)
			return "respawned %d" % p
		"ghost":
			var p := _peer_arg(a, 1)
			if a.is_empty() or not a[0] in ["light", "crow", "rustle", "caw"] or p == 0:
				return "? ghost light|crow|rustle|caw [peer] [id]"
			var why: String = main.get_node("Death/GhostPowers").act(p, StringName(a[0]), a[2] if a.size() > 2 else "")
			return "ghost %s by %d%s" % [a[0], p, ": refused, " + why if why else ""]
		"taint":
			var p := Game.local_peer() if not a.is_empty() and a[0] == "off" else _peer_arg(a, 0)
			var on := not a.has("off")
			if p == 0:
				return "? no such peer"
			main.get_node("Taint").set_taint(p, on, &"dev")
			return "%d %s" % [p, "Tainted" if on else "clean"]
		"taint_source":
			var kind := StringName(a[0]) if not a.is_empty() else &"leavings"
			if not kind in [&"leavings", &"dead_crow", &"strange_seeds"]:
				return "? taint_source leavings|dead_crow|strange_seeds"
			var me: Dictionary = Game.players.get(Game.local_peer(), {})
			if not me.has("pos"):
				return "? no body"
			var at: Vector3 = me.pos + Vector3(0, 0, -2)  # 2 m north of you
			return "%s %d at %s" % [kind, main.get_node("Taint").add_source(kind, at), at]
		"shaken":
			var p := _peer_arg(a, 0)
			if p == 0 or Game.is_ghost(p):
				return "? no living peer"
			main.get_node("TrapRace").shake(p)
			return "%d Shaken" % p
		"debug":
			var dv := main.get_node_or_null("DebugView")
			if dv == null:
				for c in main.get_children():
					if c is DebugView:
						dv = c
			if dv:
				dv.visible = not dv.visible
				return "debug view %s" % ("on" if dv.visible else "off")
			return "? no debug view"
	return "? unknown command '%s' (help)" % cmd


## Peer id from args[i], or the local peer when absent. 0 when not a player in the session.
func _peer_arg(a: PackedStringArray, i: int) -> int:
	var p := Game.local_peer() if a.size() <= i else (a[i].to_int() if a[i].is_valid_int() else 0)
	if not Game.players.has(p) and p >= 1 and p <= Game.players.size():
		p = Game.players.keys()[p - 1]  # joiners get random peer ids: a small number means the nth player (1 = host)
	return p if Game.players.has(p) else 0


func _status() -> String:
	var main := get_parent()
	var lines := PackedStringArray()
	lines.append("day %d, %s, %.0f / %.0f s" % [Clock.day, Clock.phase, Clock.t_phase, Clock.length_of(Clock.phase)])
	var farm := main.get_node_or_null("Farm")
	if farm:
		lines.append("coins %d" % farm.coins)
	var gen := main.get_node_or_null("Generator")
	if gen:
		lines.append("fuel %.0f / %.0f s%s" % [gen.fuel_s, gen.tank_s, ", damaged" if gen.damaged else ""])
	var cr := main.get_node_or_null("Creature")
	if cr:
		lines.append("creature %s, target %d" % [cr.state, cr.target])
	var ps := PackedStringArray()
	for p in Game.players:
		ps.append("%d%s" % [p, " (ghost)" if Game.is_ghost(p) else ""])
	lines.append("players " + ", ".join(ps) + "  (you: %d%s)" % [Game.local_peer(), ", host" if Game.is_host() else ""])
	return "\n".join(lines)


func _print(text: String) -> void:
	if not text.is_empty():
		_out.add_text(text + "\n")
