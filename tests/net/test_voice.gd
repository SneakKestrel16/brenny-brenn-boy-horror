extends SceneTree
## Doc 06 section 8 unit checks for the voice volume byte and the jitter buffer's sequence ring (P1-06).
##   "$GODOT" --headless --path . -s res://tests/net/test_voice.gd
## voice.gd and voice_emitter.gd name autoloads, which do not resolve when this script is compiled, so they
## load after a frame (a preload fails to compile under -s and the test hangs before quit, Q-057).

var _fails := 0


func _initialize() -> void:
	await process_frame
	var voice: GDScript = load("res://game/voice/voice.gd")
	var emitter: GDScript = load("res://game/voice/voice_emitter.gd")
	var normal: float = voice.NORMAL_DB
	_check(voice.volume_byte(normal) == 159, "normal level is byte 159")
	_check(voice.volume_byte(normal - 30.0) == 1, "30 dB under normal clamps to 1, never 0")
	_check(voice.volume_byte(normal + 18.0) == 255, "18 dB over normal is 255")
	_check(voice.volume_byte(normal + 40.0) == 255, "louder still clamps to 255")
	_check(emitter._seq_diff(0, 65535) == 1, "seq 0 follows 65535")
	_check(emitter._seq_diff(65535, 0) == -1, "seq 65535 precedes 0")
	_check(emitter._seq_diff(10, 3) == 7, "plain difference")
	print("test_voice: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", what)
