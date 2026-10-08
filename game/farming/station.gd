extends "res://game/interaction/interactable.gd"
## Doc 05 section 9: the sell box (`sell`, doc 01 stand-in at (40, 20), D-016) and the well (`fill_can`).

var kind: StringName = &"sell"  ## `sell` or `well`


func verbs_for(_st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	out.append(&"sell" if kind == &"sell" else &"fill_can")
	return out


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if verb == &"sell" and kind == &"sell":
		return &"" if int(st.get("bag", 0)) > 0 else &"bag_empty"
	if verb == &"fill_can" and kind == &"well":
		if st.get("held_kind", &"") != &"water":
			return &"no_can"
		return &"" if int(st.get("can", 0)) < int(Data.value(&"labor", &"can", &"capacity")) else &"can_full"
	return &"no_such_verb"


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	if verb == &"sell":
		var n := int(st.bag)
		st.bag = 0
		farm.add_coins(n * int(Data.value(&"crops", &"turnip", &"sell")), &"sell", peer)
	else:
		st.can = int(Data.value(&"labor", &"can", &"capacity"))
		NoiseBus.emit_kind(&"well_pump", target_pos(), peer)
