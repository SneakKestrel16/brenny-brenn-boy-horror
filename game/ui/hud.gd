extends CanvasLayer
## P1-16 (Q-046): the plainest prompt layer a first-time tester needs. Text only, no art, no markers
## pointing at anything (doc 05 section 3 "No HUD markers"; doc 01 "Onboarding" wants in-world intros, which
## come later). Local player only. Built in code; the same on a headless run (controls exist, nothing draws).

const Crops := preload("res://game/farming/crops.gd")
const HINT_S := 20.0  ## controls hint stays this long after first spawn (placeholder)
const PHASE_TEXT := {&"day": "Daylight", &"dusk": "Dusk", &"night": "NIGHT", &"dawn": "Dawn", &"harvest_moon": "HARVEST MOON"}
const VERB_TEXT := {&"plant": "Plant", &"water": "Water", &"harvest": "Harvest", &"sell": "Sell the crop",
		&"fill_can": "Fill the watering can", &"pry": "Pry free", &"refuel": "Refuel",
		&"disarm_bear": "Disarm the bear trap", &"fill_pit": "Fill the pit", &"place_flag": "Plant a flag", &"remove_flag": "Pull up the flag",
		&"hang_trap": "Hang the trap on the board", &"take_shovel": "Take the shovel", &"return_shovel": "Hang the shovel back", &"take_trap": "Pick up the trap",
		&"take_can": "Pick up the can", &"drop_can": "Put the can down", &"wash": "Wash at the well",
		&"clear_plot": "Clear the dead crop", &"pay_early": "Pay the bank early"}
const REFUSED_TEXT := {&"locked": "Locked: needs more players, or buy it at the store", &"need_shovel": "You need the shovel", &"hands_full": "Your hands are full",
		&"pegboard_full": "No free hook", &"flag_here": "A flag is already here", &"flag_limit": "All your flags are out: pull one up first",
		&"no_flag": "No flag here", &"not_armed": "Nothing set here",
		&"no_can": "You need a watering can", &"no_fuel_can": "You need the fuel can", &"can_taken": "Someone has it", &"has_fuel_can": "The can is full",
		&"not_tainted": "Your hands are clean", &"no_coins": "Not enough coins", &"no_seeds": "Buy seeds at the store", &"locked_crop": "That seed is not on sale yet",
		&"too_far": "Stand at the shipping crate", &"locked_item": "Not on sale yet", &"owned": "You have that already", &"max_bought": "The crate has no more",
		&"plots_max": "No more plots can be opened", &"no_flare": "No flare gun", &"flare_empty": "The flare gun is empty", &"flare_full": "The flare gun is full", &"flare_reloading": "Reloading",
		&"no_scarecrow": "No scarecrow to put up", &"too_close": "Too close to another scarecrow"}

var player: CharacterBody3D
var hold: Node  ## the player's HoldController

var _top: Label
var _prompt: Label
var _banner: Label
var _hint: Label
var _bar: ProgressBar
var _dot: ColorRect
var _hotbar: HBoxContainer  ## P4-22: what this player holds, one slot each with a one-line use hint
var _t := 0.0


func _ready() -> void:
	layer = 10
	_top = _label(Vector2(16, 12), 20)
	_prompt = _label(Vector2.ZERO, 26)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -170
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner = _label(Vector2.ZERO, 34)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 90
	_banner.offset_left = -420
	_banner.offset_right = 420
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _label(Vector2.ZERO, 22)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)  # P4-32: left edge, clear of the hold prompt
	_hint.offset_left = 16
	_hint.offset_right = 536
	_hint.offset_top = -190
	_hint.text = "CONTROLS\n%s  move\n%s  sprint (runs out, and it is loud)\n%s  crouch (quiet)\n%s  stand still (silent)\nHold %s  work the thing you look at (cans: pick up)
%s  put a can down\nHold %s  plant a flag where you look\n%s  whistle (carries far)\nHold %s  emote (move the mouse, let go)\n%s  free the mouse" % [
			_move_keys(), _key(&"sprint"), _key(&"crouch"), _key(&"go_still"), _key(&"interact"), _key(&"drop"), _key(&"alt_use"),
			_key(&"whistle"), _key(&"emote_wheel"), _key(&"pause")]
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(220, 14)
	_bar.max_value = float(Data.value(&"labor", &"sprint", &"max_s"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.9, 0.9)
	_bar.add_theme_stylebox_override(&"fill", fill)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.offset_left = 16
	_bar.offset_top = -34
	_bar.offset_right = 236
	_bar.offset_bottom = -20
	add_child(_bar)
	_dot = ColorRect.new()  # D-047 centre dot: a plain dot, points at nothing
	_dot.color = Color(1, 1, 1, 0.8)
	_dot.custom_minimum_size = Vector2(4, 4)
	_dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dot.offset_left = -2
	_dot.offset_right = 2
	_dot.offset_top = -2
	_dot.offset_bottom = 2
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dot)
	var map := Control.new()  # P4-24: top-right minimap (game/ui/minimap.gd)
	map.set_script(preload("res://game/ui/minimap.gd"))
	map.player = player
	add_child(map)
	_hotbar = HBoxContainer.new()
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.offset_bottom = -12
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	var menu := CanvasLayer.new()  # P4-22: the shipping crate's list
	menu.set_script(preload("res://game/ui/store_menu.gd"))
	menu.hud = self
	add_child(menu)


## P3-07 tester text until the black-hands model and the heartbeat land (doc 01 "The Taint" cues are diegetic).
func _status() -> String:
	var out := ""
	if bool(Game.players.get(Game.local_peer(), {}).get("tainted", false)) and not player.ghost:
		out += "\nTainted: wash at the well"
	if player.shaken_s > 0.0:
		out += "\nShaken: out of breath for %d s" % ceili(player.shaken_s)
	if Quirks.mine != &"" and not player.ghost:
		out += "
Quirk: %s (only you can see this)" % Quirks.display_name(Quirks.mine)  # P5-09
	return out


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	var left := maxf(Clock.length_of(Clock.phase) - Clock.t_phase, 0.0)
	var farm := get_tree().get_first_node_in_group(&"farm")
	_top.text = "Season %d  Day %d  %s  %d:%02d left\nCoins %d%s" % [Game.season_no, Clock.day, PHASE_TEXT.get(Clock.phase, String(Clock.phase)),
			int(left) / 60, int(left) % 60, farm.coins if farm else 0,
			_status()]
	_bar.max_value = player.sprint_max()  # Taint and Shaken shorten the sprint (P3-07)
	_bar.value = player.stamina
	_dot.visible = bool(Settings.get_value(&"centre_dot")) and not player.ghost
	_bar.modulate = Color(1, 0.4, 0.3) if player.exhausted else Color.WHITE
	_bar.visible = not player.ghost
	_hint.visible = _t < HINT_S and not Game.console_open  # hidden behind the pause menu
	_hint.modulate.a = clampf((HINT_S - _t) / 3.0, 0.0, 1.0)
	var text := ""
	if player.ghost:
		text = "YOU ARE DEAD. You are a ghost: nobody hears or sees you.\n%s / %s watch a friend. You come back at dawn.
%s  disturb the nearest light   %s  rustle the corn you are in   %s  ride a crow (once a night; %s caws)" % [
				_key(&"spectate_prev"), _key(&"spectate_next"), _key(&"use_tool"), _key(&"alt_use"), _key(&"lantern"), _key(&"use_tool")]
	elif player.pinned:
		text = "CAUGHT IN A TRAP. Hold %s on the trap to pry free. A friend can help." % _key(&"interact")
	_banner.text = text
	var hs: Array = hold.hold_state()
	var prompt := ""
	if hs[0] != &"":
		prompt = ("%s... %d%%  %s" % [_verb_text(hs[0]), int(hs[1] * 100.0), hs[2]]).strip_edges()
	elif hold.aimed_verb != &"":
		prompt = "Hold %s: %s" % [_key(&"interact"), _verb_text(hold.aimed_verb)]
		var plot: Node = hold.aimed_target
		if farm and String(hold.aimed_verb).begins_with("plant") and plot and plot.has_method(&"crop_for") and not plot.locked and farm.store.seed_count(plot.crop_for(hold.aimed_verb)) == 0:
			prompt = REFUSED_TEXT[&"no_seeds"]  # P4-22, D-093: planting uses a seed bought at the crate
	elif hold.held_can_id() >= 0:
		prompt = "Tap %s: put the can down" % _key(&"drop")
	if prompt == "" and farm:
		prompt = farm.store.prompt_text(player.global_position)
	var why: StringName = hold.fresh_refusal()
	if why != &"" and hs[0] == &"":
		prompt = REFUSED_TEXT.get(why, String(why).capitalize().replace("_", " "))
	_prompt.text = prompt
	_prompt.visible = not Game.console_open  # P4-22: not through the store menu
	_show_hotbar(_slots(farm) if farm and not player.ghost else [])


## P4-22 (CEO session): [name, one-line use hint] for each thing the local player holds or the team owns.
## Read from the replicated `carry` and store state; nothing here is authoritative.
func _slots(farm: Node) -> Array:
	var me := Game.local_peer()
	var c: Dictionary = farm.carry.get(me, {})
	var st: Node = farm.store
	var out := []
	match c.get("held_kind", &""):
		&"water": out.append(["Watering can %d/%d" % [int(c.get("can", 0)), int(Data.value(&"labor", &"can", &"capacity"))],
				"Hold %s on a growing plot: water. Well: refill. %s: put down" % [_key(&"interact"), _key(&"drop")]])
		&"fuel": out.append(["Fuel can, %s" % ("full" if c.get("fuel_can", false) else "empty"),
				"Hold %s on the generator: refuel. %s: put down" % [_key(&"interact"), _key(&"drop")]])
	if farm.targets.has("prize_pumpkin") and farm.targets["prize_pumpkin"].carrier == me:
		out.append(["Prize Pumpkin", "Load it on the cart. %s: set it down" % _key(&"drop")])
	if c.get("shovel", false):
		out.append(["Shovel", "Hold %s on a pit: fill it. Pegboard: hang it back" % _key(&"interact")])
	if c.get("trap", false):
		out.append(["Bear trap", "Hold %s on the pegboard: hang it" % _key(&"interact")])
	var seeds := PackedStringArray()  # D-093: only once the team owns seeds, bought at the crate
	for crop in Crops.ids():
		if st.seed_count(crop) > 0:
			seeds.append("%s %d" % [Data.record(&"crops", crop).get("name", crop), st.seed_count(crop)])
	if not seeds.is_empty():
		var sow: StringName = farm.planting_seed()
		out.append(["Seeds: " + ", ".join(seeds), "Hold %s on an empty plot: plant %s. %s: change" % [
				_key(&"interact"), Data.record(&"crops", sow).get("name", sow), _key(&"cycle_seed")]])
	if int(c.get("bag", 0)) > 0:
		out.append(["Crops %d/%d" % [int(c.bag), int(Data.value(&"labor", &"carry", &"capacity")) + int(Quirks.local(&"carry_extra_slots", 0))], "Hold %s at the town stand: sell" % _key(&"interact")])
	if int(st.team.get(&"flare_gun", 0)) > 0:
		out.append(["Flare gun, %d shot%s" % [st.flare_shots, "" if st.flare_shots == 1 else "s"], "%s: fire (scares it off, loud)" % _key(&"fire_flare")])
	if int(st.team.get(&"scarecrow", 0)) > st.scarecrows.size():
		out.append(["Scarecrow x%d" % (int(st.team.scarecrow) - st.scarecrows.size()), "%s: put one up where you stand" % _key(&"place_scarecrow")])
	if st.owns(me, &"quiet_watering_can"):
		out.append(["Quiet watering can", "Water as usual: slower, heard less far"])
	if st.owns(me, &"walkie_talkie"):
		out.append(["Walkie-talkie, %d spare batter%s" % [int(st.team.get(&"walkie_battery", 0)), "y" if int(st.team.get(&"walkie_battery", 0)) == 1 else "ies"],
				"Hold %s: talk on the radio" % _key(&"voice_radio")])
	if st.owns(me, &"brighter_lantern"):
		out.append(["Brighter lantern", "Your light reaches further"])
	if st.scrap_total() > 0:
		out.append(["Scrap x%d" % st.scrap_total(), "Hold %s on broken things: repair" % _key(&"interact")])
	return out


func _show_hotbar(slots: Array) -> void:
	while _hotbar.get_child_count() > slots.size():
		var gone := _hotbar.get_child(-1)
		_hotbar.remove_child(gone)
		gone.queue_free()
	while _hotbar.get_child_count() < slots.size():
		var box := PanelContainer.new()
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.55)
		bg.set_content_margin_all(6)
		box.add_theme_stylebox_override(&"panel", bg)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.add_theme_font_size_override(&"font_size", 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		_hotbar.add_child(box)
	for i in slots.size():
		(_hotbar.get_child(i).get_child(0) as Label).text = "%s\n%s" % slots[i]


func _verb_text(verb: StringName) -> String:
	if ":" in verb:  # `plant:<crop>` (P4-04): the chore, then the crop's name from crops.json
		var arg := String(verb).get_slice(":", 1)
		return "%s %s" % [_verb_text(StringName(String(verb).get_slice(":", 0))), Data.record(&"crops", StringName(arg)).get("name", arg)]
	return VERB_TEXT.get(verb, String(verb).capitalize().replace("_", " "))


func _key(action: StringName) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode if e.physical_keycode != 0 else e.keycode)
		if e is InputEventMouseButton:
			return "Mouse %d" % e.button_index
	return "?"


func _move_keys() -> String:
	return "%s%s%s%s" % [_key(&"move_forward"), _key(&"move_left"), _key(&"move_back"), _key(&"move_right")]
