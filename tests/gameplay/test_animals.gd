extends SceneTree
## P4-08: animal rules (pure) and the host flow: break a fence, animals escape 60 m+, round-up, fix, dusk bill.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_animals.gd -- --host --port=45398 --free-mouse
const Logic := preload("res://game/farming/animal_logic.gd")

var _t := 0.0
var _stage := 0
var _fails := 0


func _initialize() -> void:
	_check(Logic.round_up_s(4.0, 0.6) == 3.0, "Rancher round-up 4 s x0.6 = 2.4 rounds up to 3")
	_check(Logic.round_up_s(4.0, 1.0) == 4.0, "no perk: 4 s stays 4")
	_check(Logic.dusk_bill(2, 10, 100, 50, 4) == [20, 20], "2 out, 10 coins each at 100%: 20")
	_check(Logic.dusk_bill(2, 10, 59, 50, 4) == [12, 12], "pct 59: ceil(5.9) = 6 each, 2 out = 12")
	_check(Logic.dusk_bill(3, 10, 100, 10, 4) == [30, 6], "bank floor 4: only 6 paid, shortfall not carried")
	_check(Logic.far_spots([Vector3(0, 0, 0), Vector3(70, 0, 0)], Vector3.ZERO, 60.0).size() == 1, "far_spots keeps only 60 m+")
	_check(Logic.step_toward(Vector3.ZERO, Vector3(10, 0, 0), 3.0).x == 3.0, "step_toward moves 3 m")
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var main := current_scene
	var an: Node = main.get_node_or_null("Animals") if main else null
	if an == null or main.get_node_or_null("Death") == null or main.get_node("Farm").registry == null:
		if _t > 25.0:
			print("test_animals: FAIL (no Animals after 25 s)")
			quit(1)
		return false
	var farm: Node = main.get_node("Farm")
	var sab: Node = main.get_node("AiDirector/Sabotage")
	var gate: Vector3 = get_first_node_in_group("pen_gates").global_position
	var is_loose := func(a: Dictionary) -> bool: return a.state == &"loose"
	if _stage == 0:
		_stage = 1
		_check(an.herd.size() == 6, "6 animals (3 species x 2)")
		_check(get_nodes_in_group("fence_sections").size() == 6, "6 fence sections")
		_check(sab.call("_place", &"broken_fence"), "Sabotage placed broken_fence")
		_check(an.broken.size() == 1, "one section broken")
		_check(an.herd.filter(is_loose).size() == 2, "2 animals loose")
		_check(an.herd.filter(is_loose).all(func(x: Dictionary) -> bool: return (x.path[2] - x.path[1]).dot(x.path[1] - x.path[0]) > 0.0),
				"escape spot lies on the broken wall's outer side (QA P4-08)")
		_check(sab.live.size() == 1 and sab.live.values()[0].kind == &"broken_fence", "disturbance live")
		_check(farm.targets.has("dist_%d" % sab.live.keys()[0]), "repair_fence target exists")
		_check(farm.targets["dist_%d" % sab.live.keys()[0]].verbs_for({}) == [&"repair_fence"], "target offers repair_fence")
	elif _stage == 1:
		var arrived: Array = an.herd.filter(func(a: Dictionary) -> bool: return a.state == &"loose" and a.path.is_empty())
		if arrived.size() == 2 or _t > 40.0:
			_stage = 2
			for a: Dictionary in an.herd.filter(is_loose):
				var d := Vector2(a.pos.x - gate.x, a.pos.z - gate.z).length()
				_check(d >= 55.0, "loose animal %.0f m from the gate (idle wander may be 4 m off a 60 m spot)" % d)
			var i: int = an.herd.find_custom(is_loose)
			_check(farm.targets["animal_%d" % i].verbs_for({}) == [&"round_up"], "loose animal offers round_up")
			an.out_at_dusk = 2
			farm.coins = 100
			an.bill_dusk(farm)
			_check(farm.coins < 100 and farm.coins >= 100 - 2 * 10, "dusk bill took 1 to 20 coins (%d left)" % farm.coins)
			_check(an.herd.all(func(a: Dictionary) -> bool: return a.state == &"pen"), "bill returns them to the pen")
			an.herd[0].state = &"loose"
			an.herd[0].pos = Vector3(-24.0, 0.0, -70.0)  # north of the pen: the walk home goes round it (QA P4-08)
			an.round_up_done(0, 1)
			_check(an.herd[0].state == &"home", "round_up_done walks it home")
			var pts: Array = [an.herd[0].pos] + an.herd[0].path
			var crosses := false
			for s in range(pts.size() - 3):  # up to the gate front; the last legs enter through the gate
				for k in 21:
					var q: Vector3 = (pts[s] as Vector3).lerp(pts[s + 1], k / 20.0)
					crosses = crosses or Rect2(-30.0, -38.0, 12.0, 10.0).has_point(Vector2(q.x, q.z))
			_check(not crosses, "walk home stays outside the pen walls until the gate")
			an.fix_fence(an.broken.keys()[0])
			_check(an.broken.is_empty(), "fence fixed")
			print("test_animals: ", "PASS" if _fails == 0 else "FAIL")
			quit(1 if _fails > 0 else 0)
	return false


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  ", "ok  " if ok else "FAIL", what)
