class_name HeadScaler
extends SkeletonModifier3D
## P5-42 big heads: scales the farmer's own `head` bone. The skinned head (its texture) and the `hat` bone below it
## (cosmetic hats) grow together. A modifier runs after the animation each frame, so the clip cannot reset it.

var factor := 1.0


func _process_modification() -> void:
	var sk := get_skeleton()
	var i := sk.find_bone(&"head") if sk else -1
	if i >= 0:
		sk.set_bone_pose_scale(i, Vector3.ONE * factor)
