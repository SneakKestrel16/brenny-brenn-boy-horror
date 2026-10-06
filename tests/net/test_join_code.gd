extends SceneTree
## Join code checks, doc 06 section 4 "Format" (PP-02 adds this as the test that section promises).
##   "$GODOT" --headless --path . -s res://tests/net/test_join_code.gd
## Exits 0 on pass, 1 on any failure. Covers doc 06's two examples, round trips, typed-input
## normalisation, and that every single wrong character and every neighbour swap is caught over
## random addresses (fixed seed, so a failure reproduces).
## Uses the spike's implementation (spikes/voice/join_code.gd); DD Phase 1 points it at game/net/.

const JoinCode := preload("res://spikes/voice/join_code.gd")
const ADDRESSES := 3000

var _fails := 0


func _init() -> void:
	_check(JoinCode.encode("203.0.113.7") == "SC07-21W2", "doc example, default port")
	_check(JoinCode.encode("203.0.113.7", 45121) == "SC07-21XG-85AX", "doc example, port 45121")
	var d := JoinCode.decode("sc07 21w2")
	_check(d["ok"] and d["ip"] == "203.0.113.7" and d["port"] == 45120, "lower case and space")
	d = JoinCode.decode("SCO7-2lW2")  # O for 0, l for 1
	_check(d["ok"] and d["ip"] == "203.0.113.7", "O reads as 0, L reads as 1")
	_check(not JoinCode.decode("SC07-21W").get("ok", true), "7 characters rejected")
	_check(not JoinCode.decode("SC07-21WU").get("ok", true), "U is not in the alphabet")
	_check(JoinCode.classify("192.168.1.20") == "private", "classify private")
	_check(JoinCode.classify("100.101.102.103") == "cgnat", "classify CGNAT / Tailscale range")
	_check(JoinCode.classify("203.0.113.7") == "public", "classify public")
	print("127.0.0.1 default port: ", JoinCode.encode("127.0.0.1"))

	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var undetected := 0
	var tried := 0
	for i in ADDRESSES:
		var ip := "%d.%d.%d.%d" % [rng.randi_range(1, 223), rng.randi_range(0, 255),
				rng.randi_range(0, 255), rng.randi_range(0, 255)]
		var p := JoinCode.DEFAULT_PORT if i % 2 == 0 else rng.randi_range(1024, 65535)
		if p == JoinCode.DEFAULT_PORT and i % 2 == 1:
			p += 1
		var code := JoinCode.normalise(JoinCode.encode(ip, p))
		var back := JoinCode.decode(code)
		_check(back["ok"] and back["ip"] == ip and back["port"] == p, "round trip %s:%d" % [ip, p])
		for pos in code.length():
			for ch in JoinCode.ALPHABET:
				if ch == code[pos]:
					continue
				tried += 1
				var bad := code.substr(0, pos) + ch + code.substr(pos + 1)
				if JoinCode.decode(bad)["ok"]:
					undetected += 1
			if pos + 1 < code.length() and code[pos] != code[pos + 1]:
				tried += 1
				var sw := code.substr(0, pos) + code[pos + 1] + code[pos] + code.substr(pos + 2)
				if JoinCode.decode(sw)["ok"]:
					undetected += 1
	_check(undetected == 0, "%d undetected of %d single substitutions and neighbour swaps" % [undetected, tried])
	print("join code: %d typo variants over %d addresses, %d undetected" % [tried, ADDRESSES, undetected])
	print("JOIN CODE TEST ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: ", what)
