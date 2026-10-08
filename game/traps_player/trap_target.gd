extends "res://game/interaction/interactable.gd"
## Doc 05 section 7: a sprung bear trap as a hold target. Every peer has one per sprung trap (made by
## `TrapRace`). It offers `pry` only while a player is pinned in it.

var race: Node  ## the TrapRace


func verbs_for(_st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if race.victims.has(id):
		out.append(&"pry")
	return out


func can_start(verb: StringName, _st: Dictionary) -> StringName:
	if verb != &"pry":
		return &"no_such_verb"
	return &"" if race.races.has(id) else &"not_pinned"


func complete(_verb: StringName, peer: int, _st: Dictionary) -> void:
	race.on_pry_done(id, peer)
