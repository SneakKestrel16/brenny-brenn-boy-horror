extends "res://game/interaction/interactable.gd"
## Doc 05 sections 9 and 11 (P2-11): the shed pegboard as a hold target. With a disarmed bear trap in
## hand it offers `hang_trap`; otherwise it hands out or takes back the shovel (instant, no labor.json
## entry: Interactable.INSTANT_S).

var sweep: Node  ## the TrapSweep


func verbs_for(st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if st.get("trap", false):
		out.append(&"hang_trap")
	else:
		out.append(&"return_shovel" if st.get("shovel", false) else &"take_shovel")
	return out


func can_start(verb: StringName, st: Dictionary) -> StringName:
	match verb:
		&"hang_trap":
			if not st.get("trap", false):
				return &"no_trap"
			return &"" if sweep.filled.has(false) else &"pegboard_full"
		&"take_shovel": return &"" if not st.get("shovel", false) else &"has_shovel"
		&"return_shovel": return &"" if st.get("shovel", false) else &"no_shovel"
	return &"no_such_verb"


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	match verb:
		&"hang_trap": sweep.hang(peer)
		&"take_shovel": sweep.farm.set_hands(peer, true, bool(st.get("trap", false)))
		&"return_shovel": sweep.farm.set_hands(peer, false, bool(st.get("trap", false)))
