extends SceneTree
## Doc 05 section 6 unit check for the host's stillness ring (P1-07): 0.19 m in 1 s is still, 0.21 m is not.
##   "$GODOT" --headless --path . -s res://tests/gameplay/test_still_ring.gd

const StillRing := preload("res://game/player/still_ring.gd")

var _fails := 0


func _init() -> void:
	_check(_run(0.19, 1000), "0.19 m in 1 s is still")
	_check(not _run(0.21, 1000), "0.21 m in 1 s is not still")
	_check(not _run(0.0, 400), "less than a second of history is not still")
	_check(not _run(5.0, 3000), "walking is not still")
	var r := StillRing.new()  # walks, then stops: still only after a full second of standing
	for i in 41:
		r.push(i * 50, Vector3(i * 0.1, 0, 0))
	_check(not r.is_still(), "just stopped is not yet still")
	for i in 22:
		r.push(2000 + i * 50, Vector3(4.0, 0, 0))
	_check(r.is_still(), "a second after stopping is still")
	print("test_still_ring: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


## Moves `dist` metres in a straight line over `span_ms`, sampled at 20 Hz.
func _run(dist: float, span_ms: int) -> bool:
	var r := StillRing.new()
	for t in range(0, span_ms + 1, 50):
		r.push(t, Vector3(dist * t / float(span_ms), 0, 0))
	return r.is_still()


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
