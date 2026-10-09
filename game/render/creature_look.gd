class_name CreatureLook
extends RefCounted
## Doc 07 s7, s8: shared materials for the creature bodies and the lantern glass, applied by material
## name so a P4-19 rebuild of the glb needs no change here (the names `mat_flat_lit`, `mat_emissive_ember`,
## `mat_emissive_warm` are the contract). Nothing here animates: no TIME, no energy change (s4.3).
## Hook-up (Gameplay owns creature.gd): after instancing a body glb, `CreatureLook.apply(body)`; for a
## ghost's own view only, `CreatureLook.ghost_view(body, Game.is_ghost(local_peer))`.

const MATS := "res://assets/materials/%s.tres"
const GHOST_RIM := preload("res://assets/materials/mat_ghost_rim.tres")


## Swaps every surface whose material is named `mat_*` for the shared resource of the same name.
static func apply(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name.begins_with("mat_") and ResourceLoader.exists(MATS % m.resource_name):
				(mi as MeshInstance3D).set_surface_override_material(i, load(MATS % m.resource_name))


## Doc 07 s8 / doc 01 "Ghosts": the rim shows on a ghost's own screen only. Call it from the local
## client; the hull and the body keep their meshes, so only a cold edge is added.
static func ghost_view(root: Node, on: bool) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = GHOST_RIM if on else null


## Lantern glass (P4-16 nit): lit = warm emissive, unlit = dull amber with no emission. The caller
## (the lantern's owner) passes whether the lantern is on; this does not read or change any light.
static func lantern_glass(root: Node, lit: bool) -> void:
	var mat: Material = load(MATS % ("mat_emissive_warm" if lit else "mat_glass_unlit"))
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name == "mat_emissive_warm":
				(mi as MeshInstance3D).set_surface_override_material(i, mat)
