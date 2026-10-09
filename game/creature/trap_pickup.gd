extends "res://game/interaction/interactable.gd"
## Doc 03 section 9, D-053 (3) (P2-05): an unarmed bear trap lying in the corn at a `trap_spot`, where a
## trap kept in a building lit all night turns up at dawn. Every peer has one per loose trap (the
## Creature makes it on `trap_changed` `loose`). Picked up with the instant `take_trap` verb (P2-19, was the `disarm_bear` borrow, Q-056);
## it goes into the hands like a disarmed trap. P4-29 (CEO): a pried-free bear trap lies at its spot as one too,
## jaws shut, until a player takes it and hangs it on the pegboard (or the creature takes it at nightfall, D-104).

var creature: Node  ## the Creature (host: `pick_up_loose`)


func verbs_for(_st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = [&"take_trap"]
	return out


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if verb != &"take_trap":
		return &"no_such_verb"
	return &"hands_full" if st.get("trap", false) else &""


func complete(_verb: StringName, peer: int, st: Dictionary) -> void:
	creature.pick_up_loose(id, peer, st)
