extends Node
## Doc 05 section 3 `--bots <n>`: adds n bot teammates on the host (game/bots/bot.gd). A bot is a
## roster entry with a negative peer id (ENet ids are positive, so they never clash), so every peer
## spawns it as a remote player and sees it through the host's `moves` stream. Main adds this node
## after Players. Clients get bots only through the roster; they run no bot code.

const Bot := preload("res://game/bots/bot.gd")
const BotGrid := preload("res://game/bots/bot_grid.gd")

var claims: Dictionary = {}  ## target id -> bot peer, shared so bots split the plots
var _grid: RefCounted  ## P5-57: BotGrid, built on first use (the world's bodies are in the physics space by then)


func _ready() -> void:
	if not Game.is_host() or Game.bots <= 0:
		return
	var players: Node = get_parent().get_node("Players")
	var farm: Node = get_tree().get_first_node_in_group(&"farm")
	# P2-07, D-038: `--bots=N` fills empty slots up to the base count (4), never past it.
	for i in mini(Game.bots, maxi(Game.BASE_PLAYERS - Game.players.size(), 0)):
		var id := -(i + 1)
		Game.players[id] = {"bot": true}
		Log.event(&"player_joined", {"player": id, "bot": true})
		Game.player_joined.emit(id)  # Players spawns the body, Voice its emitter
		var b := Bot.new()
		b.name = "Bot%d" % (i + 1)
		b.peer = id
		b.players = players
		b.farm = farm
		b.claims = claims
		b.bots = self
		b.rng.seed = hash([Game.seed_value, id])  # `--seed` makes bot choices repeatable
		add_child(b)
	Net.to_peers(&"apply_roster", [Game.players.keys(), Net.profiles])  # a no-op until a client joins; joins resend it
	Game.player_joined.connect(_on_player_joined)


## D-038 (3): a bot never pushes a match past the base count. A human joining a full table drops one bot.
func _on_player_joined(id: int) -> void:
	if id < 0:
		return
	while Game.players.size() > Game.BASE_PLAYERS:
		var bot := 0
		for p in Game.players:
			if p < bot:
				bot = p  # the most recently added bot goes first
		if bot == 0:
			return
		Game.players.erase(bot)
		var node := get_node_or_null("Bot%d" % -bot)
		if node:
			node.queue_free()
		Net.to_peers(&"apply_roster", [Game.players.keys(), Net.profiles])
		Log.event(&"player_left", {"player": bot, "bot": true, "reason": "human_joined"})
		Game.player_left.emit(bot)


## P5-57: the full farm's walk grid, shared by every bot; null when `grid_route` is off or the farm has no bounds walls.
func grid() -> RefCounted:
	if _grid == null and Game.full_farm and Bot.knob(&"grid_route"):
		var bounds := get_tree().root.find_child("Bounds", true, false)
		if bounds == null or bounds.get_child_count() == 0:
			return null
		var first := (bounds.get_child(0) as Node3D).global_position
		var rect := Rect2(first.x, first.z, 0.0, 0.0)
		for w: Node3D in bounds.get_children():
			rect = rect.expand(Vector2(w.global_position.x, w.global_position.z))
		var skip: Array[RID] = []
		var doors := get_tree().root.get_node_or_null(^"Main/Doors") as Doors
		if doors:
			for id: String in doors.open:
				skip.append_array(doors.own_bodies(id))  # a doorway is walkable: the bot opens a closed door (bot.gd)
		var r: Dictionary = Data.record(&"ai_director", &"bots")
		_grid = BotGrid.new()
		var t0 := Time.get_ticks_msec()
		_grid.build(get_viewport().world_3d.direct_space_state, rect.grow(-1.0), float(r.cell_m), float(r.body_m), float(r.corn_weight), skip)
		Log.event(&"bot_grid", {"cells": _grid.astar.region.get_area(), "ms": Time.get_ticks_msec() - t0})
	return _grid
