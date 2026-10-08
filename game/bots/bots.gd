extends Node
## Doc 05 section 3 `--bots <n>`: adds n bot teammates on the host (game/bots/bot.gd). A bot is a
## roster entry with a negative peer id (ENet ids are positive, so they never clash), so every peer
## spawns it as a remote player and sees it through the host's `moves` stream. Main adds this node
## after Players. Clients get bots only through the roster; they run no bot code.

const Bot := preload("res://game/bots/bot.gd")

var claims: Dictionary = {}  ## target id -> bot peer, shared so bots split the plots


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
