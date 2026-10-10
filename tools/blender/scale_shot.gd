extends SceneTree
# P4-40 scale check: new models beside a 1.8 m capsule on a ground plane, saved to logs/renders/p4_40/after/scale_lineup.png.
#   godot --path . --audio-driver Dummy --script tools/blender/scale_shot.gd

const OUT := "res://logs/renders/p4_40/after/scale_lineup.png"
const ROW := [
	["char_farmer", -3.0], ["animal_cow", -1.2], ["animal_pig", 0.6], ["animal_chicken", 1.6], ["prop_cart", 3.4],
]

func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.55, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root3d.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 10)
	ground.mesh = pm
	root3d.add_child(ground)
	for e in ROW:
		var scene: PackedScene = load("res://assets/models/%s.glb" % e[0])
		var n: Node3D = scene.instantiate()
		n.position = Vector3(e[1], 0, 0)
		n.rotation_degrees.y = 180.0  # glb front is -Z; turn to face the camera at +Z
		root3d.add_child(n)
	var cap := MeshInstance3D.new()  # 1.8 m reference capsule
	var cm := CapsuleMesh.new()
	cm.height = 1.8
	cm.radius = 0.3
	cap.mesh = cm
	cap.position = Vector3(-4.2, 0.9, 0)
	root3d.add_child(cap)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 9.0), Vector3(0, 1.0, 0))
	cam.current = true
	get_root().size = Vector2i(1280, 540)
	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	quit()
