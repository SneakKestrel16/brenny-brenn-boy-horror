extends SceneTree
## P2-16 check: the rejoin shuffle bag (D-050) and the Join screen's input rules (doc 06 s4).
## Run: godot --headless --audio-driver Dummy --path . --script res://game/core/check_rejoin.gd

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)  # Log needs the running tree


func _run() -> void:
	var Rejoin: GDScript = load("res://game/core/rejoin.gd")  # loaded here: the autoloads exist by now, not when this script compiles
	var JoinCode: GDScript = load("res://game/net/join_code.gd")
	var ok := true
	var lines: Array = []
	for i in 50:
		lines.append("line %d" % i)
	var path := "user://check_rejoin_bag.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var last := ""
	for round_i in 6:
		var seen := {}
		for i in 50:
			var l: String = Rejoin.next_line(lines, path)
			ok = ok and not seen.has(l)  # no repeat inside a round
			if i == 0:
				ok = ok and l != last  # a new round never opens on the line shown last
			seen[l] = true
			last = l
		ok = ok and seen.size() == 50
	# the bag survives a restart (it is a file) and follows the data file: a removed line never comes back
	var small: Array = lines.slice(0, 3)
	for i in 6:
		ok = ok and Rejoin.next_line(small, path) in small
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ok = ok and Rejoin.next_line(["only"], path) == "only" and Rejoin.next_line(["only"], path) == "only"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Join screen: codes, raw IPs, typos
	var code: String = JoinCode.encode("203.0.113.7")
	ok = ok and code == "SC07-21W2" and JoinCode.resolve(code).address == "203.0.113.7:45120"
	ok = ok and JoinCode.resolve(JoinCode.encode("203.0.113.7", 45121)).address == "203.0.113.7:45121"
	ok = ok and JoinCode.resolve("SC07-21W3").ok == false  # failed check
	ok = ok and JoinCode.resolve("SC07-21W").ok == false  # code-shaped, wrong length: never read as an IP
	ok = ok and JoinCode.resolve("100.64.0.9:45121").address == "100.64.0.9:45121"
	ok = ok and JoinCode.resolve("localhost").ok == false and JoinCode.resolve("host.lan").address == "host.lan"
	ok = ok and JoinCode.resolve("  ").ok == false
	# D-049: a clean Leave forgets the match, so the next launch shows no rejoin prompt
	Rejoin.save_session("127.0.0.1:45120", "s1")
	ok = ok and not Rejoin.last_session().is_empty()
	root.get_node("Game").leave_session()
	ok = ok and Rejoin.last_session().is_empty()
	print("check_rejoin: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
