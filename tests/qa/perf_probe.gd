extends Node
## QA fixture (doc 09 section 10): boots the game like Boot does, then samples frame time and
## render counters for a while and prints one `perf_probe` line. Windowed only for render numbers;
## headless draws nothing but still reports the script and physics time (PERF-01).
## Run: godot --path . res://tests/qa/perf_probe.tscn -- --host --phase1 --autowalk [--probe-warm=15 --probe-s=60]
## Fixed spot (doc 07 s10.3 step 1): --probe-pos=x,z --probe-yaw=<degrees, 0 = north, -90 = east>
## --probe-label=<name>. The local player is teleported once after the warm-up and then stands still.

var _warm := 15.0
var _len := 60.0
var _t := 0.0
var _dts: Array[float] = []
var _pos := Vector2.INF
var _yaw := 0.0
var _label := ""
var _placed := false
var _done := false
var _spikes: Array[String] = []
var _player: Node3D
var _cpu: Array[float] = []
var _gpu: Array[float] = []
var _proc: Array[float] = []
var _phys: Array[float] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-warm="):
			_warm = float(a.get_slice("=", 1))
		elif a.begins_with("--probe-s="):
			_len = float(a.get_slice("=", 1))
		elif a.begins_with("--probe-pos="):
			var p := a.get_slice("=", 1).split(",")
			_pos = Vector2(float(p[0]), float(p[1]))
		elif a.begins_with("--probe-yaw="):
			_yaw = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--probe-label="):
			_label = a.get_slice("=", 1)
	if has_meta(&"run"):
		RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)
		return  # the sampling copy under the root
	set_process(false)
	var probe := Node.new()
	probe.set_script(get_script())  # a copy that outlives the scene switch Game does
	probe.set_meta(&"run", true)
	get_tree().root.add_child.call_deferred(probe)
	Game.begin(Game.parse_args(OS.get_cmdline_user_args()))


func _find_local(n: Node) -> Node3D:
	if n is Node3D and "is_local" in n and "yaw" in n and n.is_local:
		return n
	for c in n.get_children():
		var r := _find_local(c)
		if r:
			return r
	return null


func _process(delta: float) -> void:
	_t += delta
	if _pos != Vector2.INF:
		if _player == null or not is_instance_valid(_player):
			_player = _find_local(get_tree().root)
		if _player and _t > _warm - 4.0:
			if not _placed:
				_placed = true
				_player.global_position = Vector3(_pos.x, 0.6, _pos.y)
			_player.yaw = _yaw
			_player.pitch = 0.0
	if _t < _warm:
		return
	if _done:
		return
	if " ".join(OS.get_cmdline_user_args()).contains("--probe-census"):
		_done = true
		_census()
		return
	if delta > 0.033 and _spikes.size() < 6:
		_spikes.append("%.0fs:%.0fms" % [_t - _warm, delta * 1000.0])
	_dts.append(delta)
	var vp := get_tree().root.get_viewport_rid()
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_proc.append(Performance.get_monitor(Performance.TIME_PROCESS))
	_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	if _t < _warm + _len:
		return
	_done = true
	var sum := 0.0
	var worst := 0.0
	var over33 := 0
	for d in _dts:
		sum += d
		worst = maxf(worst, d)
		over33 += 1 if d > 0.033 else 0
	var ri := RenderingServer
	print("perf_probe label=%s frames=%d avg_fps=%.1f avg_ms=%.2f worst_ms=%.1f frames_over_33ms=%d draws=%d prims=%d tex_mb=%.0f vid_mb=%.0f gpu_ms=%.2f cpu_render_ms=%.2f process_max_ms=%.2f physics_max_ms=%.2f nodes=%d adapter=%s size=%s spikes=%s" % [
			_label, _dts.size(), _dts.size() / sum, sum / _dts.size() * 1000.0, worst * 1000.0, over33,
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
			_avg(_gpu), _avg(_cpu), _avg(_proc) * 1000.0, _avg(_phys) * 1000.0,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			ri.get_video_adapter_name(), get_viewport().get_visible_rect().size, ",".join(_spikes)])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-shot="):
			get_viewport().get_texture().get_image().save_png(a.get_slice("=", 1))
	get_tree().quit()


func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


## PERF-01: `--probe-census` replaces the sampling. Counts the nodes that run `_process` /
## `_physics_process`, grouped by script, then switches each of the biggest groups off for 3 s and prints
## how far the process and physics monitors drop. Dev-only: it breaks the game while a group is off.
func _census() -> void:
	var groups := {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var s: Script = n.get_script()
		if s == null or n == self:
			continue
		if n.is_processing() or n.is_physics_processing():
			var k: String = s.resource_path
			if not groups.has(k):
				groups[k] = []
			groups[k].append(n)
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a].size() > groups[b].size())
	for k in keys:
		print("census_group %s nodes=%d" % [k, groups[k].size()])
	var base := await _window()
	await get_tree().create_timer(2.0).timeout
	print("census_base process_max_ms=%.3f physics_max_ms=%.3f" % [base[0], base[1]])
	for k in keys:
		base = await _window()
		var ps: Array = []
		var pp: Array = []
		for n in groups[k]:
			ps.append(n.is_processing())
			pp.append(n.is_physics_processing())
			n.set_process(false)
			n.set_physics_process(false)
		var w := await _window()
		for i in groups[k].size():
			var n: Node = groups[k][i]
			if is_instance_valid(n):
				n.set_process(ps[i])
				n.set_physics_process(pp[i])
		print("census_off %s nodes=%d process_max_ms=%.3f (%+.3f) physics_max_ms=%.3f (%+.3f)" % [k, groups[k].size(), w[0], w[0] - base[0], w[1], w[1] - base[1]])
	get_tree().quit()


func _window() -> Array:
	var p := 0.0
	var f := 0.0
	var n := 0
	var end := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		p += Performance.get_monitor(Performance.TIME_PROCESS)
		f += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		n += 1
	return [p / n * 1000.0, f / n * 1000.0]
