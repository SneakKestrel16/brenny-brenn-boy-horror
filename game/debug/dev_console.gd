class_name DevConsole
extends CanvasLayer
## Dev command console (D-031), for building and playtesting until the game ships. Opens with the
## backquote key (`) in editor/debug runs, or in any build started with `--dev`. Commands that change
## the session run on the host only (CONTRACTS section 5); a client gets "host only". Every command is
## logged as `dev_command`, so a playtest log shows when the session was changed by hand.
## `--dev-exec="phase night; coins 50"` runs commands once the session starts (scripted QA runs).
## P5-36: the panel's left column is a mouse-driven dev menu (buttons for the common commands, a player picker for
## the ones that take a peer, a message box); every button just runs the same typed command line.
## Removed (or compiled out) before release: tracked in DECISIONS D-031.

const TOGGLE_KEY := KEY_QUOTELEFT
const PHASES: Array[StringName] = [&"day", &"dusk", &"night", &"harvest_moon", &"dawn"]
const CREATURE_STATES: Array[StringName] = [&"lurk", &"stalk", &"chase", &"retreat"]
## [label, command]; `{p}` becomes the picked player's peer id. Anything else stays typed.
const MENU := [
	["status", "status"], ["skip phase", "skip"], ["day", "phase day"], ["dusk", "phase dusk"], ["night", "phase night"],
	["harvest moon", "phase harvest_moon"], ["dawn", "phase dawn"], ["+50 coins", "coins 50"], ["fill fuel", "fuel"],
	["break gen", "gen damage"], ["fix gen", "gen repair"], ["grow ripe", "grow ripe"], ["debug view", "debug"],
	["kill", "kill {p}"], ["respawn", "respawn {p}"], ["Corrupt", "taint {p}"], ["wash", "taint {p} off"],
	["Shaken", "shaken {p}"], ["flag", "flag {p}"], ["whistle", "whistle {p}"], ["wave", "emote wave {p}"],
	["lurk", "creature lurk {p}"], ["stalk", "creature stalk {p}"], ["chase", "creature chase {p}"],
	["retreat", "creature retreat {p}"], ["jumpscare", "scare jumpscare {p}"], ["whisper", "whisper {p}"],
	["hallucination", "scare hallucination {p}"], ["nuke", "toy nuke"], ["nuke player", "toy nuke {p}"],
]
const HELP := """Commands (host only unless marked):
  help                      this list (any peer)
  status                    phase, time, coins, fuel, creature, players (any peer)
  skip                      end the current phase now
  phase day|dusk|night|harvest_moon|dawn  jump to that phase (advances through the ones between)
  time <s>                  set seconds into the current phase
  day <n>                   set the day number (scares and events that open on a day)
  tension <n>               set the AI Director's tension meter (0 to 100)
  length <phase> <s>        set a phase's length for this session
  coins <n>                 add n coins (negative takes them away)
  buy <item>                buy a store.json item as you, anywhere (the crate's other rules apply)
  pay                       early payment toward the debt as you (P4-07; one 50-coin step)
  fuel [s]                  add s seconds of fuel (default: fill the tank)
  cart [m]                  move the festival cart to m metres along its route; show its state
  gen damage|repair         break or fix the generator
  creature <state> [peer]   force lurk, stalk, chase or retreat (target defaults to you)
  grow [ripe|growing|empty] set every planted plot to a stage (default ripe)
  scare <kind> [peer]       play a scare now, past the AI Director: jumpscare, shed, whisper, own_voice,
                            wrong_count, hallucination, disarm_lunge, fake_out (target defaults to you)
  trap [bear|pit]           creature sets a trap at the free trap spot nearest you (default bear)
  flag [peer]               a player plants a flag at their feet, host rules apply (default: you)
  whistle [peer]            whistle as a player, through the host checks (default: you)
  emote <kind> [peer]       any emote id (data/emotes.json) as a player (default: you)
  kill [peer]               kill a player (default: you)
  respawn [peer]            bring a ghost back (default: you)
  ghost light|crow|rustle|caw [peer] [id]  a ghost power as that ghost, host rules apply (id: light or perch)
  taint [peer] [off]        Corrupt a player, or wash them clean with off (default: you)
  taint_source [kind]       leavings, dead_crow or strange_seeds 2 m north of you (default leavings)
  shaken [peer]             Shaken for taint.json's 60 s (default: you)
  msg <peer> <text>         show a text message on that player's screen only (P5-36)
  whisper [peer|name]       P5-43: the whisper scare on that one player only (default: you)
  debug                     toggle the debug view (F3)
  clear                     clear this console (any peer)"""

var _panel: PanelContainer
var _out: RichTextLabel
var _in: LineEdit
var _history: PackedStringArray = []
var _hist_i := 0
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _picker: OptionButton
var _msg_in: LineEdit
var _toast: Label
var _toast_t := 0.0


static func enabled() -> bool:
	return OS.is_debug_build() or OS.get_cmdline_user_args().has("--dev")


func _ready() -> void:
	layer = 100
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.offset_bottom = 460.0
	var row := HBoxContainer.new()
	_panel.add_child(row)
	row.add_child(_build_menu())
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
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
	_toast = Label.new()  # P5-36: a message from the host, on this screen only
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -80.0
	_toast.add_theme_font_size_override(&"font_size", 26)
	_toast.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override(&"outline_size", 8)
	_toast.visible = false
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	UiText.fit(_toast, 900)  # P5-44: a long host message wraps inside the safe margins
	Net.apply_received.connect(func(what: StringName, args: Array) -> void:
		if what == &"dev_message":
			_show_message(args[0]))
	_print("Dev console. Type help. %s" % ("You are the host." if Game.is_host() else "You are a client: most commands are host only."))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dev-exec="):
			_exec_later.call_deferred(a.substr("--dev-exec=".length()))


func _build_menu() -> Control:
	var col := VBoxContainer.new()
	_picker = OptionButton.new()
	_picker.tooltip_text = "Player for the commands that take one"
	col.add_child(_picker)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(330, 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3
	sc.add_child(grid)
	for item: Array in MENU:
		var b := Button.new()
		b.text = item[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_menu_run.bind(item[1]))
		grid.add_child(b)
	var mrow := HBoxContainer.new()
	col.add_child(mrow)
	_msg_in = LineEdit.new()
	_msg_in.placeholder_text = "message to the picked player"
	_msg_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_in.text_submitted.connect(func(_t: String) -> void: _menu_send())
	mrow.add_child(_msg_in)
	var send := Button.new()
	send.text = "Send"
	send.pressed.connect(_menu_send)
	mrow.add_child(send)
	return col


func _fill_picker() -> void:
	var keep := _picked()
	_picker.clear()
	for p: int in Game.players:
		var n := str(Net.profiles.get(p, {}).get("name", ""))
		_picker.add_item("%s%s (%d)" % [n if n != "" else "player", " [you]" if p == Game.local_peer() else "", p], p)
		if p == keep:
			_picker.select(_picker.item_count - 1)


func _picked() -> int:
	return _picker.get_selected_id() if _picker.item_count > 0 else Game.local_peer()


func _menu_run(line: String) -> void:
	line = line.replace("{p}", str(_picked()))
	_print("> " + line)
	_print(run(line))


func _menu_send() -> void:
	if _msg_in.text.strip_edges().is_empty():
		return
	_menu_run("msg {p} " + _msg_in.text.strip_edges())
	_msg_in.clear()


func _show_message(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_t = 8.0
	print("[dev] message: %s" % text)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.visible = _toast_t > 0.0


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
		_fill_picker()
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
			return HELP + ("\n  toy <name> [peer]   dev toy (nuke: blast centres on that player): shrink disco nuke low_gravity big_heads confetti chicken" if DevGate.unlocked() else "")
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
				return "? phase day|dusk|night|harvest_moon|dawn"
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
			if a.size() < 2 or not StringName(a[0]) in [&"day", &"dusk", &"night", &"harvest_moon"] or not a[1].is_valid_float() or a[1].to_float() <= 0.0:
				return "? length day|dusk|night|harvest_moon <seconds>"
			Clock.set_length(StringName(a[0]), a[1].to_float())
			return "%s is now %.0f s on the host (a client's countdown still shows its own length)" % [a[0], a[1].to_float()]
		"toy":  # P5-10: dev toys, closed unless DevGate.unlocked() (D-044); a closed gate answers like any unknown command
			if not DevGate.unlocked():
				return "? unknown command '%s' (help)" % cmd
			if a.is_empty():
				return "? toy shrink|disco|nuke|low_gravity|big_heads|confetti|chicken"
			var who := 0
			if a.size() > 1:  # P5-41: `toy nuke <player>` centres the blast on that player
				who = _peer_arg(a, 1)
				if who == 0:
					return "? no such player '%s'" % a[1]
			return main.get_node("DevToys").run(StringName(a[0]), who)
		"imposter":  # P5-11 hidden dev setting (D-044): closed unless DevGate.unlocked(); host only; peers see nothing different
			if not DevGate.unlocked() or not Game.is_host():
				return "? unknown command '%s' (help)" % cmd
			return Imposter.dev_force(a[0] if not a.is_empty() else "")
		"buy":
			if a.is_empty():
				return "? buy <store item id>"
			var why: StringName = main.get_node("Farm").store.buy(Game.local_peer(), StringName(a[0]), false)
			return "bought %s" % a[0] if why == &"" else "? %s" % why
		"coins":
			if a.is_empty() or not a[0].is_valid_int():
				return "? coins <n>"
			var farm := main.get_node_or_null("Farm")
			farm.add_coins(a[0].to_int(), &"dev", Game.local_peer())
			return "coins %d" % farm.coins
		"pay":  # P4-07: the sell box's pay_early verb, without the walk
			var dbt := get_tree().get_first_node_in_group(&"debt")
			var why: StringName = dbt.early_blocked()
			return "paid %d, still owed %d" % [dbt.pay_early(Game.local_peer()), dbt.owed] if why == &"" else "no payment: %s" % why
		"pumpkin":  # P4-05: host drives the Prize Pumpkin for QA
			var pk = main.get_node("Farm").targets.get("prize_pumpkin")
			if pk == null or a.is_empty() or not a[0] in ["plant", "water", "gnaw", "bite", "judge"]:
				return "? pumpkin plant|water|gnaw|bite|judge"
			match a[0]:
				"plant": pk.complete(&"plant", Game.local_peer(), Game.players[Game.local_peer()])
				"water":
					pk.watered_days += 1
					pk._send()
				"gnaw": pk.gnaw()
				"bite": pk.bite()
				"judge": pk.judge(main.get_node("Farm"))
			return "pumpkin %s, watered %d, drops %d" % [pk.size_name(), pk.watered_days, pk.drops]
		"cart":  # P4-12: host moves the festival cart along its route for QA
			var cart = main.get_node("Farm").cart
			if cart == null:
				return "no cart on this farm"
			if not a.is_empty() and a[0].is_valid_float():
				cart.offset = clampf(a[0].to_float(), 0.0, cart.length)
				cart._send()
			return "cart act %d, %.1f of %.1f m, x %.1f, loaded %s, out %s" % [cart.act, cart.offset, cart.length,
					cart.body.global_position.x, cart.loaded, cart.cart_out]
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
		"flag":
			var who := _peer_arg(a, 0)
			if who == 0:
				return "? flag [peer]"
			var at: Vector3 = Game.players[who].pos
			main.get_node("Farm").registry.request(who, &"place_flag", "flag:%.1f,%.1f" % [at.x, at.z])
			return "peer %d plants a flag at their feet (a 1 s hold, host rules apply)" % who
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
				return "? emote <id from data/emotes.json> [peer]"
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
			return "%d %s" % [p, "Corrupted" if on else "clean"]
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
		"msg":  # P5-36: one player's screen only; the peer argument works as everywhere (id, number, name)
			var p := _peer_arg(a, 0)
			if a.size() < 2 or p == 0:
				return "? msg <peer|name> <text>"
			var text := " ".join(a.slice(1))
			Log.event(&"dev_message", {"peer": p, "text": text})
			if p == Game.local_peer():
				_show_message(text)
			else:
				Net.to_peers(&"apply_dev_message", [text], [p])
			return "sent to %d" % p
		"whisper":  # P5-43: the director's whisper scare (doc 03 s13) on one player, through `scare` (private send)
			var p := _peer_arg(a, 0)
			if p == 0:
				return "? whisper [peer|name]"
			var reply := _host("scare", PackedStringArray(["whisper", str(p)]))
			return reply + " (no teammate clip 25 m+ away to replay: hush and log only, silent where the director would drop it)" if "no_teammate_clip" in reply else reply
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


## Peer id from args[i], or the local peer when absent. 0 when not a player in the session. A name (case-insensitive,
## a unique start is enough) works too.
func _peer_arg(a: PackedStringArray, i: int) -> int:
	var p := Game.local_peer() if a.size() <= i else (a[i].to_int() if a[i].is_valid_int() else _peer_by_name(a[i]))
	if not Game.players.has(p) and p >= 1 and p <= Game.players.size():
		p = Game.players.keys()[p - 1]  # joiners get random peer ids: a small number means the nth player (1 = host)
	return p if Game.players.has(p) else 0


func _peer_by_name(s: String) -> int:
	var hits: Array[int] = []
	for p: int in Game.players:
		var n := str(Net.profiles.get(p, {}).get("name", "")).to_lower()
		if n == s.to_lower():
			return p
		if n.begins_with(s.to_lower()):
			hits.append(p)
	return hits[0] if hits.size() == 1 else 0


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
