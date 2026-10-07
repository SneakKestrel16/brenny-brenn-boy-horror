extends SceneTree
## Doc 05 section 6 unit checks for the host speed check and the move packet (P1-04).
##   "$GODOT" --headless --path . -s res://tests/gameplay/test_speed_check.gd

const SpeedCheck := preload("res://game/player/speed_check.gd")
const Frame := preload("res://game/player/move_frame.gd")

var _fails := 0


func _init() -> void:
	var o := Vector3.ZERO
	var r := SpeedCheck.check(o, Vector3(0.9, 0, 0), 0.05, 5.0)  # 18 m/s? no: 0.9/0.05 = 18 -> over 3x5
	_check(r.teleport and r.violation and r.pos == o, "18 m/s sprint-max 5 is a teleport")
	r = SpeedCheck.check(o, Vector3(0.25, 0, 0), 0.05, 5.0)  # exactly 5 m/s
	_check(not r.violation and r.pos.x == 0.25, "5 m/s at max 5 passes")
	r = SpeedCheck.check(o, Vector3(0.29, 0, 0), 0.05, 5.0)  # 5.8 m/s, under +20%
	_check(not r.violation, "5.8 m/s (under +20%) passes")
	r = SpeedCheck.check(o, Vector3(0.6, 1.0, 0), 0.05, 5.0)  # 12 m/s: clamp, not teleport
	_check(r.violation and not r.teleport and is_equal_approx(r.pos.x, 0.3) and r.pos.y == 1.0, "12 m/s is clamped to 6 m/s, y kept")
	r = SpeedCheck.check(o, Vector3(0.2, 0, 0), 0.05, 1.2)  # crouch walking at 4 m/s
	_check(r.violation and r.teleport, "crouch max 1.2: 4 m/s is over 3x")
	r = SpeedCheck.check(o, Vector3(0.1, 0, 0), 0.05, 1.2)  # 2 m/s: 1.67x
	_check(r.violation and not r.teleport, "crouch max 1.2: 2 m/s is clamped")

	var pkt := Frame.pack(7, Vector3(1.5, 0.0, -3.25), 0.5, -0.25, true, false)
	var f := Frame.unpack(pkt, 1)
	_check(f.seq == 7 and f.pos == Vector3(1.5, 0.0, -3.25) and f.crouch and not f.sprint, "frame round-trips")
	print("test_speed_check: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
