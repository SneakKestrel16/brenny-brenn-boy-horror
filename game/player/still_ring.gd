extends RefCounted
## Doc 05 section 6 / doc 03 section 3: the host's 1 s ring of received positions. "Still" means the
## player moved less than STILL_M (flat) over the last STILL_S, judged from transforms alone so a
## hacked client cannot claim stillness. Pure data, no autoloads: tests/gameplay/test_still_ring.gd.

const STILL_M := 0.2  ## doc 03 section 3: under 0.2 m in 1 s (placeholder)
const STILL_MS := 1000
const SLACK_MS := 60  ## the ring must span about a full second, allowing one 20 Hz tick of jitter

var _t: PackedInt32Array = PackedInt32Array()
var _p: PackedVector2Array = PackedVector2Array()


## `t_ms` is the host receive time of the frame.
func push(t_ms: int, pos: Vector3) -> void:
	_t.append(t_ms)
	_p.append(Vector2(pos.x, pos.z))
	while _t.size() > 2 and _t[1] <= t_ms - STILL_MS:  # keep one sample at or before the window start
		_t.remove_at(0)
		_p.remove_at(0)


## Furthest the body has been from its newest position inside the window (metres).
func moved_m() -> float:
	var n := _t.size()
	var m := 0.0
	for i in n:
		m = maxf(m, _p[i].distance_to(_p[n - 1]))
	return m


func is_still() -> bool:
	var n := _t.size()
	return n >= 2 and _t[n - 1] - _t[0] >= STILL_MS - SLACK_MS and moved_m() < STILL_M
