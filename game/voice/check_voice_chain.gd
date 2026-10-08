extends SceneTree
## P3-10 checks: the ghost static chain (doc 06 section 9).
##   "$GODOT" --headless --audio-driver Dummy --path . --script res://game/voice/check_voice_chain.gd
## Every tell maps to its ghost twin, the twins send into VoiceGhost, the static is procedural and
## loops, and a ghost-bus voice gets the static layer whatever the tell. Exit code 1 on a FAIL.

const Chain := preload("res://game/audio/voice_chain.gd")

var _fails := 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var want := {&"none": &"VoiceGhost", &"no_crackle": &"VoiceGhost", &"echo": &"VoiceGhostEcho",
			&"pitch_up": &"VoiceGhostPitchUp", &"pitch_down": &"VoiceGhostPitchDown"}
	for tell: StringName in want:
		_check("%s alive stays clean" % tell, not Chain.is_ghost_bus(Chain.bus_for(tell)))
		_check("%s dead -> %s" % [tell, want[tell]], Chain.bus_for(tell, true) == want[tell])
	for b in [&"VoiceGhostEcho", &"VoiceGhostPitchUp", &"VoiceGhostPitchDown"]:
		var i := AudioServer.get_bus_index(b)
		_check("%s sends into VoiceGhost" % b, AudioServer.get_bus_send(i) == &"VoiceGhost")
		_check("%s after VoiceGhost" % b, i > AudioServer.get_bus_index(&"VoiceGhost"))
	_check("VoiceGhost has band and drive", AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"VoiceGhost")) == 3)
	var s := Chain.static_stream()
	_check("static is 1 s, looping", s.data.size() == Chain.STATIC_RATE * 2 and s.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	for tell: StringName in [&"none", &"no_crackle"]:
		var p := AudioStreamPlayer3D.new()
		root.add_child(p)
		Chain.attach_crackle(p, tell, Chain.bus_for(tell, true))
		_check("%s ghost fake has static" % tell, p.has_node(^"GhostStatic"))
		_check("%s crackle as the tell says" % tell, p.has_node(^"Crackle") == (tell != &"no_crackle"))
		p.free()
	var clean := AudioStreamPlayer3D.new()
	root.add_child(clean)
	Chain.attach_crackle(clean, &"echo", Chain.bus_for(&"echo"))
	_check("living fake has no static", not clean.has_node(^"GhostStatic"))
	clean.free()
	print("check_voice_chain: %s" % ("PASS" if _fails == 0 else "%d FAIL" % _fails))
	quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", what])
