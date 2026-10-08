extends Node
## Doc 05 section 14 (P3-11): the whistle and the emotes. Host: validates `request_whistle` (cooldown)
## and `request_emote` (1 per second), stamps the position from its own `Game.players` state, emits the
## Noise, logs `whistle` / `emote` and broadcasts `apply_whistle` / `apply_emote`. Every peer: plays the
## sound at that position and the emote on the sender's body. Local: `whistle` (Q) sends a request,
## `emote_wheel` (hold Z) opens the wheel. No marker anywhere: the whistle is placed by ear (doc 01).

const EmoteWheel := preload("res://game/ui/emote_wheel.gd")

const EMOTES: Array[StringName] = [&"wave", &"point", &"shrug", &"scream"]  ## doc 01 "Emotes and physical comedy"
const WHISTLE_COOLDOWN_S := 5.0  ## doc 01 "Whistle": "short cooldown"; the number is a placeholder (doc 05 s14)
const EMOTE_GAP_S := 1.0  ## doc 05 s14: host rate limit, 1 per 1 s (placeholder)
const SCREAM_BYTE := 255  ## doc 03 s3.1 emote `scream` row: `voice` at byte 255, 60 m (inference there)

var _last_whistle := {}  ## host: peer -> msec of the last accepted whistle
var _last_emote := {}  ## host: peer -> msec of the last accepted emote
var _wheel: Control


func _ready() -> void:
	Net.apply_received.connect(_on_apply)
	if Game.is_host():
		Net.request_received.connect(_on_request)
	if DisplayServer.get_name() != "headless":
		var layer := CanvasLayer.new()
		_wheel = EmoteWheel.new()
		_wheel.picked.connect(func(e: StringName) -> void: Net.to_host(&"request_emote", [e]))
		layer.add_child(_wheel)
		add_child(layer)
	if OS.get_cmdline_user_args().has("--autowhistle"):
		_autowhistle()


## QA (`-- --autowhistle`, multi-instance tests): this peer sends the same requests the keys send, so a
## client exercises the real request path. Twice fast each time, so the host's cooldown and rate limit answer too.
func _autowhistle() -> void:
	for i in 6:
		await get_tree().create_timer(3.0).timeout
		if not is_inside_tree():
			return
		Net.to_host(&"request_whistle")
		Net.to_host(&"request_whistle")
		Net.to_host(&"request_emote", [EMOTES[i % EMOTES.size()]])
		Net.to_host(&"request_emote", [EMOTES[i % EMOTES.size()]])


func _unhandled_input(event: InputEvent) -> void:
	if Game.console_open or Game.is_ghost(Game.local_peer()):
		return  # a ghost's Q is `spectate_prev` (shared key, settings_apply.gd)
	if event.is_action_pressed(&"whistle") and not event.is_echo():
		Net.to_host(&"request_whistle")
	elif event.is_action_pressed(&"emote_wheel") and not event.is_echo() and _wheel:
		_wheel.open()


# --- host ----------------------------------------------------------------------------------------

func _on_request(what: StringName, peer: int, args: Array) -> void:
	if what == &"whistle":
		whistle(peer)
	elif what == &"emote":
		emote(peer, StringName(args[0]))


## Host: `peer` asks to whistle. Returns the refusal reason, "" when it whistled (the dev console prints it).
func whistle(peer: int) -> StringName:
	var reason := _refusal(peer, _last_whistle, WHISTLE_COOLDOWN_S, &"cooldown")
	if reason != &"":
		return _refuse(peer, &"whistle", reason)
	_last_whistle[peer] = Time.get_ticks_msec()
	var pos: Vector3 = Game.players[peer].pos
	NoiseBus.emit_kind(&"whistle", pos, peer)  # doc 03 s3.1: 50 m
	Log.event(&"whistle", {"player": peer, "position": [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)], "cooldown_s": WHISTLE_COOLDOWN_S})
	Net.to_peers(&"apply_whistle", [peer, pos])
	Net.apply_received.emit(&"whistle", [peer, pos])  # the host is its own client
	return &""


## Host: `peer` asks for emote `kind`. Same return as `whistle`.
func emote(peer: int, kind: StringName) -> StringName:
	var reason := &"unknown_emote" if not kind in EMOTES else _refusal(peer, _last_emote, EMOTE_GAP_S, &"rate_limit")
	if reason != &"":
		return _refuse(peer, &"emote", reason)
	_last_emote[peer] = Time.get_ticks_msec()
	var pos: Vector3 = Game.players[peer].pos
	if kind == &"scream":
		NoiseBus.emit_voice(pos, SCREAM_BYTE, peer)
	Log.event(&"emote", {"player": peer, "emote": String(kind), "position": [snappedf(pos.x, 0.1), snappedf(pos.z, 0.1)]})
	Net.to_peers(&"apply_emote", [peer, kind, pos])
	Net.apply_received.emit(&"emote", [peer, kind, pos])
	return &""


func _refusal(peer: int, last: Dictionary, gap_s: float, why: StringName) -> StringName:
	if not Game.players.has(peer) or not Game.players[peer].has("pos"):
		return &"no_player"
	if Game.is_ghost(peer):
		return &"ghost"  # ghosts cannot touch the world (doc 05 s14); their powers are lights and crows
	if last.has(peer) and Time.get_ticks_msec() - int(last[peer]) < int(gap_s * 1000.0):
		return why
	return &""


func _refuse(peer: int, verb: StringName, reason: StringName) -> StringName:
	Log.event(&"hold_refused", {"player": peer, "verb": String(verb), "target": "", "reason": String(reason)})
	if peer > 1:  # the host and bots have no connection to answer on
		Net.to_peers(&"apply_refused", [verb, reason], [peer])
	return reason


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	if what == &"whistle":
		Soundscape.play_3d(&"sfx_whistle", args[1])
	elif what == &"emote":
		if args[1] == &"scream":
			Soundscape.play_3d(&"vox_emote_scream", args[2])
		var pl: Node = get_parent().get_node("Players").player(args[0])
		if pl:
			pl.play_emote(args[1])
