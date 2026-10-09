extends SceneTree
## P4-07 (QA): a client mirrors the host's debt through `apply_debt`. Run as the client of a 2-instance session
## whose host pays early and runs the first-payment dawn:
##   uv run tools/qa/multi.py -n 2 --headless --duration 60 \
##     --args "-- --host --port=48450 --free-mouse --dev-exec=\"wait 4; coins 300; pay; day 3; phase dawn\"" \
##     --args "-s res://tests/net/test_debt_sync.gd -- --join=127.0.0.1 --port=48450 --free-mouse"

var _t := 0.0
var _early := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var death := current_scene.get_node_or_null("Death") if current_scene else null
	if death != null and death.debt != null:
		var d: Node = death.debt
		if _early == 0 and d.paid > 0:
			_early = d.paid
			print("test_debt_sync: early payment mirrored, paid %d owed %d" % [d.paid, d.owed])
		if d.first_made and d.paid > _early:
			print("test_debt_sync: PASS (first_made, paid %d, owed %d)" % [d.paid, d.owed])
			quit(0)
			return false
	if _t > 45.0:
		print("test_debt_sync: FAIL (early %d, first_made %s)" % [_early, death.debt.first_made if death else "no Death"])
		quit(1)
	return false
