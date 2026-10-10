class_name DevToys
extends Node
## P5-10 (doc 01 "Dev toys", D-044, D-045, D-046): seven hidden joke commands behind the machine-hash gate
## (`DevGate`). No menu shows them; the dev console runs `toy <name>` on the host and only when the gate is open.
## Host: `run` checks the gate, logs `dev_toy` (so `check_logs.py` skips the session) and broadcasts
## `apply_dev_toy` (doc 05 s25). Every peer, the host included, shows the toy from that message.
## Rules (doc 01): a toy never touches the save, coins, debt or deaths, so nothing here calls Farm, Save, Death or
## the generator. Every effect is visual or audio on the peer's own screen, or a body-size / gravity setting on
## a Player node. Only ghosts touch the lights (doc 07 s4.3): no `LightRig` is used, no light energy is animated
## faster than a slow ramp, and a colour change is a slow hue drift. Safe mode (`photosensitive_safe`) hides the
## disco lights and the nuke glow on that peer's screen (doc 01 "Photosensitivity safety").

const TOYS: Array[StringName] = [&"shrink", &"disco", &"nuke", &"low_gravity", &"big_heads", &"confetti", &"chicken"]
## Seconds. Doc 01 gives 60 for shrink and low gravity. The rest are placeholders (inference: doc 01 gives no
## length for big heads, disco or the nuke; 0 means "the rest of the day", ended at dawn). A playtest settles them.
const SECONDS := {&"shrink": 60.0, &"low_gravity": 60.0, &"big_heads": 60.0, &"disco": 45.0, &"nuke": 14.0,
		&"confetti": 0.0, &"chicken": 0.0}
const SHRINK := 0.25  ## doc 01: a quarter size
const BIG_HEAD := 3.0  ## doc 01: three times size
const LOW_GRAVITY := 0.2  ## placeholder
const BALL_Y := 14.0
const NUKE_PUSH_S := 1.2  ## the blast reaches the bodies this long after the glow starts
const NUKE_RAGDOLL_S := 4.0
const NUKE_GLOW_ALPHA := 0.30  ## top of the warm screen tint; reached in 5 s, so at most 0.09 per second
const DISCO_HUE_RATE := 0.4  ## rad/s of the hue drift (a 16 s cycle)
const DISCO_SWEEP := 0.5  ## rad/s the beams sweep round (a 12 s lap)
const OVERLAY_META := &"toy_overlay"
const RATE := 22050
const MUSIC_RATE := 16000

static var _squeak_wav: AudioStreamWAV
static var _kazoo_wav: AudioStreamWAV
static var _music_wav: AudioStreamWAV
static var _rumble_wav: AudioStreamWAV

var _until := {}  ## toy -> seconds left (INF: until dawn)
var _plot_state := {}  ## plot id -> last wire state, to see a ripe plot become empty (a harvest) on every peer
var _t := 0.0
var _rig: Node3D  ## disco: ball and beams
var _beams: Array[SpotLight3D] = []
var _music: AudioStreamPlayer3D
var _overlay: StandardMaterial3D  ## disco: the creature's steady tint
var _glow: ColorRect  ## nuke
var _glow_layer: CanvasLayer
var _nuke_t := 0.0
var _cloud: Node3D
var _cloud_mat: StandardMaterial3D
var _blast := Vector3.ZERO
var _pushed := false


func _ready() -> void:
	Net.apply_received.connect(_on_apply)
	Clock.phase_changed.connect(func(p: StringName) -> void:
		if p == &"dawn":  # "the rest of the day" ends with it
			_end(&"confetti")
			_end(&"chicken"))


func _exit_tree() -> void:
	for toy in _until.keys():
		_end(toy)


# --- host ----------------------------------------------------------------------------------------

## Host: starts toy `toy` for everyone. Returns the reply the dev console prints.
func run(toy: StringName) -> String:
	if not Game.is_host():
		return "host only"
	if not DevGate.unlocked():
		return "? unknown command 'toy' (help)"
	if not toy in TOYS:
		return "? toy %s" % "|".join(TOYS)
	var secs: float = SECONDS[toy]
	var pos: Vector3 = Game.players.get(Game.local_peer(), {}).get("pos", Vector3.ZERO)
	Log.event(&"dev_toy", {"toy": String(toy), "seconds": secs, "player": Game.local_peer()})
	Net.to_peers(&"apply_dev_toy", [toy, secs, pos])
	Net.apply_received.emit(&"dev_toy", [toy, secs, pos])  # the host is its own client
	return "%s on%s" % [toy, " for %.0f s" % secs if secs > 0.0 else " until dawn"]


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	match what:
		&"dev_toy":
			if args[0] == &"squeak":
				_play(_squeak(), args[2], 4.0)
			elif args[0] in TOYS:
				_start(args[0], args[1], args[2])
		&"plot_changed":
			var prev := String(_plot_state.get(args[0], ""))
			_plot_state[args[0]] = String(args[1])
			if _until.has(&"confetti") and prev.begins_with("ripe") and String(args[1]) == "empty":
				_confetti_at(args[0])
		&"hold_done":  # the host's own hands only: hold_done reaches the host for the host's holds
			if _until.has(&"chicken") and Game.is_host():
				var pos: Vector3 = Game.players.get(Game.local_peer(), {}).get("pos", Vector3.ZERO)
				Net.to_peers(&"apply_dev_toy", [&"squeak", 0.0, pos])
				_play(_squeak(), pos, 4.0)


func _start(toy: StringName, secs: float, pos: Vector3) -> void:
	_end(toy)
	_until[toy] = secs if secs > 0.0 else INF
	print("DevToys: %s on (%s)" % [toy, "%.0f s" % secs if secs > 0.0 else "until dawn"])
	match toy:
		&"shrink":
			_each_player(func(p: Node) -> void: p.set_body_scale(SHRINK))
			Squeaky.set_on(true)
		&"low_gravity":
			var me := _player(Game.local_peer())  # each client owns its own movement
			if me:
				me.gravity_scale = LOW_GRAVITY
				me.jump_ok = true
		&"big_heads":
			_each_player(func(p: Node) -> void: p.set_head_scale(BIG_HEAD))
			var cr := _creature()
			if cr:
				var head := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.4
				sp.height = 0.8
				head.mesh = sp
				head.name = "ToyHead"
				head.set_meta(&"toy", true)
				head.scale = Vector3.ONE * BIG_HEAD
				head.position.y = 3.0  # on top of the 2.4 m placeholder body (inference: the glb body is about as tall)
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.08, 0.06, 0.05)
				head.material_override = m
				cr.add_child(head)
		&"disco":
			_start_disco(pos)
		&"nuke":
			_start_nuke(pos)
	# confetti and chicken need nothing here: the flag in _until is all they use


func _end(toy: StringName) -> void:
	if not _until.has(toy):
		return
	_until.erase(toy)
	print("DevToys: %s off" % toy)
	match toy:
		&"shrink":
			_each_player(func(p: Node) -> void: p.set_body_scale(1.0))
			Squeaky.set_on(false)
		&"low_gravity":
			var me := _player(Game.local_peer())
			if me:
				me.gravity_scale = 1.0
				me.jump_ok = false
		&"big_heads":
			_each_player(func(p: Node) -> void: p.set_head_scale(1.0))
			var cr := _creature()
			if cr and cr.has_node(^"ToyHead"):
				cr.get_node(^"ToyHead").queue_free()
		&"disco":
			_each_player(func(p: Node) -> void: p.dance_end())
			_creature_restore()
			for mi in _creature_meshes():
				mi.material_overlay = mi.get_meta(OVERLAY_META, null)
				mi.remove_meta(OVERLAY_META)
			for n in [_rig, _music]:
				if is_instance_valid(n):
					n.queue_free()
			_rig = null
			_music = null
			_beams.clear()
		&"nuke":
			for n in [_glow_layer, _cloud]:
				if is_instance_valid(n):
					n.queue_free()
			_glow = null
			_glow_layer = null
			_cloud = null
			_creature_restore()


func _process(delta: float) -> void:
	if _until.is_empty():
		return
	_t += delta
	for toy in _until.keys():
		_until[toy] -= delta
		if _until[toy] <= 0.0:
			_end(toy)
	var safe := bool(Settings.get_value(&"photosensitive_safe"))
	if _until.has(&"disco"):
		_disco(safe)
	if _until.has(&"nuke"):
		_nuke(safe, delta)


# --- disco ---------------------------------------------------------------------------------------

func _start_disco(pos: Vector3) -> void:
	_rig = (load("res://game/debug/disco_rig.tscn") as PackedScene).instantiate()
	_rig.position = Vector3(pos.x, BALL_Y, pos.z)
	var ball := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 1.5
	sp.height = 3.0
	sp.radial_segments = 14
	sp.rings = 8
	ball.mesh = sp
	var m := StandardMaterial3D.new()
	m.metallic = 1.0
	m.roughness = 0.2
	m.albedo_color = Color(0.75, 0.78, 0.85)
	ball.material_override = m
	_rig.add_child(ball)
	for k in 4:  # four beams (static energy in the scene), 90 degrees apart, tilted outward; the rig turns slowly (D-046: a sweep, never a pulse)
		var holder: Node3D = _rig.get_node("Holder%d" % k)
		holder.rotation.y = k * PI / 2.0
		var s: SpotLight3D = holder.get_node("Beam")
		s.rotation = Vector3(deg_to_rad(-55.0), 0.0, 0.0)
		s.shadow_enabled = false
		_beams.append(s)
	get_parent().add_child(_rig)
	var tw := create_tween()  # the ball drops in from above
	_rig.position.y = BALL_Y + 30.0
	tw.tween_property(_rig, "position:y", BALL_Y, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_music = AudioStreamPlayer3D.new()
	_music.stream = _disco_music()
	_music.bus = &"Music"
	_music.unit_size = 30.0
	_music.max_distance = 200.0
	_music.volume_db = -4.0
	_rig.add_child(_music)
	_music.play()
	_overlay = StandardMaterial3D.new()  # the creature's steady tint: fully visible while it dances (doc 01)
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color.from_hsv(0.5, 0.6, 1.0, 0.55)
	for mi in _creature_meshes():
		mi.set_meta(OVERLAY_META, mi.material_overlay)
		mi.material_overlay = _overlay


func _disco(safe: bool) -> void:
	if _rig == null:
		return
	_rig.rotation.y = _t * DISCO_SWEEP
	for i in _beams.size():
		_beams[i].visible = not safe  # safe mode: no disco lights (doc 01); the ball, music and dance stay
		_beams[i].light_color = Color.from_hsv(fposmod(0.5 + 0.3 * sin(_t * DISCO_HUE_RATE + i * 1.5), 1.0), 0.8, 1.0)
	_overlay.albedo_color = Color.from_hsv(fposmod(0.5 + 0.3 * sin(_t * DISCO_HUE_RATE), 1.0), 0.6, 1.0, 0.55)
	_each_player(func(p: Node) -> void: p.dance(_t))
	for part in _creature_parts():
		_stash(part)
		var base: Vector3 = part.get_meta(&"toy_pos")
		part.position = Vector3(base.x, base.y + 0.25 * absf(sin(_t * PI * 1.5)), base.z)
		part.rotation.y = _t * 2.0


# --- nuke ----------------------------------------------------------------------------------------

func _start_nuke(pos: Vector3) -> void:
	_blast = pos
	var blockers := get_parent().get_node_or_null("World/CornBlockers")
	if blockers and blockers.get_child_count() > 0:  # over the corn: the middle of its blocks
		_blast = Vector3.ZERO
		for c in blockers.get_children():
			_blast += (c as Node3D).global_position
		_blast /= blockers.get_child_count()
	_blast.y = 0.0
	_pushed = false
	_cloud = Node3D.new()
	_cloud.position = _blast
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat.albedo_color = Color(0.3, 0.18, 0.12, 0.9)
	_cloud_mat.emission_enabled = true
	_cloud_mat.emission = Color(1.0, 0.5, 0.15)  # steady: no energy change
	_cloud_mat.emission_energy_multiplier = 0.6
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 7.0
	cyl.height = 40.0
	stem.mesh = cyl
	stem.position.y = 20.0
	stem.material_override = _cloud_mat
	_cloud.add_child(stem)
	var cap := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 16.0
	sp.height = 32.0
	cap.mesh = sp
	cap.scale = Vector3(1.0, 0.6, 1.0)
	cap.position.y = 44.0
	cap.material_override = _cloud_mat
	_cloud.add_child(cap)
	_cloud.scale = Vector3.ONE * 0.05
	get_parent().add_child(_cloud)
	var tw := create_tween()
	tw.tween_property(_cloud, "scale", Vector3.ONE, 6.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var layer := CanvasLayer.new()  # under the dev console (layer 100)
	layer.layer = 90
	_glow = ColorRect.new()
	_glow.color = Color(1.0, 0.6, 0.25, 0.0)  # warm orange: never white, never red
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_glow)
	add_child(layer)
	_glow_layer = layer
	_play(_rumble(), _blast, 5.0, 20.0)
	_nuke_t = 0.0


func _nuke(safe: bool, delta: float) -> void:
	_nuke_t += delta
	# One slow bump: up over 5 s, holding, down over 6 s. The steepest part moves 0.09 alpha per second (D-046).
	var k := smoothstep(0.0, 5.0, _nuke_t) * (1.0 - smoothstep(8.0, 14.0, _nuke_t))
	if is_instance_valid(_glow):
		_glow.color.a = NUKE_GLOW_ALPHA * k
		_glow.visible = not safe  # safe mode: no nuke glow (doc 01)
	if _cloud_mat:
		_cloud_mat.albedo_color.a = 0.9 * (1.0 - smoothstep(10.0, 14.0, _nuke_t))
	if not _pushed and _nuke_t >= NUKE_PUSH_S:
		_pushed = true
		_each_player(func(p: Node) -> void: p.ragdoll(_outward(p.global_position), NUKE_RAGDOLL_S))
		var cr := _creature()
		if cr:
			var out := _outward(cr.global_position)
			var local := cr.global_transform.basis.inverse() * out
			for part in _creature_parts():
				_stash(part)
				var tw := create_tween()
				tw.tween_method(_creature_pose.bind(part, local), 0.0, 1.0, NUKE_RAGDOLL_S)
				tw.tween_callback(_creature_restore)


func _creature_pose(k: float, part: Node3D, local: Vector3) -> void:
	if not is_instance_valid(part) or not part.has_meta(&"toy_pos"):
		return
	var base: Vector3 = part.get_meta(&"toy_pos")
	var arc := sin(k * PI)
	part.position = base + Vector3(local.x * 6.0 * arc, 2.5 * arc, local.z * 6.0 * arc)
	part.rotation.x = k * TAU * 2.0


## Flat direction from the blast to `at` (a random one when they coincide).
func _outward(at: Vector3) -> Vector3:
	var d := Vector3(at.x - _blast.x, 0.0, at.z - _blast.z)
	return d.normalized() if d.length() > 0.1 else Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)


# --- confetti ------------------------------------------------------------------------------------

func _confetti_at(plot_id: String) -> void:
	var farm := get_tree().get_first_node_in_group(&"farm")
	var plot: Node3D = farm.targets.get(plot_id) if farm else null
	if plot == null:
		return
	var at := plot.global_position + Vector3(0, 0.8, 0)
	var c := CPUParticles3D.new()
	c.one_shot = true
	c.emitting = true
	c.amount = 40
	c.lifetime = 1.8
	c.explosiveness = 1.0
	c.direction = Vector3.UP
	c.spread = 55.0
	c.initial_velocity_min = 2.5
	c.initial_velocity_max = 5.0
	c.gravity = Vector3(0, -4.0, 0)
	c.angular_velocity_max = 360.0
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	c.mesh = q
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
	g.colors = PackedColorArray([Color("ff4fa3"), Color("ffd23f"), Color("3fd2ff"), Color("7dff6a"), Color("b07bff")])
	c.color_initial_ramp = g
	get_parent().add_child(c)
	c.global_position = at
	get_tree().create_timer(c.lifetime + 0.5).timeout.connect(c.queue_free)
	_play(_kazoo(), at, 6.0)


# --- helpers -------------------------------------------------------------------------------------

func _player(peer: int) -> Node:
	var pl := get_parent().get_node_or_null("Players")
	return pl.player(peer) if pl else null


func _each_player(f: Callable) -> void:
	for peer in Game.players:
		var p := _player(peer)
		if p:
			f.call(p)


func _creature() -> Node3D:
	return get_parent().get_node_or_null("Creature") as Node3D


## The creature's body nodes: its direct visual children (meshes, or a plain Node3D such as a glb
## root), never sensors, emitters or collision, and not the toy's own.
func _creature_parts() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var cr := _creature()
	if cr:
		for c in cr.get_children():
			if (c is VisualInstance3D or c.get_class() == "Node3D") and not c.has_meta(&"toy"):
				out.append(c)
	return out


func _creature_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var cr := _creature()
	if cr:
		for mi in cr.find_children("*", "MeshInstance3D", true, false):
			if not mi.has_meta(&"toy"):
				out.append(mi)
	return out


## Remembers a creature part's own pose the first time a toy moves it.
func _stash(part: Node3D) -> void:
	if not part.has_meta(&"toy_pos"):
		part.set_meta(&"toy_pos", part.position)
		part.set_meta(&"toy_rot", part.rotation)


## Puts the creature's parts back, unless the disco is still moving them.
func _creature_restore() -> void:
	if _until.has(&"disco"):
		return
	for part in _creature_parts():
		if part.has_meta(&"toy_pos"):
			part.position = part.get_meta(&"toy_pos")
			part.rotation = part.get_meta(&"toy_rot")
			part.remove_meta(&"toy_pos")
			part.remove_meta(&"toy_rot")


## One-shot sound at `at` on the SFX bus.
func _play(stream: AudioStream, at: Vector3, unit: float, max_d: float = 60.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"SFX"
	p.unit_size = unit
	p.max_distance = max_d * 4.0
	p.finished.connect(p.queue_free)
	get_parent().add_child(p)
	p.global_position = at
	p.play()


# --- sounds (generated, no assets: placeholders for the Audio Designer) -----------------------------

static func _wav(f: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var d := PackedByteArray()
	d.resize(f.size() * 2)
	for i in f.size():
		d.encode_s16(i * 2, int(clampf(f[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = f.size()
	return w


## A rubber chicken: a buzzy tone that bends up and back down, with a rough 40 Hz wobble.
static func _squeak() -> AudioStreamWAV:
	if _squeak_wav:
		return _squeak_wav
	var n := int(RATE * 0.38)
	var f := PackedFloat32Array()
	f.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += TAU * (600.0 + 1300.0 * sin(PI * t)) / RATE
		var rough := 0.6 + 0.4 * signf(sin(TAU * 40.0 * i / RATE))
		var env := minf(t / 0.03, 1.0) * minf((1.0 - t) / 0.25, 1.0)
		f[i] = 0.5 * env * rough * (sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph))
	_squeak_wav = _wav(f, RATE)
	return _squeak_wav


## A kazoo: two clipped, nasal notes with vibrato.
static func _kazoo() -> AudioStreamWAV:
	if _kazoo_wav:
		return _kazoo_wav
	var n := int(RATE * 0.7)
	var f := PackedFloat32Array()
	f.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var hz := (440.0 if t < 0.3 else 587.0) * (1.0 + 0.015 * sin(TAU * 6.0 * t))
		ph += TAU * hz / RATE
		var env := minf(t / 0.02, 1.0) * minf((0.7 - t) / 0.15, 1.0)
		f[i] = 0.4 * env * (clampf(3.0 * sin(ph), -1.0, 1.0) + 0.4 * sin(2.0 * ph) * sin(TAU * 90.0 * t))
	_kazoo_wav = _wav(f, RATE)
	return _kazoo_wav


## Disco music: 8 s loop at 120 bpm: kick on each beat, off-beat hats, a bass line and a rising arpeggio.
static func _disco_music() -> AudioStreamWAV:
	if _music_wav:
		return _music_wav
	var beat := MUSIC_RATE / 2  # samples per beat at 120 bpm
	var n := beat * 16
	var f := PackedFloat32Array()
	f.resize(n)
	var bass := [55.0, 55.0, 82.4, 55.0, 65.4, 65.4, 98.0, 65.4]
	var arp := [220.0, 261.6, 329.6, 392.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5110
	var prev_noise := 0.0
	for i in n:
		var b := i / beat
		var in_beat := float(i % beat) / MUSIC_RATE  # seconds since the beat
		var kick := sin(TAU * (40.0 * in_beat + 1.2 * (1.0 - exp(-25.0 * in_beat)))) * exp(-9.0 * in_beat)  # 70 Hz falling to 40 Hz
		var off := fmod(in_beat + 0.25, 0.5)  # off-beat hat every half beat after the kick
		var noise := rng.randf_range(-1.0, 1.0)
		var hat := (noise - prev_noise) * exp(-60.0 * off) * 0.5
		prev_noise = noise
		var bt := fmod(in_beat, 0.5)
		var bz: float = bass[b % bass.size()]
		var bs := signf(sin(TAU * bz * i / MUSIC_RATE)) * 0.25 * exp(-4.0 * bt)
		var step := (i / (beat / 2)) % arp.size()  # eighth notes
		var at := float(i % (beat / 2)) / MUSIC_RATE
		var az: float = arp[step] * (2.0 if (b / 4) % 2 == 1 else 1.0)
		var ar := sin(TAU * az * at) * 0.18 * exp(-6.0 * at)
		f[i] = 0.7 * (0.8 * kick + hat + bs + ar)
	_music_wav = _wav(f, MUSIC_RATE, true)
	return _music_wav


## A low rumble for the nuke: slow low-passed noise that swells and dies.
static func _rumble() -> AudioStreamWAV:
	if _rumble_wav:
		return _rumble_wav
	var rate := 11025
	var n := rate * 6
	var f := PackedFloat32Array()
	f.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1945
	var y := 0.0
	for i in n:
		y += 0.04 * (rng.randf_range(-1.0, 1.0) - y)
		var t := float(i) / n
		f[i] = 6.0 * y * smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.5, 1.0, t))
	_rumble_wav = _wav(f, rate)
	return _rumble_wav
