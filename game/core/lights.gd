extends RefCounted
## Doc 05 section 12: the shared light controller. The only caller of LightRig.set_on / set_dim
## (CONTRACTS section 10, doc 07 s4). Every rig follows the generator: off when dead, dimmed by fuel.
## A dying generator dims, smoothly, through LightRig's own slew limit.


static func apply(tree: SceneTree, powered: bool, fuel_fraction: float) -> void:
	for r in tree.get_nodes_in_group(&"light_rigs"):
		r.set_on(powered)
		r.set_dim(fuel_fraction)
