extends Node3D
## Standalone viewer for the full farm (P2-02): loads farm.tscn with the Technical Artist's WorldLook corn and
## prints render stats for the doc 07 s10.2 corn budget. No players, no network; Main still loads
## farm_phase1.tscn until Gameplay adds a flag (Q-053).
##   "$GODOT" --path . res://game/world/farm_view.tscn -- --view-cam=x,y,z,yaw,pitch [--view-frames=90]
## Prints one `farm_view_stats` line: stalks in total, within the 30 m MultiMesh range, and in view (in the
## frustum and within range), plus draws, triangles, frame ms and adapter.

var _cam: Camera3D
var _frames := 0
var _target := 90
var _ms := 0.0


func _ready() -> void:
	var world := (load("res://game/world/farm.tscn") as PackedScene).instantiate()
	world.name = "World"
	add_child(world)
	var look := Node.new()
	look.set_script(load("res://game/render/world_look.gd"))
	look.name = "Look"
	add_child(look)
	var v := Vector3(30, 1.65, 52)
	var yaw := 180.0
	var pitch := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view-cam="):
			var f := a.trim_prefix("--view-cam=").split(",")
			v = Vector3(float(f[0]), float(f[1]), float(f[2]))
			yaw = float(f[3]) if f.size() > 3 else 0.0
			pitch = float(f[4]) if f.size() > 4 else 0.0
		elif a.begins_with("--view-frames="):
			_target = int(a.trim_prefix("--view-frames="))
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.global_position = v
	_cam.rotation_degrees = Vector3(pitch, yaw, 0.0)
	_cam.make_current()


func _process(delta: float) -> void:
	_frames += 1
	if _frames > _target * 0.5:
		_ms += delta * 1000.0
	if _frames < _target:
		return
	var total := 0
	var near := 0
	var seen := 0
	var corn: Node = get_node("Look").get("corn")
	for c in corn.get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null:
			continue
		var mm := mmi.multimesh
		total += mm.instance_count
		for i in mm.instance_count:
			var p := mm.get_instance_transform(i).origin
			if p.distance_to(_cam.global_position) <= CornField.NEAR_M:
				near += 1
				if _cam.is_position_in_frustum(p + Vector3.UP * 1.2):
					seen += 1
	print("farm_view_stats cam=%s total=%d in_range=%d in_view=%d draws=%d prims=%d ms=%.2f adapter=%s" % [
			_cam.global_position, total, near, seen,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			_ms / (_target - _target * 0.5), RenderingServer.get_video_adapter_name()])
	get_tree().quit()
