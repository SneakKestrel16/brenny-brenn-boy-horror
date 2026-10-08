extends "res://game/interaction/interactable.gd"
## Doc 05 sections 7 and 11: a trap spot as a hold target. Every peer has one per spot that holds a set
## or sprung trap (made by `TrapRace`). Offers `pry` while a player is pinned in it, `disarm_bear` on a
## set bear trap (a disarmed trap goes into the hands, hung later on the pegboard), `fill_pit` on a set or
## sprung pit (needs the shovel). Noises: doc 05 section 8 and doc 03 section 3.1.

var race: Node  ## the TrapRace
var pick: Node  ## the layer-4 pick body, freed with the target


func _trap() -> Dictionary:
	return race.traps.get(id, {})


func verbs_for(_st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if race.victims.has(id):
		out.append(&"pry")
		return out
	var t := _trap()
	if t.is_empty():
		return out
	if t.kind == &"bear" and t.state == &"set":
		out.append(&"disarm_bear")
	elif t.kind == &"pit" and t.state in [&"set", &"sprung"]:
		out.append(&"fill_pit")
	return out


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if Game.is_host():
		race.sync_set()  # the host's table may be up to 0.5 s behind the Creature's
	var t := _trap()
	match verb:
		&"pry":
			return &"" if race.races.has(id) else &"not_pinned"
		&"disarm_bear":
			if t.is_empty() or t.kind != &"bear" or t.state != &"set":
				return &"not_armed"
			return &"hands_full" if st.get("trap", false) else &""
		&"fill_pit":
			if t.is_empty() or t.kind != &"pit" or not t.state in [&"set", &"sprung"]:
				return &"not_armed"
			return &"" if st.get("shovel", false) else &"need_shovel"
	return &"no_such_verb"


func on_start(verb: StringName, peer: int) -> void:
	if verb == &"fill_pit":  # doc 05 section 8: tool_shovel at the start and again at the end
		NoiseBus.emit_kind(&"tool_shovel", target_pos(), peer)


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	match verb:
		&"pry": race.on_pry_done(id, peer)
		&"disarm_bear":
			NoiseBus.emit_kind(&"tool_disarm", target_pos(), peer)
			race.clear_trap(id, &"disarmed", peer)
			farm.set_hands(peer, bool(st.get("shovel", false)), true)
		&"fill_pit":
			NoiseBus.emit_kind(&"tool_shovel", target_pos(), peer)
			race.clear_trap(id, &"filled", peer)
