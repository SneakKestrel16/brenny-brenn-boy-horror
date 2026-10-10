extends SceneTree
## QA P5-55: a bot (moves by position) does not walk through a closed barn door: it stops and opens it, so a "door" log line
## with open=true and by=<bot> appears, and the bot is never outside while the door is closed.
## godot --headless --audio-driver Dummy -s res://tests/qa/qa_p5_55_bot_door.gd -- --host --port=56802 --free-mouse --seed=1 --bots=1 --bot-chores
## Prints "QA_BOTDOOR PASS|FAIL". Single instance.

var _t := 0.0
var _closed_t := -1.0
var _leaks := 0


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _physics_process(delta: float) -> bool:
	if not root.has_node("Main/Doors") or not root.has_node("Main/Bots"):
		return false
	_t += delta
	var doors := root.get_node("Main/Doors")
	var game := root.get_node("Game")
	var bots: Array = game.players.keys().filter(func(p: int) -> bool: return p != 1)
	if bots.is_empty():
		return false
	var bot: Node = root.get_node("Main/Players/%d" % bots[0])
	var bp: Vector3 = bot.global_position
	var inside: bool = Rect2(-8.0, -20.0, 16.0, 20.0).has_point(Vector2(bp.x, bp.z))  # the BARN rect (x -8..8, z -20..0)
	if _closed_t < 0.0:
		if _t > 1.0 and inside:  # shut it behind the bot, before its first chore
			doors.host_set("door_barn", false, 0)
			_closed_t = _t
		return false
	if not doors.open["door_barn"] and not inside:
		_leaks += 1
	if _t - _closed_t > 100.0 or (doors.open["door_barn"] and bot.global_position.z > 2.0):
		print("door open=%s bot=%s leaks=%d" % [doors.open["door_barn"], bot.global_position, _leaks])
		print("QA_BOTDOOR ", "PASS" if _leaks == 0 and doors.open["door_barn"] and bot.global_position.z > 2.0 else "FAIL")
		quit()
	return false
