extends Node3D
## Doc 05 section 3: the running session. World is the level scene; Players is the per-peer Player
## nodes and the move stream (game/player/players.gd).

const FARM := "res://game/world/farm_phase1.tscn"


func _ready() -> void:
	var world := (load(FARM) as PackedScene).instantiate()
	world.name = "World"
	add_child(world)
	var farm := Node.new()
	farm.set_script(load("res://game/farming/farm.gd"))
	farm.name = "Farm"
	add_child(farm)  # before Players: the local Player's HoldController finds the Farm by group
	var players := Node3D.new()
	players.set_script(load("res://game/player/players.gd"))
	players.name = "Players"
	add_child(players)
	Log.event(&"main_ready", {"players": Game.players.keys()})
