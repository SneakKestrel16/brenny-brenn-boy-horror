extends SceneTree
## Doc 04 section 8 checks, run on the built scene:
##   "$GODOT" --headless --path . --script res://game/world/check_farm.gd
## Prints marker group counts and distances, and FAIL lines for anything off doc 04. Exit code 1 on a FAIL.

var _fails := 0
var _world: Node
var _corn: Array[Rect2] = []


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_world = (load("res://game/world/farm.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	for b in _world.get_node("CornBlockers").get_children():
		var s: Vector3 = (b.get_node("Mesh") as MeshInstance3D).mesh.size
		_corn.append(Rect2(b.position.x - s.x / 2, b.position.z - s.z / 2, s.x, s.z))
	_counts()
	_distances()
	_pumpkin()
	_lure_and_ghost()
	_route()
	print("check_farm: %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	quit(1 if _fails else 0)


func _p(path: String) -> Vector2:
	var n := _world.get_node(path) as Node3D
	return Vector2(n.global_position.x, n.global_position.z)


func _expect(label: String, got: float, want: float, tol := 0.1) -> void:
	var ok := absf(got - want) <= tol
	if not ok:
		_fails += 1
	print("%s %-34s got %7.2f  doc %7.2f" % ["ok  " if ok else "FAIL", label, got, want])


func _group(g: StringName) -> Array:
	return get_nodes_in_group(g).filter(func(n): return _world.is_ancestor_of(n))


func _counts() -> void:
	var want := {&"trap_spots": 22, &"creature_cover": 16, &"crow_perches": 9, &"scarecrow_spots": 7,
			&"animal_escape_spots": 4, &"spatial_audio_markers": 4, &"player_spawns": 6, &"plot_spots": 36,
			&"pegboard_spots": 1, &"pegboard_slots": 5, &"recording_spots": 1, &"barn_lantern": 1, &"doors": 3,
			&"lightrig_spots": 4, &"generator": 1, &"fuel_drum": 1, &"well": 1, &"sell_box": 1, &"store_crate": 1,
			&"pen_gates": 1, &"farm_gate": 1, &"sanctuary": 1, &"pumpkin_patch": 1, &"moonflower_bed": 1}
	for g in want:
		var n := _group(g).size()
		if n != want[g]:
			_fails += 1
		print("%s group %-22s %3d  doc %3d" % ["ok  " if n == want[g] else "FAIL", g, n, want[g]])
	var kinds := {}
	for t in _group(&"trap_spots"):
		kinds[t.get_meta(&"kind")] = kinds.get(t.get_meta(&"kind"), 0) + 1
	print("trap kinds: %s (doc 04 s7.1 table: edge 9, row 9, deep 4)" % kinds)
	if kinds != {"edge": 9, "row": 9, "deep": 4}:
		_fails += 1
	var start := _group(&"plot_spots").filter(func(p): return not p.get_meta(&"upgrade")).size()
	var field_start := _group(&"plot_spots").filter(func(p): return not p.get_meta(&"upgrade") and not p.get_meta(&"extra", false) and p.get_meta(&"field") != "moonflower").size()
	print("plots: start %d (fields %d, doc 01 16 at start), 24 field + 8 headcount extras + 4 moonflower" % [start, field_start])
	if field_start != 16:
		_fails += 1


func _centre(field: String) -> Vector2:
	var s := Vector2.ZERO
	var n := 0
	for p in _group(&"plot_spots"):
		if p.get_meta(&"field") == field and not p.get_meta(&"extra", false):  # doc centres are the 12-plot grid
			s += Vector2(p.global_position.x, p.global_position.z)
			n += 1
	return s / n


func _distances() -> void:
	var barn := _p("Buildings/Barn")
	var house := _p("Buildings/Farmhouse")
	var shed := _p("Buildings/ToolShed")
	var gen := _p("Props/Generator")
	var drum := _p("Props/FuelDrum")
	var well := _p("Props/Well")
	var a := _centre("a")
	var b := _centre("b")
	var moon := _centre("moonflower")
	var crate := _p("Props/ShippingCrate")
	var stand := _p("Props/TownStand")
	var gate := _p("Props/FarmGate")
	var pump := _p("Props/PrizePumpkin")
	print("-- doc 04 s8.1")
	_expect("barn-farmhouse", barn.distance_to(house), 45.0)
	_expect("barn-generator", barn.distance_to(gen), 12.5)
	_expect("barn-shed", barn.distance_to(shed), 30.0)
	_expect("farmhouse-shed", house.distance_to(shed), 39.7)
	_expect("generator-drum", gen.distance_to(drum), 33.0)
	_expect("barn-well", barn.distance_to(well), 26.9)
	_expect("well-shed", well.distance_to(shed), 18.9)
	_expect("well-farmhouse", well.distance_to(house), 22.4)
	_expect("barn-fieldA", barn.distance_to(a), 30.5)
	_expect("fieldA-fieldB", a.distance_to(b), 42.0)
	_expect("barn-fieldB (far field)", barn.distance_to(b), 72.2)
	_expect("fieldB-crate", b.distance_to(crate), 10.5)
	_expect("fieldB-moonflower", b.distance_to(moon), 30.0)
	_expect("fieldA-moonflower", a.distance_to(moon), 40.7)
	_expect("barn-moonflower", barn.distance_to(moon), 63.9)
	_expect("farmhouse-pumpkin", house.distance_to(pump), 33.1)
	_expect("shed-pumpkin", shed.distance_to(pump), 32.8)
	_expect("barn-pumpkin", barn.distance_to(pump), 57.4)
	_expect("well-pumpkin", well.distance_to(pump), 31.8)
	_expect("fieldB-townstand", b.distance_to(stand), 48.0)
	_expect("gate-townstand", gate.distance_to(stand), 15.0)
	_expect("barn-townstand", barn.distance_to(stand), 120.1)
	_expect("pumpkin-townstand (longest)", pump.distance_to(stand), 171.3)
	for e in _group(&"animal_escape_spots"):
		var d := Vector2(e.global_position.x, e.global_position.z).distance_to(_p("Pen/PenGate"))
		print("%s %s to pen gate %.1f (doc 04 s7.3: 60 m or more)" % ["ok  " if d >= 60 else "FAIL", e.name, d])
		if d < 60:
			_fails += 1


func _pumpkin() -> void:
	print("-- doc 04 s5.3 / s8.5 pumpkin")
	var pump := _p("Props/PrizePumpkin")
	for d in _group(&"doors"):
		var dd := pump.distance_to(Vector2(d.global_position.x, d.global_position.z))
		print("%s door %-10s %.1f m (30 m rule)" % ["ok  " if dd >= 30 else "FAIL", d.get_parent().name, dd])
		if dd < 30:
			_fails += 1
	var strip1 := _corn_rect("Strip1")
	print("strip 1 tip (z %.0f) is %.1f m from the pumpkin; farmhouse door is north of it: %s" % [
			strip1.position.y, strip1.position.y - pump.y, _p("Buildings/Farmhouse").y < pump.y])
	var in20 := []
	for g in [&"creature_cover", &"trap_spots", &"crow_perches", &"scarecrow_spots"]:
		for m in _group(g):
			var dm := pump.distance_to(Vector2(m.global_position.x, m.global_position.z))
			if dm <= 20.0:
				in20.append("%s %.1f" % [m.name, dm])
	print("markers within 20 m of the pumpkin: ", in20)


func _corn_rect(n: String) -> Rect2:
	var b := _world.get_node("CornBlockers/" + n)
	var s: Vector3 = (b.get_node("Mesh") as MeshInstance3D).mesh.size
	return Rect2(b.position.x - s.x / 2, b.position.z - s.z / 2, s.x, s.z)


func _corn_dist(p: Vector2) -> float:
	var best := 1e9
	for r in _corn:
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		best = minf(best, p.distance_to(q))
	return best


func _lure_and_ghost() -> void:
	print("-- doc 04 s8.3 lure 15 m / s8.4 ghost 20 m")
	var spots := {"barn door": _p("Buildings/Barn"), "farmhouse door": _p("Buildings/Farmhouse"),
			"shed door": _p("Buildings/ToolShed"), "generator": _p("Props/Generator"), "fuel drum": _p("Props/FuelDrum"),
			"well": _p("Props/Well"), "pen gate": _p("Pen/PenGate"), "field A": _centre("a"), "field B": _centre("b"),
			"crate": _p("Props/ShippingCrate"), "moonflower": _centre("moonflower"), "pumpkin": _p("Props/PrizePumpkin"),
			"farm gate": _p("Props/FarmGate"), "town stand": _p("Props/TownStand")}
	var names := spots.keys()
	var close := []
	for i in names.size():
		for j in range(i + 1, names.size()):
			var d: float = spots[names[i]].distance_to(spots[names[j]])
			if d < 15.0:
				close.append("%s-%s %.1f" % [names[i], names[j], d])
	print("work-spot pairs under 15 m: ", close, " (doc: shed-drum 5.1, B-crate 10.5, barn-gen 12.5, gate-stand 15.0)")
	if close.size() != 3:
		_fails += 1
	for n in names:
		var d := _corn_dist(spots[n])
		print("corn within %-14s %5.1f m" % [n, d])
	# doc 04 s8.4 table values; field centres use the plot-grid edge, as the doc does ("12.0" for field A centre)
	_expect("corn near pumpkin", _corn_dist(spots["pumpkin"]), 7.0, 0.5)
	_expect("corn near drum", _corn_dist(spots["fuel drum"]), 11.0, 0.5)
	_expect("corn near barn door", _corn_dist(spots["barn door"]), 12.0, 0.5)
	_expect("corn near shed door", _corn_dist(spots["shed door"]), 13.4, 0.5)
	_expect("corn near pen gate", _corn_dist(spots["pen gate"]), 17.0, 0.5)
	_expect("corn near generator", _corn_dist(spots["generator"]), 23.0, 0.5)
	_expect("corn near well", _corn_dist(spots["well"]), 32.2, 0.5)
	_expect("corn near farm gate", _corn_dist(spots["farm gate"]), 4.0, 0.5)
	# deep spots: 10 m or more inside the ring (doc 04 s7.1) = >= 10 m from the clearing rectangle
	var clearing := Rect2(-65, -45, 170, 100)
	for t in _group(&"trap_spots"):
		if t.get_meta(&"kind") == "deep":
			var p := Vector2(t.global_position.x, t.global_position.z)
			var dd := p.distance_to(Vector2(clampf(p.x, clearing.position.x, clearing.end.x), clampf(p.y, clearing.position.y, clearing.end.y)))
			print("%s %s deep: %.1f m inside the ring (>= 10)" % ["ok  " if dd >= 10 else "FAIL", t.name, dd])
			if dd < 10:
				_fails += 1
	# 20 m sanctuary radius: nothing of the cart route, no plot
	var stand := _p("Props/TownStand")
	for p in _group(&"plot_spots"):
		if stand.distance_to(Vector2(p.global_position.x, p.global_position.z)) <= 10.0:
			_fails += 1
			print("FAIL plot inside sanctuary: ", p.name)


func _route() -> void:
	print("-- doc 04 s6.1 cart route")
	var path := _world.get_node("CartRoute") as Path3D
	var c := path.curve
	var len_m := 0.0
	var least := 1e9
	for i in c.point_count:
		var p := c.get_point_position(i)
		if i > 0:
			len_m += p.distance_to(c.get_point_position(i - 1))
		print("R%d (%.0f, %.0f) corn %.1f m" % [i, p.x, p.z, _corn_dist(Vector2(p.x, p.z))])
	# sample each leg for the closest approach to corn
	for i in range(1, c.point_count):
		var a := c.get_point_position(i - 1)
		var b := c.get_point_position(i)
		for k in 101:
			var q := a.lerp(b, k / 100.0)
			least = minf(least, _corn_dist(Vector2(q.x, q.z)))
	_expect("route length", len_m, 147.9)
	_expect("closest pass to corn (gate end)", least, 3.7, 0.15)
	var gate := _p("Props/FarmGate")
	var last := c.get_point_position(c.point_count - 1)
	_expect("R8 on the gate", Vector2(last.x, last.z).distance_to(gate), 0.0)
