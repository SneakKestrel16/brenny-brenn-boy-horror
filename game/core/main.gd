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
	var look := Node.new()  # Technical Artist P1-11: lighting, fog, corn visuals (game/render/)
	look.set_script(load("res://game/render/world_look.gd"))
	look.name = "Look"
	add_child(look)
	var gen := Node.new()  # P1-07: generator, fuel drum, building lights (after Farm and Look: it uses both)
	gen.set_script(load("res://game/core/generator.gd"))
	gen.name = "Generator"
	add_child(gen)
	var players := Node3D.new()
	players.set_script(load("res://game/player/players.gd"))
	players.name = "Players"
	add_child(players)
	var bots := Node.new()  # AI Programmer P1-13: `--bots <n>` teammates (game/bots/), after Players
	bots.set_script(load("res://game/bots/bots.gd"))
	bots.name = "Bots"
	add_child(bots)
	add_child(DebugView.new())  # P1-12: hidden unless --debug-view or F3 (host)
	Log.event(&"main_ready", {"players": Game.players.keys()})
