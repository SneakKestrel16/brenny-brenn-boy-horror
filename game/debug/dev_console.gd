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
  length <phase> <s>        set a phase's length for this session
  coins <n>                 add n coins (negative takes them away)
  fuel [s]                  add s seconds of fuel (default: fill the tank)
  gen damage|repair         break or fix the generator
  creature <state> [peer]   force lurk, stalk, chase or retreat (target defaults to you)
  kill [peer]               kill a player (default: you)
  respawn [peer]            bring a ghost back (default: you)
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
