extends "res://game/interaction/interactable.gd"
## Doc 05 section 9: the sell box (`sell`, doc 01 stand-in at (40, 20), D-016) and the well (`fill_can`, and
## `wash` for a Tainted player, P3-07: doc 01 "The Taint", about 10 s of noisy pumping clears it).

const Crops := preload("res://game/farming/crops.gd")

var kind: StringName = &"sell"  ## `sell` or `well`


func verbs_for(st: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if kind == &"well" and bool(Game.players.get(Game.local_peer(), {}).get("tainted", false)):
		out.append(&"wash")  # the carry view has no Taint flag: read this machine's mirror of it
	if kind == &"sell" and st.has("bag") and int(st.bag) == 0:
		out.append(&"pay_early")  # P4-07: doc 01 "Early payment: allowed at any dawn"; empty-handed at the box pays the bank
	else:
		out.append(&"sell" if kind == &"sell" else &"fill_can")
	return out


func can_start(verb: StringName, st: Dictionary) -> StringName:
	if verb == &"pay_early" and kind == &"sell":
		var d: Node = farm.get_tree().get_first_node_in_group(&"debt")
		return d.early_blocked() if d else &"no_such_verb"
	if verb == &"sell" and kind == &"sell":
		return &"" if int(st.get("bag", 0)) > 0 else &"bag_empty"
	if verb == &"fill_can" and kind == &"well":
		if st.get("held_kind", &"") != &"water":
			return &"no_can"
		return &"" if int(st.get("can", 0)) < int(Data.value(&"labor", &"can", &"capacity")) else &"can_full"
	if verb == &"wash" and kind == &"well":
		return &"" if bool(st.get("tainted", false)) else &"not_tainted"
	return &"no_such_verb"


## Washing is noisy from the first stroke (doc 01 "The Taint": "That can draw the creature").
func on_start(verb: StringName, peer: int) -> void:
	if verb == &"wash":
		NoiseBus.emit_kind(&"well_pump", target_pos(), peer)


func complete(verb: StringName, peer: int, st: Dictionary) -> void:
	if verb == &"pay_early":
		farm.get_tree().get_first_node_in_group(&"debt").pay_early(peer)
		return
	if verb == &"sell":
		var n := int(st.bag)
		var v := Crops.bag_value(st)
		Crops.bag_clear(st)
		Log.event(&"sell", {"player": peer, "items": n, "coins": v})
		farm.add_coins(v, &"sell", peer)
	elif verb == &"wash":
		NoiseBus.emit_kind(&"well_pump", target_pos(), peer)
		farm.get_tree().get_first_node_in_group(&"taint").set_taint(peer, false, &"well")
	else:
		st.can = int(Data.value(&"labor", &"can", &"capacity"))
		NoiseBus.emit_kind(&"well_pump", target_pos(), peer)
