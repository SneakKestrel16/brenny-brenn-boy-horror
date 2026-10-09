extends Node3D
## Doc 05 section 3: the running session. World is the level scene; Players is the per-peer Player
## nodes and the move stream (game/player/players.gd).

func _ready() -> void:
	var world := (load(Game.world_path()) as PackedScene).instantiate()
	world.name = "World"
	add_child(world)
	var farm := Node.new()
	farm.set_script(load("res://game/farming/farm.gd"))
	farm.name = "Farm"
	add_child(farm)  # before Players: the local Player's HoldController finds the Farm by group
	var animals := Node3D.new()  # P4-08: the pen animals and the breakable fence (game/farming/), after Farm
	animals.set_script(load("res://game/farming/animals.gd"))
	animals.name = "Animals"
	add_child(animals)
	var look := Node.new()  # Technical Artist P1-11: lighting, fog, corn visuals (game/render/)
	look.set_script(load("res://game/render/world_look.gd"))
	look.name = "Look"
	add_child(look)
	var gen := Node.new()  # P1-07: generator, fuel drum, building lights (after Farm and Look: it uses both)
	gen.set_script(load("res://game/core/generator.gd"))
	gen.name = "Generator"
	add_child(gen)
	var taint := Node.new()  # P3-07: who is Tainted, and the Taint sources on the ground
	taint.set_script(load("res://game/player/taint.gd"))
	taint.name = "Taint"
	add_child(taint)
	var players := Node3D.new()
	players.set_script(load("res://game/player/players.gd"))
	players.name = "Players"
	add_child(players)
	var bots := Node.new()  # AI Programmer P1-13: `--bots <n>` teammates (game/bots/), after Players
	bots.set_script(load("res://game/bots/bots.gd"))
	bots.name = "Bots"
	add_child(bots)
	var director := Node.new()  # AI Programmer P3-04: the AI Director (game/ai_director/); before the Creature, which asks it in _ready
	director.set_script(load("res://game/ai_director/ai_director.gd"))
	director.name = "AiDirector"
	add_child(director)
	var creature := CharacterBody3D.new()  # AI Programmer P1-08: the Phase 1 creature (game/creature/)
	creature.set_script(load("res://game/creature/creature.gd"))
	creature.name = "Creature"
	add_child(creature)
	var scares := Node.new()  # AI Programmer P3-05: the scares (game/ai_director/); after the Creature, whose rules it reads
	scares.set_script(load("res://game/ai_director/scares.gd"))
	scares.name = "Scares"
	add_child(scares)
	var death := Node.new()  # P1-09: death, ghosts, respawn (game/ghost/); before TrapRace, which kills through it
	death.set_script(load("res://game/ghost/death.gd"))
	death.name = "Death"
	add_child(death)
	var traps := Node.new()  # P1-09: trap race, player side (game/traps_player/)
	traps.set_script(load("res://game/traps_player/trap_race.gd"))
	traps.name = "TrapRace"
	add_child(traps)
	var sweep := Node.new()  # P2-11: flags and the shed pegboard (game/traps_player/); after Farm
	sweep.set_script(load("res://game/traps_player/trap_sweep.gd"))
	sweep.name = "TrapSweep"
	add_child(sweep)
	var whistle := Node.new()  # P3-11: whistle and emotes (game/player/), after Players, whose bodies it animates
	whistle.set_script(load("res://game/player/whistle_emotes.gd"))
	whistle.name = "WhistleEmotes"
	add_child(whistle)
	add_child(DawnReport.new())  # P3-12: before Death logs its first dawn
	add_child(PauseMenu.new())  # P2-10
	add_child(DebugView.new())  # P1-12: hidden unless --debug-view or F3 (host)
	if DevConsole.enabled():  # D-031: ` opens it in debug runs or with --dev
		add_child(DevConsole.new())
	Log.event(&"main_ready", {"players": Game.players.keys()})
