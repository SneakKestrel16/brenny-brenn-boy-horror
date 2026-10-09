extends RefCounted
## Doc 05 section 12: the shared light controller. The only caller of LightRig.set_on / set_dim
## (CONTRACTS section 10, doc 07 s4). Every rig follows the generator: off when dead, dimmed by fuel.
## A dying generator dims, smoothly, through LightRig's own slew limit.
## P4-12: a rig whose spot has meta `own_power` (the cart lantern) is not on the generator; `set_own` drives it.


static func apply(tree: SceneTree, powered: bool, fuel_fraction: float) -> void:
	for r in tree.get_nodes_in_group(&"light_rigs"):
		if r.get_parent().has_meta(&"own_power"):
			continue
		r.set_on(powered)
		r.set_dim(fuel_fraction)


## P4-12: a rig with its own power (the cart lantern burns oil, doc 07 s3) on or off.
static func set_own(rig: Node, on: bool) -> void:
	rig.set_on(on)
