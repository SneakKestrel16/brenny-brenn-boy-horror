extends RefCounted
## P5-45: the extra emotes as procedural bone poses, keyed by bone name, so they play on any farmer mesh with the
## 12 bones of `char_farmer.glb` (hips, spine, arm_l/r, forearm_l/r, head, hat, thigh_l/r, shin_l/r) and need no
## clip in the glb. Each key is a rotation in degrees applied on top of the bone's rest rotation, in the bone's own
## frame. Measured on the rig: arm/forearm/thigh `+X` swings forward (arm +X 90 = straight ahead, 180 = overhead),
## arm `Z` swings sideways (left `+Z` = out, right `-Z` = out), shin `-X` bends the knee, spine/head `+X` leans back
## or looks up, `Y` turns, `Z` rolls. `hips_y` is a metres offset on the hips position (crouching, jumping).

const KINDS: Array[StringName] = [&"thumbs_up", &"beckon", &"shh", &"cower", &"cheer", &"facepalm", &"clap"]
const BONES: Array[StringName] = [&"hips", &"spine", &"arm_l", &"forearm_l", &"arm_r", &"forearm_r", &"head",
		&"thigh_l", &"shin_l", &"thigh_r", &"shin_r"]
const PREFIX := "Armature/Skeleton3D:"


## Pose tables: emote -> {length, bone -> [[t, Vector3(x, y, z) degrees], ...]}. A bone left out stays at rest.
static func _defs() -> Dictionary:
	var d := {}
	# QA P5-45: thumbs_up is two-handed and beckon a whole-arm sweep, so neither reads as the other or as wave at 3.2 m.
	d[&"thumbs_up"] = {"len": 1.6,
		&"arm_l": [[0.0, V(0, 0, 0)], [0.25, V(50, 0, 45)], [1.3, V(50, 0, 45)], [1.6, V(0, 0, 0)]],
		&"arm_r": [[0.0, V(0, 0, 0)], [0.25, V(50, 0, -45)], [1.3, V(50, 0, -45)], [1.6, V(0, 0, 0)]],
		&"forearm_l": [[0.0, V(0, 0, 0)], [0.25, V(80, 0, 0)], [0.55, V(100, 0, 0)], [0.8, V(80, 0, 0)],
				[1.05, V(100, 0, 0)], [1.3, V(80, 0, 0)], [1.6, V(0, 0, 0)]],
		&"forearm_r": [[0.0, V(0, 0, 0)], [0.25, V(80, 0, 0)], [0.55, V(100, 0, 0)], [0.8, V(80, 0, 0)],
				[1.05, V(100, 0, 0)], [1.3, V(80, 0, 0)], [1.6, V(0, 0, 0)]],
		&"spine": [[0.0, V(0, 0, 0)], [0.25, V(8, 0, 0)], [1.3, V(8, 0, 0)], [1.6, V(0, 0, 0)]],
		&"head": [[0.0, V(0, 0, 0)], [0.4, V(-12, 0, 0)], [0.7, V(4, 0, 0)], [1.0, V(-12, 0, 0)], [1.6, V(0, 0, 0)]]}
	d[&"beckon"] = {"len": 2.0,
		&"arm_r": [[0.0, V(0, 0, 0)], [0.25, V(85, 0, -5)], [0.55, V(60, 0, -80)], [0.85, V(85, 0, -5)],
				[1.15, V(60, 0, -80)], [1.45, V(85, 0, -5)], [1.75, V(60, 0, -80)], [2.0, V(0, 0, 0)]],
		&"forearm_r": [[0.0, V(0, 0, 0)], [0.25, V(110, 0, 0)], [0.55, V(15, 0, 0)], [0.85, V(110, 0, 0)],
				[1.15, V(15, 0, 0)], [1.45, V(110, 0, 0)], [1.75, V(15, 0, 0)], [2.0, V(0, 0, 0)]],
		&"spine": [[0.0, V(0, 0, 0)], [0.25, V(-10, 0, 0)], [1.75, V(-10, 0, 0)], [2.0, V(0, 0, 0)]],
		&"head": [[0.0, V(0, 0, 0)], [0.25, V(0, 0, 12)], [1.75, V(0, 0, 12)], [2.0, V(0, 0, 0)]]}
	d[&"shh"] = {"len": 2.0,
		&"arm_r": [[0.0, V(0, 0, 0)], [0.3, V(70, 0, 35)], [1.7, V(70, 0, 35)], [2.0, V(0, 0, 0)]],
		&"forearm_r": [[0.0, V(0, 0, 0)], [0.3, V(125, 0, 0)], [1.7, V(125, 0, 0)], [2.0, V(0, 0, 0)]],
		&"spine": [[0.0, V(0, 0, 0)], [0.3, V(-14, 0, 0)], [1.7, V(-14, 0, 0)], [2.0, V(0, 0, 0)]],
		&"head": [[0.0, V(0, 0, 0)], [0.3, V(-8, 0, 0)], [0.7, V(-8, 35, 0)], [1.1, V(-8, -35, 0)], [1.5, V(-8, 35, 0)],
				[2.0, V(0, 0, 0)]]}
	d[&"cower"] = {"len": 2.4,
		&"hips_y": [[0.0, 0.0], [0.3, -0.38], [2.1, -0.38], [2.4, 0.0]],
		&"thigh_l": [[0.0, V(0, 0, 0)], [0.3, V(80, 0, 0)], [2.1, V(80, 0, 0)], [2.4, V(0, 0, 0)]],
		&"thigh_r": [[0.0, V(0, 0, 0)], [0.3, V(80, 0, 0)], [2.1, V(80, 0, 0)], [2.4, V(0, 0, 0)]],
		&"shin_l": [[0.0, V(0, 0, 0)], [0.3, V(-110, 0, 0)], [2.1, V(-110, 0, 0)], [2.4, V(0, 0, 0)]],
		&"shin_r": [[0.0, V(0, 0, 0)], [0.3, V(-110, 0, 0)], [2.1, V(-110, 0, 0)], [2.4, V(0, 0, 0)]],
		&"spine": [[0.0, V(0, 0, 0)], [0.3, V(-40, 0, 0)], [0.45, V(-40, 0, 5)], [0.6, V(-40, 0, -5)], [0.75, V(-40, 0, 5)],
				[0.9, V(-40, 0, -5)], [1.05, V(-40, 0, 5)], [1.2, V(-40, 0, -5)], [1.35, V(-40, 0, 5)], [1.5, V(-40, 0, -5)],
				[1.65, V(-40, 0, 5)], [1.8, V(-40, 0, -5)], [2.1, V(-40, 0, 0)], [2.4, V(0, 0, 0)]],
		&"head": [[0.0, V(0, 0, 0)], [0.3, V(-30, 0, 0)], [2.1, V(-30, 0, 0)], [2.4, V(0, 0, 0)]],
		&"arm_l": [[0.0, V(0, 0, 0)], [0.3, V(95, 0, -25)], [2.1, V(95, 0, -25)], [2.4, V(0, 0, 0)]],
		&"arm_r": [[0.0, V(0, 0, 0)], [0.3, V(95, 0, 25)], [2.1, V(95, 0, 25)], [2.4, V(0, 0, 0)]],
		&"forearm_l": [[0.0, V(0, 0, 0)], [0.3, V(125, 0, 0)], [2.1, V(125, 0, 0)], [2.4, V(0, 0, 0)]],
		&"forearm_r": [[0.0, V(0, 0, 0)], [0.3, V(125, 0, 0)], [2.1, V(125, 0, 0)], [2.4, V(0, 0, 0)]]}
	d[&"cheer"] = {"len": 2.0,
		&"hips_y": [[0.0, 0.0], [0.2, -0.1], [0.45, 0.22], [0.75, 0.0], [1.0, -0.1], [1.25, 0.22], [1.55, 0.0], [2.0, 0.0]],
		&"arm_l": [[0.0, V(0, 0, 0)], [0.25, V(165, 0, 15)], [0.45, V(150, 0, 15)], [0.65, V(170, 0, 15)],
				[1.25, V(150, 0, 15)], [1.55, V(170, 0, 15)], [1.75, V(165, 0, 15)], [2.0, V(0, 0, 0)]],
		&"arm_r": [[0.0, V(0, 0, 0)], [0.25, V(165, 0, -15)], [0.45, V(150, 0, -15)], [0.65, V(170, 0, -15)],
				[1.25, V(150, 0, -15)], [1.55, V(170, 0, -15)], [1.75, V(165, 0, -15)], [2.0, V(0, 0, 0)]],
		&"head": [[0.0, V(0, 0, 0)], [0.25, V(20, 0, 0)], [1.75, V(20, 0, 0)], [2.0, V(0, 0, 0)]],
		&"spine": [[0.0, V(0, 0, 0)], [0.25, V(10, 0, 0)], [1.75, V(10, 0, 0)], [2.0, V(0, 0, 0)]]}
	d[&"facepalm"] = {"len": 2.4,
		&"arm_r": [[0.0, V(0, 0, 0)], [0.4, V(60, 0, 15)], [2.0, V(60, 0, 15)], [2.4, V(0, 0, 0)]],
		&"forearm_r": [[0.0, V(0, 0, 0)], [0.4, V(135, 0, 0)], [2.0, V(135, 0, 0)], [2.4, V(0, 0, 0)]],
		&"spine": [[0.0, V(0, 0, 0)], [0.4, V(-22, 0, 0)], [2.0, V(-22, 0, 0)], [2.4, V(0, 0, 0)]],
		&"head": [[0.0, V(0, 0, 0)], [0.4, V(-35, 0, 0)], [0.8, V(-35, 14, 0)], [1.3, V(-35, -14, 0)], [1.7, V(-35, 0, 0)],
				[2.0, V(-35, 0, 0)], [2.4, V(0, 0, 0)]]}
	d[&"clap"] = {"len": 1.8,
		&"arm_l": _clap(1, 18.0), &"arm_r": _clap(-1, 18.0),
		&"forearm_l": [[0.0, V(0, 0, 0)], [0.25, V(70, 0, 0)], [1.55, V(70, 0, 0)], [1.8, V(0, 0, 0)]],
		&"forearm_r": [[0.0, V(0, 0, 0)], [0.25, V(70, 0, 0)], [1.55, V(70, 0, 0)], [1.8, V(0, 0, 0)]],
		&"head": [[0.0, V(0, 0, 0)], [0.25, V(10, 0, 0)], [1.55, V(10, 0, 0)], [1.8, V(0, 0, 0)]]}
	return d


## Both arms out in front, swinging in and out 4 times; `side` 1 = left arm, -1 = right arm (Z mirrors).
static func _clap(side: int, apart: float) -> Array:
	var keys := [[0.0, V(0, 0, 0)], [0.25, V(50, 0, side * apart)]]
	for i in 4:
		keys.append([0.45 + i * 0.28, V(50, 0, -side * 6.0)])
		keys.append([0.59 + i * 0.28, V(50, 0, side * apart)])
	keys.append([1.8, V(0, 0, 0)])
	return keys


static func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


## One Animation per kind in KINDS, for this skeleton. Every bone gets a track (rest where the emote leaves it) so
## nothing carries over from the previous clip.
static func build(skel: Skeleton3D) -> Dictionary:
	var out := {}
	var defs := _defs()
	for kind in KINDS:
		var def: Dictionary = defs[kind]
		var a := Animation.new()
		a.length = def["len"]
		a.loop_mode = Animation.LOOP_NONE
		for b in BONES:
			var i := skel.find_bone(String(b))
			if i < 0:
				continue
			var rest := skel.get_bone_rest(i)
			var t := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(t, NodePath(PREFIX + String(b)))
			var keys: Array = def.get(b, [[0.0, Vector3.ZERO], [a.length, Vector3.ZERO]])
			for k in keys:
				a.rotation_track_insert_key(t, k[0], rest.basis.get_rotation_quaternion() * Quaternion.from_euler((k[1] as Vector3) * (PI / 180.0)))
			if b == &"hips":
				var p := a.add_track(Animation.TYPE_POSITION_3D)
				a.track_set_path(p, NodePath(PREFIX + "hips"))
				for k in def.get(&"hips_y", [[0.0, 0.0], [a.length, 0.0]]):
					a.position_track_insert_key(p, k[0], rest.origin + Vector3(0, k[1], 0))
		out[kind] = a
	return out
