extends SceneTree
## P5-45: every emote in data/emotes.json has a one-shot animation on the farmer body, the extra ones are code poses
## keyed by bone name that move at least two bones off rest, and only the scream is loud. (The wheel needs the Game
## autoload, so it is checked in the windowed run.)
##   godot --headless --audio-driver Dummy --path . -s res://tests/gameplay/test_emotes.gd

const FarmerBody := preload("res://game/player/farmer_body.gd")
const EmotePoses := preload("res://game/player/emote_poses.gd")
var _fails := 0


func _init() -> void:
	var data: Node = preload("res://game/core/data.gd").new()
	data.load_dir("res://data")
	var ids: Array[StringName] = []
	for r in data.records(&"emotes"):
		ids.append(StringName(r["id"]))
		_check(bool(r["loud"]) == (r["id"] == "scream"), "%s loudness" % r["id"])
	_check(ids.size() >= 10, "at least 10 emotes (%d)" % ids.size())
	for k in EmotePoses.KINDS:
		_check(k in ids, "pose %s is listed in data" % k)
	var body := FarmerBody.new(0)
	root.add_child(body)
	var ap: AnimationPlayer = body.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for k in ids:
		_check(body.has_anim(k) and ap.get_animation(k).loop_mode == Animation.LOOP_NONE, "%s is a one-shot" % k)
		_check(body.shot(k) > 1.0, "%s has a length" % k)
	for k in EmotePoses.KINDS:
		var a := ap.get_animation(k)
		var moved := 0
		for t in a.get_track_count():
			var bone := sk.find_bone(String(a.track_get_path(t)).get_slice(":", 1))
			_check(bone >= 0, "%s track names a real bone" % k)
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				for i in a.track_get_key_count(t):
					if not (a.track_get_key_value(t, i) as Quaternion).is_equal_approx(sk.get_bone_rest(bone).basis.get_rotation_quaternion()):
						moved += 1
						break
		_check(moved >= 2, "%s moves at least two bones (%d)" % [k, moved])
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).mesh.get_surface_count():
			(mi as MeshInstance3D).set_surface_override_material(s, null)
	root.remove_child(body)
	body.free()
	await process_frame
	print("test_emotes: %s (%d failures)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + what)
