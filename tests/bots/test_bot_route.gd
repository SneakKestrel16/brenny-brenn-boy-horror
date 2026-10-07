extends SceneTree
## P1-13: bot routes across the DD Phase 1 gray box never enter strip 2 and cross the barn wall only
## at the door (doc 04 section 9).
##   "$GODOT" --headless --path . -s res://tests/bots/test_bot_route.gd

const Route := preload("res://game/bots/bot_route.gd")

## Spawns, plots, sell box, well, fuel drum and generator stand points (game/bots/bot.gd).
const SPOTS := [Vector3(-3, 0, -8), Vector3(3, 0, -8), Vector3(25.5, 0, -7), Vector3(34.5, 0, -1),
		Vector3(38.4, 0, 20), Vector3(-23.4, 0, 10), Vector3(-11.5, 0, 27), Vector3(-12.5, 0, -6),
		Vector3(0, 0, 6), Vector3(22, 0, 0), Vector3(30, 0, 1), Vector3(-20, 0, 8)]

var _fails := 0


func _initialize() -> void:
	for a in SPOTS:
		for b in SPOTS:
			_check_route(a, b)
	print("test_bot_route: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check_route(a: Vector3, b: Vector3) -> void:
	var pts: Array = [a] + Route.path(a, b)
	if pts.back() != b:
		_fail("%s -> %s does not end at the target" % [a, b])
	for i in pts.size() - 1:
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[i + 1]
		var n := maxi(int(p.distance_to(q) / 0.1), 1)
		var was_in := Route.in_barn(p)
		for s in n + 1:
			var x := p.lerp(q, float(s) / n)
			var bad := ""
			if x.x > 12.0 and x.x < 18.0 and x.z < 2.0:
				bad = "enters strip 2"
			elif Route.in_barn(x) != was_in and absf(x.x) > 1.5:
				bad = "crosses the barn wall"
			elif x.x < -8.0 and x.x > -8.5 and x.z < 0.0 and x.z > -20.0:
				bad = "crosses the barn's west wall"
			if bad != "":
				_fail("%s -> %s %s at %s" % [a, b, bad, x])
				return
			was_in = Route.in_barn(x)


func _fail(what: String) -> void:
	_fails += 1
	printerr("FAIL: ", what)
