class_name DebugView
extends CanvasLayer
## Doc 05 section 19: the debug top-down view. A pure reader, never changes state. Toggle F3
## (`toggle_debug_view`) or `--debug-view`. Host machine by default (it shows secrets); a client needs
## `--debug-view`, and without `--debug-share` (not built) it sees only what its own scene holds:
## players and markers, no creature. Mouse wheel zooms.
## Deviation from section 19 (inference: same information, less code): drawn with 2D canvas calls in
## a corner panel, not an orthographic Camera3D in debug layer 20. Pan and the H radii are not built.
## Creature, sensed positions and AI Director panels use `Creature.debug_state()`, `debug_sensed()` and
## `AiDirector.debug_state()` (groups `creature`, `ai_director`) and show nothing until those exist.

const PANEL := Vector2(380, 440)
const NOISE_FADE_S := 2.0  ## doc 05 section 19: fade in 2 s
const WORLD_HALF := Vector2(64, 75)  ## the farm ground is 128 x 150 m (doc 04)

var _panel: Control
var _zoom := 1.0
var _noise: Array[Dictionary] = []  ## {pos, r, kind, age}
var _tension: Array[float] = []


func _ready() -> void:
	layer = 100
	_panel = Control.new()
	_panel.position = Vector2(8, 8)
	_panel.size = PANEL
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	visible = Game.debug_view
	if Game.is_host():
		NoiseBus.noise_emitted.connect(func(p: Vector3, r: float, k: StringName, _s: int) -> void:
			_noise.append({"pos": p, "r": r, "kind": k, "age": 0.0}))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug_view") and (Game.is_host() or Game.debug_view):
		visible = not visible
	elif visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(_zoom * 1.25, 8.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(_zoom / 1.25, 0.5)


func _process(delta: float) -> void:
	if not visible:
		return
	for n: Dictionary in _noise:
		n.age += delta
	_noise = _noise.filter(func(n: Dictionary) -> bool: return n.age < NOISE_FADE_S)
	var d := _director()
	if not d.is_empty():
		_tension.append(float(d.get("tension", 0.0)))
		if _tension.size() > 240:
			_tension.pop_front()
	_panel.queue_redraw()


func _director() -> Dictionary:
	var n := get_tree().get_first_node_in_group(&"ai_director")
	return n.debug_state() if n and n.has_method(&"debug_state") else {}


## World metres (x, z) to panel pixels; the view centres on the farm, `_zoom` 1 fits the whole ground.
func _px(p: Vector3) -> Vector2:
	var s := minf(PANEL.x / (WORLD_HALF.x * 2.0), PANEL.y / (WORLD_HALF.y * 2.0)) * _zoom
	return PANEL / 2.0 + Vector2(p.x, p.z) * s


func _scale() -> float:
	return minf(PANEL.x / (WORLD_HALF.x * 2.0), PANEL.y / (WORLD_HALF.y * 2.0)) * _zoom


func _draw_panel() -> void:
	var c := _panel
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, PANEL), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(_px(Vector3(-WORLD_HALF.x, 0, -WORLD_HALF.y)), WORLD_HALF * 2.0 * _scale()), Color(1, 1, 1, 0.25), false)
	var tr := get_tree().get_first_node_in_group(&"trap_race")
	var armed: Array = []  # host only: the Creature's own record of the traps it set
	var cr0 := get_tree().get_first_node_in_group(&"creature")
	if Game.is_host() and cr0 and cr0.has_method(&"debug_state"):
		armed = cr0.debug_state().traps.values().filter(func(t: Dictionary) -> bool: return t.armed).map(func(t: Dictionary) -> String: return t.id)
	for m in get_tree().get_nodes_in_group(&"trap_spots"):  # grey = unknown, orange = set (host), red = sprung, green = disarmed
		var tc := Color(0.5, 0.5, 0.5)
		if String(m.name) in armed:
			tc = Color.ORANGE
		elif tr and tr.traps.has(String(m.name)):
			tc = Color.RED if tr.traps[String(m.name)].state == &"sprung" else Color.GREEN
		c.draw_rect(Rect2(_px(m.global_position) - Vector2(3, 3), Vector2(6, 6)), tc)
	for m in get_tree().get_nodes_in_group(&"plot_spots"):
		c.draw_circle(_px(m.global_position), 1.5, Color(0.4, 0.7, 0.3))
	for n: Dictionary in _noise:
		var a: float = 1.0 - n.age / NOISE_FADE_S
		var col := Color.from_hsv(float(hash(n.kind) % 100) / 100.0, 0.8, 1.0, a)
		c.draw_arc(_px(n.pos), n.r * _scale() * (0.3 + 0.7 * n.age / NOISE_FADE_S), 0, TAU, 32, col, 1.5)
	var players := get_tree().current_scene.get_node_or_null("Players") if get_tree().current_scene else null
	for peer in Game.players:
		var body: Node3D = players.player(peer) if players else null
		if body == null:
			continue
		var st: Dictionary = Game.players[peer]
		var col := Color.WHITE
		if bool(st.get("ghost", false)):
			col = Color(0.7, 0.7, 1.0, 0.35)
		elif body.crouching:
			col = Color.YELLOW
		var p := _px(body.global_position)
		c.draw_circle(p, 5, col)
		c.draw_line(p, p + Vector2(-sin(body.yaw), -cos(body.yaw)) * 12, col, 2)
		c.draw_string(font, p + Vector2(7, -5), "%d%s%s" % [peer, " (you)" if peer == Game.local_peer() else "", " bot" if peer < 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	_draw_creature(c, font)
	var d := _director()
	var y := PANEL.y - 12.0
	if not d.is_empty():
		c.draw_string(font, Vector2(6, y - 44), "tension %.0f  %s  next scare %.0fs" % [d.get("tension", 0.0), d.get("phase", ""), d.get("next_scare_s", 0.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		for i in _tension.size():
			c.draw_line(Vector2(6 + i, y), Vector2(6 + i, y - _tension[i] * 0.3), Color.ORANGE)
	c.draw_string(font, Vector2(6, 14), "debug view  zoom %.1f  t=%.0fs  noise %s" % [_zoom, Log.now(), NoiseBus.counts], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


func _draw_creature(c: Control, font: Font) -> void:
	var cr := get_tree().get_first_node_in_group(&"creature")
	if cr == null or not cr.has_method(&"debug_state"):
		return
	var ds: Dictionary = cr.debug_state()
	var true_pos: Dictionary = {}  # peer -> true position, for the sensed-to-true lines
	var players := get_tree().current_scene.get_node_or_null("Players")
	for peer in Game.players:
		var body: Node3D = players.player(peer) if players else null
		if body:
			true_pos[peer] = body.global_position
	if cr.has_method(&"debug_sensed"):
		for s: Dictionary in cr.debug_sensed():
			var sp := _px(s.position)
			c.draw_arc(sp, 5, 0, TAU, 16, Color.RED, 1.0)
			if true_pos.has(s.peer):
				c.draw_line(sp, _px(true_pos[s.peer]), Color(1, 0, 0, 0.5))
			c.draw_string(font, sp + Vector2(6, 10), "%s %.0fs" % [s.get("source_kind", ""), s.get("age_s", 0.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.RED)
	var cp := _px(ds.get("position", Vector3.ZERO))
	c.draw_circle(cp, 7, Color.RED)
	c.draw_string(font, cp + Vector2(9, 4), "%s %s -> %s" % [ds.get("state", ""), ds.get("body", ""), ds.get("target", "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.RED)
