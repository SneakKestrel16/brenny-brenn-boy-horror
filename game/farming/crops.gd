extends RefCounted

const Debt := preload("res://game/farming/debt.gd")
## P4-04 (doc 05 s9): crop facts read from crops.json. No crop name lives in code; a crop is found by what it
## does (`harvest_phase`), so a new record in the table plants, grows and sells with no edit here.

## P4-07: the first payment was made (Debt records it at dawn 4; every peer mirrors it). Pumpkins stay locked
## for the season after a missed one (doc 02 s5, D-017).
static func first_paid(_day: int = 0) -> bool:
	return Debt.first_made


static func rec(id: StringName) -> Dictionary:
	return Data.record(&"crops", id)


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in Data.records(&"crops"):
		out.append(StringName(r.id))
	return out


static func is_unlocked(id: StringName, day: int) -> bool:
	var r := rec(id)
	if r.is_empty() or day < int(r.unlock_day):
		return false
	return String(r.unlock_rule) != "first_payment_made" or first_paid(day)


## The crop that is picked at night and wilts at dawn (doc 01 Crops: the moonflower), empty if none.
static func night_crop() -> StringName:
	for r in Data.records(&"crops"):
		if String(r.harvest_phase) == "night":
			return StringName(r.id)
	return &""


## Day crops a field plot may plant today, cheapest unlock first (data order). Never empty once turnips exist.
static func seeds(day: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for r in Data.records(&"crops"):
		if String(r.harvest_phase) == "day" and is_unlocked(StringName(r.id), day):
			out.append(StringName(r.id))
	return out


## The crop a plain `plant` verb plants: the first day crop, the one that is unlocked from day 1.
static func default_seed() -> StringName:
	for r in Data.records(&"crops"):
		if String(r.harvest_phase) == "day":
			return StringName(r.id)
	return &""


static func sell(id: StringName) -> int:
	return int(rec(id).get("sell", 0))


## `bag_by` {crop: n} to coins.
static func value_of(bag_by: Dictionary) -> int:
	var v := 0
	for c in bag_by:
		v += int(bag_by[c]) * sell(StringName(c))
	return v


## Host: what a player's bag sells for. `st.bag` is the count the clients see; `st.bag_by` says which crops.
## Items counted in `bag` but not in `bag_by` (a test or bot setting `bag` directly) sell as the default crop.
static func bag_value(st: Dictionary) -> int:
	var by: Dictionary = st.get("bag_by", {})
	var n := 0
	for c in by:
		n += int(by[c])
	return value_of(by) + maxi(int(st.get("bag", 0)) - n, 0) * sell(default_seed())


static func bag_add(st: Dictionary, crop: StringName) -> void:
	var by: Dictionary = st.get("bag_by", {})
	by[crop] = int(by.get(crop, 0)) + 1
	st.bag_by = by
	st.bag = int(st.get("bag", 0)) + 1


static func bag_clear(st: Dictionary) -> void:
	st.bag = 0
	st.bag_by = {}
