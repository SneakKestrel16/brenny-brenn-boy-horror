extends SceneTree
## P5-68: the jumpscare shows the season's body glb, not a capsule. Forces `scare jumpscare` on the host
## through the dev console, checks the `Apparition` node is the body (no CapsuleMesh), then checks a
## hallucination is the body too and the wrong count stays a farmer capsule. Windowed runs also save a PNG
## mid-flash. Exits 0 on pass, 1 on any failure.
## 2-instance: host `-- --host --lobby-start=2 --target=2 ...`, joiner `-- --join=127.0.0.1:<port> ...`; the joiner must PASS.
##   "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/shot_p5_68.gd -- --host --lobby-start=1 --no-intro --port=34680 --free-mouse --creature-body=boar [--phase=night] [--no-shake] [--at=x,z] [--out=<png>]

var _f := 0
var _fails := 0
var _dev: Node
var _main: Node
var _seen := -1
var _arg := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			_arg[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1)
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _capsule(n: Node) -> bool:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is CapsuleMesh:
		return true
	return n.find_children("*", "MeshInstance3D", true, false).any(func(m: MeshInstance3D) -> bool: return m.mesh is CapsuleMesh)


func _process(_d: float) -> bool:
	if not root.has_node(^"Main"):  # frames count from the match start (a lobby waits for its players)
		return false
	_f += 1
	if _f == 120:
		_main = root.get_node("Main")
		for c in _main.get_children():
			if c.get_script() and c.get_script().resource_path.ends_with("dev_console.gd"):
				_dev = c
		if _arg.has("no-shake"):  # a level frame without the knockdown roll (set APPDATA to a temp dir: settings persist)
			root.get_node("Settings").set_value(&"camera_shake", 0.0)
		if _arg.has("at"):  # stand the host's farmer at x,z (outdoors: the spawn is in the barn)
			var xz: PackedFloat64Array = _arg.at.split_floats(",")
			_main.get_node("Players").player(1).global_position = Vector3(xz[0], 0.0, xz[1])
		if _arg.has("phase"):
			print(_dev.run("phase %s" % _arg.phase))
	if _arg.has("target"):  # 2-instance run: this host only fires at the joiner (`--target=2`, the 2nd player) and exits
		if _f >= 240 and _seen < 0 and root.get_node("Game").players.size() >= 2:
			var reply: String = _dev.run("scare jumpscare %s" % _arg.target)
			print(reply)
			_seen = -1 if reply.begins_with("?") else _f
		if _f == 1500:
			quit(0 if _seen > 0 else 1)
		return false
	if _f == 240:
		print(_dev.run("scare jumpscare"))  # on a joiner: "host only", it waits for the host's `--target`
	if _f > 240 and _seen < 0:
		var n := _main.get_node_or_null(^"Apparition")
		if n:
			_seen = _f
			var body := String(root.get_node("Soundscape").creature_body)
			print("shot: body %s, apparition %s" % [body, n.get_class()])
			_check(body != "", "the season's body is known on this peer")
			_check(not _capsule(n), "the jumpscare apparition is not a capsule")
			_check(n.find_children("*", "OmniLight3D", true, false).size() == 1, "the jumpscare carries its own lamp")
			n.name = "Jump"  # the checks below add more apparitions
		elif _f > 1500:
			_check(false, "a jumpscare apparition appeared")
			quit(1)
	if _seen > 0 and _f == _seen + 6:  # about 0.1 s into the 0.4 s flash
		if DisplayServer.get_name() != "headless" and _arg.has("out"):
			root.get_viewport().get_texture().get_image().save_png(_arg.out)
	if _seen > 0 and _f == _seen + 40:
		var scares := _main.get_node("Scares")
		scares._apparition(Vector3(0, 0, -20), &"hallucination", 0.2)
		var h := _main.get_node_or_null(^"Apparition")
		_check(h != null and not _capsule(h), "a hallucination is the body, not a capsule")
		if h:
			h.name = "Done"
		scares._apparition(Vector3(0, 0, -20), &"wrong_count", 0.2)
		var w := _main.get_node_or_null(^"Apparition")
		_check(w != null and _capsule(w), "the wrong count stays a farmer capsule")
	if _seen > 0 and _f == _seen + 80:
		print("P5-68 %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
		quit(1 if _fails else 0)
	return false
