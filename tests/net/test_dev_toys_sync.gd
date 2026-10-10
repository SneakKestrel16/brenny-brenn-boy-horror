extends SceneTree
## P5-10 (Gameplay): a dev toy started on the host runs on a client too. Run as the client of a 2-instance
## session whose host holds the gate (the test hash is this machine's own, printed by print_machine_hash.gd):
##   H=$("$GODOT" --headless --path . -s res://game/core/print_machine_hash.gd | sed -n 3p)
##   uv run tools/qa/multi.py -n 2 --headless --duration 40 \
##     --args "-- --host --port=53300 --free-mouse --dev-gate-test-hash=$H --dev-exec=\"wait 6; toy shrink\"" \
##     --args "-s res://tests/net/test_dev_toys_sync.gd -- --join=127.0.0.1 --port=53300 --free-mouse"
## Passes when the client's DevToys shows shrink running and its own player is a quarter the size.

var _t := 0.0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(delta: float) -> bool:
	_t += delta
	var toys := current_scene.get_node_or_null("DevToys") if current_scene else null
	var players := current_scene.get_node_or_null("Players") if current_scene else null
	var me: Node = players.player(root.get_node("Game").local_peer()) if players else null
	if toys != null and me != null and toys._until.has(&"shrink") and is_equal_approx(me.body_scale, 0.25):
		print("test_dev_toys_sync: PASS (shrink on the client, body_scale %.2f)" % me.body_scale)
		quit(0)
		return false
	if _t > 30.0:
		print("test_dev_toys_sync: FAIL (toys %s, shrink %s, body_scale %s)" % [toys != null, toys._until if toys else "-", me.body_scale if me else "no player"])
		quit(1)
	return false
