extends Node
## QA fixture (doc 09 section 10): boots the game like Boot does, then samples frame time and
## render counters for a while and prints one `perf_probe` line. Windowed only; headless draws nothing.
## Run: godot --path . res://tests/qa/perf_probe.tscn -- --host --phase1 --autowalk [--probe-warm=15 --probe-s=60]

var _warm := 15.0
var _len := 60.0
var _t := 0.0
var _dts: Array[float] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-warm="):
			_warm = float(a.get_slice("=", 1))
		elif a.begins_with("--probe-s="):
			_len = float(a.get_slice("=", 1))
	if has_meta(&"run"):
		return  # the sampling copy under the root
	set_process(false)
	var probe := Node.new()
	probe.set_script(get_script())  # a copy that outlives the scene switch Game does
	probe.set_meta(&"run", true)
	get_tree().root.add_child.call_deferred(probe)
	Game.begin(Game.parse_args(OS.get_cmdline_user_args()))


func _process(delta: float) -> void:
	_t += delta
	if _t < _warm:
		return
	_dts.append(delta)
	if _t < _warm + _len:
		return
	var sum := 0.0
	var worst := 0.0
	var over33 := 0
	for d in _dts:
		sum += d
		worst = maxf(worst, d)
		over33 += 1 if d > 0.033 else 0
	var ri := RenderingServer
	print("perf_probe frames=%d avg_fps=%.1f worst_ms=%.1f frames_over_33ms=%d draws=%d prims=%d tex_mb=%.0f vid_mb=%.0f adapter=%s size=%s" % [
			_dts.size(), _dts.size() / sum, worst * 1000.0, over33,
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
			ri.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
			ri.get_video_adapter_name(), get_viewport().get_visible_rect().size])
	get_tree().quit()
