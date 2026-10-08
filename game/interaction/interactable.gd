extends Node
## Doc 05 section 7: what an object offers. A child of the world node it describes (a plot marker, a
## prop body); `id` is the wire name for `request_hold`. Subclasses override the three virtuals.
## `st` is the host's per-player dictionary (`Game.players[peer]` plus `can` and `bag`); on a client
## `verbs_for` gets the local replicated view only (it picks the prompt, the host decides).

## Verbs that are not chores, so labor.json has no entry: taking and returning the shovel (P2-11).
const INSTANT_S := {&"take_shovel": 0.3, &"return_shovel": 0.3, &"take_trap": 1.0}  ## placeholders; take_trap about 1 s like hanging (doc 02 s2.1, P2-19)

var id := ""
var range_m := 2.0  ## doc 05 section 7 step 2 (placeholder)
var farm: Node  ## the Farm that owns this


## Hold seconds for a verb: labor.json, or INSTANT_S for the few verbs that are not chores.
static func hold_seconds(verb: StringName) -> float:
	return float(INSTANT_S[verb]) if INSTANT_S.has(verb) else Data.hold_s(verb)


func target_pos() -> Vector3:
	return (get_parent() as Node3D).global_position


func verbs_for(_st: Dictionary) -> Array[StringName]:
	return []


## Empty StringName for OK, else the refusal reason.
func can_start(_verb: StringName, _st: Dictionary) -> StringName:
	return &"no_such_verb"


## Host only: the hold has just been accepted (a noise at hold start, doc 05 section 8).
func on_start(_verb: StringName, _peer: int) -> void:
	pass


## Host only: apply the effect (the registry has already logged and will log `hold_completed`).
func complete(_verb: StringName, _peer: int, _st: Dictionary) -> void:
	pass


## Adds a layer-4 pick body so the HoldController ray can find this interactable.
func add_pick_body(size: Vector3 = Vector3(1.6, 1.0, 1.6)) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 8  # layer 4 "interactable"
	b.collision_mask = 0
	b.set_meta(&"interactable", self)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.position.y = size.y / 2.0
	b.add_child(c)
	get_parent().add_child(b)
