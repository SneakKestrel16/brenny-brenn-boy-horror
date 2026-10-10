extends RefCounted
## P5-57: the full farm's walk grid for bot teammates. A bot moves by position (no physics), so before this it
## walked straight through walls, fences and props. One AStarGrid2D over the farm's bounds walls (farm.tscn
## `Bounds`), built once on the host from the physics world: a cell is solid where a player-sized box hits a
## static body on layer 1 (walls, fences, props: what stops a player, player.gd), except the door blockers and
## leaves, so a path goes through a doorway and the bot opens a closed door there (bot.gd `_door_stops`). Corn
## and trees (layer 16, walkable) cost `corn_weight` per cell, so a bot keeps to open ground where it can: the
## creature lurks in the corn (doc 03 section 6, P5-56). Numbers: ai_director.json `bots`.

const SOLID_MASK := 1
const CORN_MASK := 16

var astar := AStarGrid2D.new()
var _rect: Rect2  ## x, z
var _cell := 1.0


## `rect` in metres (x, z); `exclude` the bodies never counted solid (door blockers and leaves).
func build(space: PhysicsDirectSpaceState3D, rect: Rect2, cell_m: float, body_m: float, corn_weight: float, exclude: Array[RID]) -> void:
	_rect = rect
	_cell = cell_m
	astar.region = Rect2i(0, 0, ceili(rect.size.x / cell_m), ceili(rect.size.y / cell_m))
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var box := BoxShape3D.new()
	box.size = Vector3(body_m, 1.2, body_m)  # y 0.3 to 1.5: clears the floor (top at y 0), hits walls and fences
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = SOLID_MASK | CORN_MASK
	q.exclude = exclude
	for i in astar.region.size.x:
		for j in astar.region.size.y:
			var c := Vector2i(i, j)
			q.transform = Transform3D(Basis.IDENTITY, _world(c) + Vector3(0, 0.9, 0))
			var corn := false
			for hit: Dictionary in space.intersect_shape(q, 8):
				var body := hit.collider as CollisionObject3D
				if not body is StaticBody3D:
					continue  # players, the creature, the cart: they move
				if body.collision_layer & SOLID_MASK:
					astar.set_point_solid(c)
					break
				corn = true
			if corn and not astar.is_point_solid(c):
				astar.set_point_weight_scale(c, corn_weight)


## Points from `from` to `to` (metres, y 0): turns only, ending on `to` itself. A blocked end walks to the nearest
## open cell first; no way through gives the partial path, then the straight line (the old behaviour).
func path(from: Vector3, to: Vector3) -> Array:
	var a := _open_near(_cell_of(from))
	var b := _open_near(_cell_of(to))
	var out: Array = []
	if a.x >= 0 and b.x >= 0:
		var ids := astar.get_id_path(a, b, true)
		for k in ids.size():
			var turn := k == ids.size() - 1 or k == 0 or ids[k] - ids[k - 1] != ids[k + 1] - ids[k]
			if turn and k > 0:  # cell 0 is where the bot stands
				out.append(_world(ids[k]))
	out.append(Vector3(to.x, 0.0, to.z))
	return out


func solid_at(p: Vector3) -> bool:
	var c := _cell_of(p)
	return astar.is_in_boundsv(c) and astar.is_point_solid(c)


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - _rect.position.x) / _cell), floori((p.z - _rect.position.y) / _cell))


func _world(c: Vector2i) -> Vector3:
	return Vector3(_rect.position.x + (c.x + 0.5) * _cell, 0.0, _rect.position.y + (c.y + 0.5) * _cell)


## The nearest open in-bounds cell to `c` within 4 rings, else (-1, -1).
func _open_near(c: Vector2i) -> Vector2i:
	c = c.clamp(astar.region.position, astar.region.end - Vector2i.ONE)
	for r in 5:
		var best := Vector2i(-1, -1)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and astar.is_in_boundsv(n) and not astar.is_point_solid(n) \
						and (best.x < 0 or (n - c).length_squared() < (best - c).length_squared()):
					best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)
