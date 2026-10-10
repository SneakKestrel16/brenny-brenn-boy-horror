extends SceneTree
## P5-10 (Gameplay): the dev gate is closed by default and the squeaky effect adds and removes cleanly.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_dev_gate.gd
## Add `-- --dev-gate-test-hash=<this machine's hash>` to test the open case (the second run prints PASS too).

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("test_dev_gate: FAIL ", what)


func _initialize() -> void:
	var h := DevGate.machine_hash()
	_check(h.length() == 64 and h == h.to_lower(), "machine_hash is 64 lowercase hex")
	_check(h != OS.get_unique_id(), "the raw id is never the hash")
	_check(DevGate.HASHES.is_empty() or not (h in DevGate.HASHES) or DevGate.unlocked(), "a listed hash opens the gate")
	var armed := false
	for a in OS.get_cmdline_user_args():
		armed = armed or a == DevGate.TEST_ARG + h
	_check(DevGate.unlocked() == (armed or h in DevGate.HASHES), "gate opens only by a listed hash or the matching test hash (--dev and debug builds do not)")
	# Squeaky: one effect on the Voice bus, removed again.
	var bus := AudioServer.get_bus_index(&"Voice")
	if bus >= 0:
		var n := AudioServer.get_bus_effect_count(bus)
		Squeaky.set_on(true)
		Squeaky.set_on(true)
		_check(Squeaky.is_on() and AudioServer.get_bus_effect_count(bus) == n + 1, "squeaky adds exactly one effect")
		Squeaky.set_on(false)
		_check(not Squeaky.is_on() and AudioServer.get_bus_effect_count(bus) == n, "squeaky removes it again")
	print("test_dev_gate: ", "PASS (gate %s)" % ("open" if DevGate.unlocked() else "closed") if _fails == 0 else "FAIL x%d" % _fails)
	quit(0 if _fails == 0 else 1)
