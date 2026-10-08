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
	var creature := CharacterBody3D.new()  # AI Programmer P1-08: the Phase 1 creature (game/creature/)
	creature.set_script(load("res://game/creature/creature.gd"))
	creature.name = "Creature"
	add_child(creature)
	var death := Node.new()  # P1-09: death, ghosts, respawn (game/ghost/); before TrapRace, which kills through it
	death.set_script(load("res://game/ghost/death.gd"))
	death.name = "Death"
	add_child(death)
	var traps := Node.new()  # P1-09: trap race, player side (game/traps_player/)
	traps.set_script(load("res://game/traps_player/trap_race.gd"))
	traps.name = "TrapRace"
	add_child(traps)
	add_child(PauseMenu.new())  # P2-10
	add_child(DebugView.new())  # P1-12: hidden unless --debug-view or F3 (host)
	if DevConsole.enabled():  # D-031: ` opens it in debug runs or with --dev
		add_child(DevConsole.new())
	Log.event(&"main_ready", {"players": Game.players.keys()})
