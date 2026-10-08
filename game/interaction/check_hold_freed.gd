extends SceneTree
## P2-11 fix-round test: a trap target freed mid-hold (TrapRace._forget on `trap_changed`) must not crash the
## holder's HoldController before `hold_done` arrives. Run:
##   godot --headless --path . --script res://game/interaction/check_hold_freed.gd
## Prints PASS; a freed-object error fails the run (exit code 1 from the checks below, SCRIPT ERROR in the log).

class FakePlayer extends CharacterBody3D:
	var _cam := Camera3D.new()
	var ghost := false
	var pinned := false
	var peer := 2

class FakeTarget extends Node3D:
	var id := "trap_1"
	func target_pos() -> Vector3:
		return position


func _initialize() -> void:
	await process_frame  # autoloads (Data) are ready from the first frame
	var player := FakePlayer.new()
	root.add_child(player)
	player.add_child(player._cam)
	var hc: Node = load("res://game/interaction/hold_controller.gd").new()
	player.add_child(hc)
	var target := FakeTarget.new()
	root.add_child(target)
	hc._scripted = true  # no key held in a test: do not cancel on release
	hc.start(&"fill_pit", target)
	hc._physics_process(0.016)
	target.free()  # TrapRace._forget
	hc._physics_process(0.016)  # was: target_pos() on a freed object
	hc._on_apply(&"hold_done", [&"fill_pit", "trap_1"])  # was: _target.id on a freed object
	var ok: bool = not hc._holding
	print("check_hold_freed: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
