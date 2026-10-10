class_name IntroCard
extends CanvasLayer
## P5-67 (replaces the P5-34 text card; doc 01 pitch and Core Loop, doc 11 s1, s5, s6): a 26 s in-engine fly-through before the
## first day of a new season, told by showing: the BRENN FARM sign and the bank notice at the gate (P5-48), the yard and the
## plots, the Prize Pumpkin patch, then a shape glimpsed in the western corn. The only text is the game title at the end
## (no captions, no voice). Local to each peer, so nothing is synced; shown once per new save (never for a loaded season or a
## headless run). Skip with a key or a click. Debug user arg: --no-intro. Like the old card it only turns the local game keys
## off (`Game.console_open`); the host clock keeps running, so every peer loses the same seconds.
## Shot positions are farm.tscn coordinates (gate 105,-5; Prize Pumpkin -47,33; west corn ring -77.5,5): inference from the
## scene, settled by the screenshots in production/handoffs/P5-67/.

const TITLE := "FARMER'S DELIGHT"
const END_S := 26.0
## [time s, camera position, look-at]; the camera moves in a straight line between keys and dips to black at each cut.
const KEYS := [
	[0.0, Vector3(88, 1.7, -5), Vector3(110, 3.6, -5)], [6.0, Vector3(97, 1.8, -5), Vector3(110, 3.9, -5)],  # sign and notice
	[6.0, Vector3(82, 5.0, -14), Vector3(30, 2.0, -6)], [12.0, Vector3(40, 4.0, -8), Vector3(-5, 2.5, 0)],  # yard and plots
	[12.0, Vector3(-33, 2.4, 25), Vector3(-47, 0.8, 33)], [17.0, Vector3(-41, 1.8, 29.5), Vector3(-47, 0.7, 33)],  # Prize Pumpkin
	[17.0, Vector3(-48, 1.7, 14), Vector3(-72, 1.8, 5)], [22.0, Vector3(-54, 1.7, 11), Vector3(-72, 1.8, 5)],  # the corn
]
const CUTS := [6.0, 12.0, 17.0]
const GLIMPSE := [19.6, 20.5]  ## the shape stands in the corn edge between these times
const GLIMPSE_AT := Vector3(-66.0, 1.3, 5.0)

var _t := 0.0
var _ending := -1.0  ## seconds into the fade-out, or -1 while playing
var _cam: Camera3D
var _prev: Camera3D
var _hud: CanvasLayer
var _shape: MeshInstance3D
var _black: ColorRect
var _title: Label
var _cues := [[1.2, &"sfx_crow_caw", Vector3(112, 7, -5)], [12.6, &"sfx_crow_caw", Vector3(-50, 6, 30)],
		[GLIMPSE[0], &"cre_corn_part", GLIMPSE_AT], [GLIMPSE[0], &"cre_presence_swell", Vector3.ZERO]]


static func wanted() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-intro") \
		and Save.pending.is_empty() and Clock.day == 1 and Clock.phase == &"day" and Game.season_no == 1 \
		and Clock.t_phase < 10.0  # a rejoiner gets the host's clock before Main loads (Net._admit): no film mid-season
	# ponytail: a rejoin in the first 10 s of day 1 still sees it; a client-side "rejoined" flag in Game if that matters


## Camera pose at time `t`: [position, look-at], from the last key at or before `t` and the next one of the same shot.
static func pose(t: float) -> Array:
	var i := 0
	for k in KEYS.size():
		if float(KEYS[k][0]) <= t:
			i = k
	var a: Array = KEYS[i]
	var b: Array = KEYS[mini(i + 1, KEYS.size() - 1)]
	var k := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
	return [(a[1] as Vector3).lerp(b[1], k), (a[2] as Vector3).lerp(b[2], k)]


## Black overlay opacity at time `t`: dips at the cuts, closes before the title, opens after it.
static func black(t: float) -> float:
	var a := 0.0
	for c: float in CUTS:
		a = maxf(a, 1.0 - absf(t - c) / 0.4)
	return clampf(maxf(a, clampf(t - 22.0, 0.0, 1.0)), 0.0, 1.0)


func _ready() -> void:
	if not wanted():
		queue_free()
		return
	layer = 80  # over the HUD (10), under the REC light (90, doc 06 s11: never covered), the Dawn Report (110) and the pause menu (120)
	_prev = get_viewport().get_camera_3d()
	_hud = _prev.get_parent().get_node_or_null(^"Hud") as CanvasLayer if _prev != null else null
	if _hud != null:
		_hud.visible = false  # no HUD text or minimap over the film
	_cam = Camera3D.new()
	_cam.fov = 70.0
	get_parent().add_child.call_deferred(_cam)  # a 3D node cannot sit under this CanvasLayer
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_title = Label.new()
	_title.text = TITLE
	_title.add_theme_font_size_override(&"font_size", 56)
	_title.add_theme_color_override(&"font_color", Color(0.95, 0.8, 0.4))
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	add_child(_title)
	_shape = MeshInstance3D.new()  # a tall dark shape, unlit, in the corn edge; gone as fast as it came
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 2.6
	_shape.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.015, 0.015)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shape.material_override = m
	_shape.visible = false
	get_parent().add_child.call_deferred(_shape)
	Game.console_open = true  # game keys off while the intro plays (as the pause menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Log.event(&"intro_shown", {})
	_frame(0.0)


func _process(delta: float) -> void:
	if _ending >= 0.0:
		_ending += delta
		_black.color.a = maxf(_black.color.a - delta / 0.6, 0.0)
		if _ending >= 0.6:
			queue_free()
		return
	_t += delta
	if _t >= END_S:
		_finish(false)
		return
	_frame(_t)


func _frame(t: float) -> void:
	if _cam == null or not _cam.is_inside_tree():
		return
	var p := pose(t)
	_cam.look_at_from_position(p[0], p[1])
	if not _cam.current:
		_cam.make_current()
	_black.color.a = black(t)
	_title.modulate.a = clampf(minf(t - 23.0, END_S - 0.4 - t), 0.0, 1.0)
	_shape.global_position = GLIMPSE_AT
	_shape.visible = t >= GLIMPSE[0] and t <= GLIMPSE[1]
	while not _cues.is_empty() and t >= float(_cues[0][0]):
		var c: Array = _cues.pop_front()
		if (c[2] as Vector3) == Vector3.ZERO:
			Soundscape.play_2d(c[1], -6.0)
		else:
			Soundscape.play_3d(c[1], c[2])


## Hand the camera and the keys back. The fade-out then runs on top of the player's own view.
func _finish(skipped: bool) -> void:
	Game.console_open = false
	if not Game.in_lobby:
		Game.capture_mouse()
	if is_instance_valid(_hud):
		_hud.visible = true
	if is_instance_valid(_prev):
		_prev.make_current()
	if _cam != null:
		_cam.queue_free()
		_shape.queue_free()
	_title.modulate.a = 0.0
	_ending = 0.0
	Log.event(&"intro_skipped" if skipped else &"intro_done", {"t": snappedf(_t, 0.1)})


func _input(event: InputEvent) -> void:
	if _ending >= 0.0 or _black == null:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_finish(true)
