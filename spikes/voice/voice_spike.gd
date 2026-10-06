extends Node3D
## PP-02 voice spike: proves doc 06 sections 2 to 4 and 8 (ENet star, UPnP and host screen, join
## codes and fallbacks, Opus proximity voice relayed by the host). Throwaway (DECISIONS D-004):
## nothing in game/ may import it.
##
## Run: "$GODOT" --path . res://spikes/voice/voice_spike.tscn [-- args]. Arguments (after --):
##   --host                 host at once (no menu)
##   --join <code|ip[:port]>  join at once; a join code or a raw IPv4/IPv6 address
##   --voice-wav <path>     feed voice from a WAV instead of the mic
##   --port <n>             host port (default 45120, doc 06 section 2)
##   --no-upnp              skip UPnP (repeated local tests; the host screen says so)
##   --name <text>          display name
##   --ptt                  start in push-to-talk mode
##   --walk                 walk a circle automatically (moving-source tests)
##   --run-seconds <n>      log final stats and quit cleanly after n seconds
##   --screenshot <path>    save a PNG of the window after --screenshot-at seconds (default 10)
##   --enet-throttle        keep ENet's default RTT throttle (comparison runs; see _pin_throttle)
##   --stall-at <s>         block the main thread 300 ms once at s seconds (hitch test)
##   --mute-output          mute Master (automated windowed runs on a shared machine)
##   --net-sim-loss <0..1>  drop that share of this peer's outgoing voice frames (doc 06 section 14)
##   --denoise off|speex|rnnoise   default rnnoise (doc 06 "Encode"), the same for mic and WAV

const JoinCode := preload("res://spikes/voice/join_code.gd")
const SpikeLog := preload("res://spikes/voice/spike_log.gd")
const SpikeUpnp := preload("res://spikes/voice/spike_upnp.gd")
const SpikeVoice := preload("res://spikes/voice/spike_voice.gd")

# Doc 06 section 2: channels. 0 reliable gameplay, 1 unreliable ordered movement, 2 unreliable
# voice, 3 reliable bulk (unused by the spike, created so both ends agree on the count).
const CHANNELS := 4
const CH_MOVE := 1
const CH_VOICE := 2
const MAX_CLIENTS := 4  # doc 06 section 2: one more than the 3 allowed, to say "the farm is full"
const MAX_PLAYERS := 4  # doc 01 "Format": 2 to 4
const CONNECT_TIMEOUT_S := 10.0
const MOVE_HZ := 20.0  # doc 06 section 6 (placeholder)
const STATS_EVERY_S := 10.0  # doc 06 section 14
const WALK_SPEED := 4.0  # m/s (placeholder; doc 02 owns real speeds)
const TURN_SPEED := 2.2  # rad/s
const PKT_MOVE := 0x10
const PKT_MOVE_RELAY := 0x11
const PROTOCOL := 1
const CAPSULE_COLOURS: Array[Color] = [Color(0.85, 0.3, 0.25), Color(0.25, 0.55, 0.9),
		Color(0.35, 0.75, 0.35), Color(0.9, 0.75, 0.25)]

var slog := SpikeLog.new()
var voice: SpikeVoice
var upnp: SpikeUpnp
var args := {}
var is_host := false
var in_session := false
var port := JoinCode.DEFAULT_PORT
var my_name := "Farmhand"
var session_id := ""

# Roster, host-authoritative: peer_id -> {"slot": int, "name": String}
var roster: Dictionary = {}
var capsules: Dictionary = {}  # peer_id -> Node3D
var _leaving_peers: Dictionary = {}  # peer_id -> true once they said they're quitting
var _host_volume: Dictionary = {}  # peer_id -> loudest volume byte since last 100 ms (host only)
var _host_heard: Dictionary = {}  # peer_id -> last reported volume (HUD only, never logged)
var _host_heard_at := 0.0

var _connect_started := 0
var _connect_via := ""
var _connect_target := ""
var _move_accum := 0.0
var _stats_accum := 0.0
var _run_seconds := -1.0
var _elapsed := 0.0
var _walk := false
var _walk_t := 0.0
var _quitting := false
var _upnp_result: Dictionary = {}

# Scene
var me: Node3D
var cam_pivot: Node3D
var listener: AudioListener3D

# UI
var ui: CanvasLayer
var menu: Control
var host_panel: Control
var hud: Label
var card: Label
var join_code_edit: LineEdit
var join_ip_edit: LineEdit
var join_status: Label
var upnp_line: Label
var host_details: RichTextLabel
var public_edit: LineEdit
var public_code: Label
var players_label: Label


func _init() -> void:
	# Doc 06 section 8 "Capture": audio/driver/enable_input. Set at runtime so the spike needs no
	# project.godot change (Q-006 asks Gameplay for the real entry). Must happen before any
	# AudioStreamMicrophone plays; verified on 4.7.2 (without it Godot warns and no frames arrive).
	ProjectSettings.set_setting("audio/driver/enable_input", true)


func _ready() -> void:
	Engine.max_fps = 60  # headless runs uncapped otherwise
	args = _parse_args(OS.get_cmdline_user_args())
	port = int(args.get("port", JoinCode.DEFAULT_PORT))
	my_name = str(args.get("name", "Farmhand %d" % (randi() % 90 + 10)))
	_walk = args.has("walk")
	if args.has("mute-output"):
		AudioServer.set_bus_mute(0, true)  # Master; capture taps sit upstream, so stats still work
	_trace = args.has("trace-voice")
	_sim_loss = clampf(float(args.get("net-sim-loss", 0.0)), 0.0, 1.0)
	_run_seconds = float(args.get("run-seconds", -1.0))
	_build_world()
	_build_ui()

	voice = SpikeVoice.new()
	voice.name = "Voice"
	add_child(voice)
	voice.frame_ready.connect(_on_local_voice_frame)
	if args.has("ptt"):
		voice.mic_mode = SpikeVoice.MicMode.PUSH_TO_TALK
	var wav := str(args.get("voice-wav", ""))
	var denoise_arg := str(args.get("denoise", "rnnoise"))
	var denoise: int = {"off": TwovoipOpusEncoder.DENOISER_DISABLED,
			"speex": TwovoipOpusEncoder.DENOISER_SPEEX,
			"rnnoise": TwovoipOpusEncoder.DENOISER_RNNOISE}.get(denoise_arg,
			TwovoipOpusEncoder.DENOISER_RNNOISE)
	var err := voice.start_capture(wav, denoise)
	if err != "":
		push_warning("voice spike: " + err)
		_set_card(err)

	var mp := multiplayer as SceneMultiplayer
	mp.server_relay = false  # CONTRACTS section 7 (D-010)
	mp.peer_packet.connect(_on_peer_packet)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	get_tree().set_auto_accept_quit(false)

	if args.has("host"):
		_host()
	elif args.has("join"):
		_join_from_text(str(args["join"]))


func _parse_args(list: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < list.size():
		var a := list[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			var val: Variant = true
			if "=" in key:
				val = key.get_slice("=", 1)
				key = key.get_slice("=", 0)
			elif i + 1 < list.size() and not list[i + 1].begins_with("--"):
				val = list[i + 1]
				i += 1
			out[key] = val
		i += 1
	return out


# --- World --------------------------------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.68, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.5, 0.27)
	ground.material_override = gm
	add_child(ground)
	# Fence posts every 10 m so distance and direction are visible.
	for x in range(-50, 51, 10):
		for z in range(-50, 51, 10):
			var post := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.2, 1.0, 0.2)
			post.mesh = box
			post.position = Vector3(x, 0.5, z)
			add_child(post)


func _make_capsule(peer_id: int, slot: int, label: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Player_%d" % peer_id
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8  # CONTRACTS section 4: farmer height
	body.mesh = cap
	body.position.y = 0.9
	var m := StandardMaterial3D.new()
	m.albedo_color = CAPSULE_COLOURS[slot % CAPSULE_COLOURS.size()]
	body.material_override = m
	root.add_child(body)
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.15, 0.15, 0.3)
	nose.mesh = nb
	nose.position = Vector3(0, 1.55, -0.4)  # faces -Z (CONTRACTS section 4)
	root.add_child(nose)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = label
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 2.2
	tag.font_size = 48
	root.add_child(tag)
	add_child(root)
	return root


func _spawn_point(slot: int) -> Vector3:
	return Vector3((slot % 2) * 4.0 - 2.0, 0, (slot / 2) * 4.0 - 2.0)


func _spawn_me(slot: int) -> void:
	me = _make_capsule(multiplayer.get_unique_id(), slot, my_name + " (you)")
	me.position = _spawn_point(slot)
	cam_pivot = Node3D.new()
	me.add_child(cam_pivot)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3.2, 5.5)
	cam.rotation_degrees.x = -18
	cam_pivot.add_child(cam)
	cam.current = true
	# The ears are on the farmer's head, not on the third-person camera.
	listener = AudioListener3D.new()
	listener.position = Vector3(0, 1.65, 0)
	me.add_child(listener)
	listener.make_current()


func _ensure_capsule(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id() or capsules.has(peer_id) or not roster.has(peer_id):
		return
	var info: Dictionary = roster[peer_id]
	var c := _make_capsule(peer_id, int(info["slot"]), str(info["name"]))
	c.position = _spawn_point(int(info["slot"]))
	capsules[peer_id] = c
	voice.add_speaker(peer_id, c)


func _drop_capsule(peer_id: int) -> void:
	if capsules.has(peer_id):
		voice.remove_speaker(peer_id)
		capsules[peer_id].queue_free()
		capsules.erase(peer_id)


# --- Per-frame ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_elapsed += delta
	_maybe_screenshot()
	if args.has("stall-at") and not _stalled and _elapsed >= float(args["stall-at"]):
		_stalled = true
		OS.delay_msec(300)  # test hook: a deliberate main-thread hitch
	if _run_seconds > 0.0 and _elapsed >= _run_seconds and not _quitting:
		_quit()
		return
	if _trace and in_session and Engine.get_process_frames() % 30 == 0:
		var e := _enet()
		for id: int in roster:
			var pp := e.get_peer(id) if e and id != multiplayer.get_unique_id() and (is_host or id == 1) else null
			if pp:
				print("TRACE throttle to %d %.3f thr %d lim %d acc %d dec %d rtt %d var %d" % [id, slog.now(), pp.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE), pp.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT), pp.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_ACCELERATION), pp.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION), pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME), pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE)])
	if in_session and me:
		_move_me(delta)
		_move_accum += delta
		if _move_accum >= 1.0 / MOVE_HZ:
			_move_accum = 0.0
			_send_move()
		_stats_accum += delta
		if _stats_accum >= STATS_EVERY_S:
			_stats_accum = 0.0
			_log_stats()
		if is_host:
			_host_hearing_tick()
	_update_hud()


func _move_me(delta: float) -> void:
	var dir := Vector3.ZERO
	var turn := 0.0
	if _walk:
		_walk_t += delta
		dir = Vector3(0, 0, -1)
		turn = 0.5
	elif not _typing():
		if Input.is_physical_key_pressed(KEY_W): dir.z -= 1
		if Input.is_physical_key_pressed(KEY_S): dir.z += 1
		if Input.is_physical_key_pressed(KEY_A): dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D): dir.x += 1
		if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT): turn += 1
		if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_RIGHT): turn -= 1
		voice.ptt_held = Input.is_physical_key_pressed(KEY_V)
	me.rotation.y += turn * TURN_SPEED * delta
	if dir != Vector3.ZERO:
		me.position += me.basis * dir.normalized() * WALK_SPEED * delta
	me.position.x = clampf(me.position.x, -95, 95)
	me.position.z = clampf(me.position.z, -95, 95)


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not in_session:
		return
	match k.physical_keycode:
		KEY_T:
			voice.mic_mode = SpikeVoice.MicMode.PUSH_TO_TALK if voice.mic_mode == SpikeVoice.MicMode.OPEN \
					else SpikeVoice.MicMode.OPEN
		KEY_M:
			voice.muted = not voice.muted
		KEY_H:
			if is_host:
				host_panel.visible = not host_panel.visible
		KEY_ESCAPE:
			_quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


# --- Hosting ------------------------------------------------------------------------------------

func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	# max_channels stays 0 (unlimited; clients ask for CHANNELS). Godot 4.7.2 create_server passes
	# its arguments to create_host_bound shifted by one, so max_channels = N advertises an incoming
	# bandwidth of N + 3 bytes/s, and every client's ENet bandwidth throttle then drops most of its
	# unreliable (voice) packets for about 15 s after joining. Measured in PP-02; see README.
	var err := peer.create_server(port, MAX_CLIENTS)
	var tries := 0
	while err != OK and tries < 4:  # doc 06 section 2: 45121..45124 if taken locally
		tries += 1
		port += 1
		err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		_set_card("Could not open UDP port %d: %s" % [port, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	in_session = true
	session_id = "voice_spike_%s" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	slog.open(session_id, 1)
	roster[1] = {"slot": 0, "name": my_name}
	_spawn_me(0)
	menu.visible = false
	host_panel.visible = true
	slog.event("net_hosting", {"port": port, "input": voice.input_name,
			"lan_addresses": _lan_addresses(), "vpn_addresses": _vpn_addresses().map(func(v): return v["ip"]),
			"godot": Engine.get_version_info()["string"], "mix_rate": AudioServer.get_mix_rate()})
	if args.has("no-upnp"):
		_upnp_result = {"result": "skipped", "external_address_class": "unknown", "seconds": 0.0}
		slog.event("net_upnp_result", {"result": "skipped", "external_address_class": "unknown",
				"port": port, "seconds": 0.0})
	else:
		upnp = SpikeUpnp.new()
		upnp.finished.connect(_on_upnp_finished)
		upnp.start(port)
		_upnp_result = {"result": "pending"}
	_refresh_host_panel()


func _on_upnp_finished(r: Dictionary) -> void:
	_upnp_result = r
	# Doc 06 section 14: result, external_address_class, port, seconds. The address itself is the
	# host's real public IP, so it is not logged (logs may be shared; the class is what QA needs).
	slog.event("net_upnp_result", {"result": r["result"], "external_address_class": r["external_address_class"],
			"port": r["external_port"] if r["external_port"] else port, "seconds": r["seconds"],
			"lease_s": r["lease_s"], "gateway_found": r["gateway_lan_address"] != ""})
	_refresh_host_panel()


func _lan_addresses() -> Array:
	var out := []
	for iface in IP.get_local_interfaces():
		for a: String in iface["addresses"]:
			if JoinCode.classify(a) == "private":
				out.append(a)
	return out


## Doc 06 section 3 "VPN": 100.64.0.0/10 (Tailscale's range) or an adapter named ZeroTier.
## Detection by range and name is a heuristic (inference); the raw IP field always works.
func _vpn_addresses() -> Array:
	var out := []
	for iface in IP.get_local_interfaces():
		var fname := str(iface.get("friendly", "")) + " " + str(iface.get("name", ""))
		var named := fname.to_lower().contains("zerotier") or fname.to_lower().contains("tailscale")
		for a: String in iface["addresses"]:
			if ":" in a:
				continue
			if JoinCode.classify(a) == "cgnat" or (named and JoinCode.classify(a) != "unknown"):
				out.append({"ip": a, "adapter": str(iface.get("friendly", iface.get("name", "")))})
	return out


func _refresh_host_panel() -> void:
	if not is_host:
		return
	var r := _upnp_result
	var res := str(r.get("result", ""))
	var lan: Array = _lan_addresses()
	var lan_ip: String = r.get("gateway_lan_address", "") if str(r.get("gateway_lan_address", "")) != "" \
			else (lan[0] if lan.size() > 0 else "this PC's address")
	var ext_port := int(r.get("external_port", 0)) if int(r.get("external_port", 0)) > 0 else port
	var lines: Array[String] = []
	if res == "pending":
		upnp_line.text = "Asking your router to open UDP port %d..." % port
		upnp_line.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	elif res == "skipped":
		upnp_line.text = "UPnP skipped (--no-upnp). Use the LAN, VPN or manual options below."
		upnp_line.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	elif res == "success" and r["external_address_class"] == "public":
		upnp_line.text = "UPnP WORKED: port %d opened automatically." % ext_port
		upnp_line.add_theme_color_override("font_color", Color(0.3, 0.95, 0.35))
		var code := JoinCode.encode(r["external_address"], ext_port)
		lines.append("[b]Public address:[/b] %s : %d" % [r["external_address"], ext_port])
		lines.append("[b]Join code for friends:[/b] [font_size=30]%s[/font_size]   (Ctrl+C copies it)" % code)
		lines.append("Not yet tested from outside: the first friend to join confirms it.")
		DisplayServer.clipboard_set(code)
	elif res == "success":
		upnp_line.text = "UPnP opened the port, but you're behind a second router."
		upnp_line.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		lines.append("Your router opened the port, but your internet provider or another router sits in front of it (its outside address is %s, which is %s), so friends probably can't reach you. Use the VPN option below." % [r["external_address"], r["external_address_class"]])
	else:
		var why := "no UPnP router found" if res in ["no_gateway", "no_devices", "no_valid_gateway", "socket_error"] \
				else "your router refused to open the port (%s)" % res
		upnp_line.text = "UPnP DIDN'T WORK: %s." % why
		upnp_line.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	lines.append("")
	lines.append("[b]Manual port forward:[/b] forward UDP port %d to this PC, %s. Then type your public address (from your router's status page) here to get a code:" % [port, lan_ip])
	host_details.text = "\n".join(lines)
	var vpn_lines: Array[String] = []
	for v: Dictionary in _vpn_addresses():
		vpn_lines.append("[b]VPN (%s):[/b] %s  code [b]%s[/b]  - friends on your Tailscale/ZeroTier network can use this." % [v["adapter"], v["ip"], JoinCode.encode(v["ip"], port)])
	if vpn_lines.is_empty():
		vpn_lines.append("[b]VPN:[/b] none found. With Tailscale or ZeroTier running, its address and code appear here.")
	for a: String in lan:
		vpn_lines.append("[b]LAN code[/b] (same house): %s = %s" % [a, JoinCode.encode(a, port)])
	vpn_lines.append("[b]Local test[/b] (same PC): join raw IP 127.0.0.1%s" % ("" if port == JoinCode.DEFAULT_PORT else ":%d" % port))
	vpn_lines.append("[i]Windows Firewall: allow this program on Private networks when asked, or friends can't connect.[/i]")
	_vpn_text.text = "\n".join(vpn_lines)


func _on_public_typed(text: String) -> void:
	var code := JoinCode.encode(text.strip_edges(), port)
	public_code.text = ("Join code: " + code) if code != "" else ("" if text == "" else "Not an IPv4 address")


# --- Joining ------------------------------------------------------------------------------------

func _join_from_text(text: String) -> void:
	text = text.strip_edges()
	var n := JoinCode.normalise(text)
	if not ("." in text or ":" in text) and (n.length() == 8 or n.length() == 12):
		var d := JoinCode.decode(text)
		if not d["ok"]:
			join_status.text = d["error"]
			slog.event("net_join_code_rejected", {"reason": d["error"]})
			return
		_connect(d["ip"], int(d["port"]), "code")
		return
	_join_raw(text)


func _join_raw(text: String) -> void:
	text = text.strip_edges()
	var host := text
	var p := JoinCode.DEFAULT_PORT
	if text.begins_with("["):  # [v6]:port
		host = text.substr(1, text.find("]") - 1)
		if text.find("]:") > 0:
			p = int(text.substr(text.find("]:") + 2))
	elif text.count(":") == 1:
		host = text.get_slice(":", 0)
		p = int(text.get_slice(":", 1))
	if not (host.is_valid_ip_address()):
		join_status.text = "That isn't an IP address. Type a join code in the first box, or an IP like 100.101.102.103"
		return
	_connect(host, p, "ip")


func _connect(ip: String, p: int, via: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, p, CHANNELS)
	if err != OK:
		join_status.text = "Could not start connecting: %s" % error_string(err)
		return
	multiplayer.multiplayer_peer = peer
	_connect_started = Time.get_ticks_msec()
	_connect_via = via
	_connect_target = "%s:%d" % [ip, p]
	join_status.text = "Connecting to %s ..." % _connect_target
	print("voice spike: connecting to %s via %s" % [_connect_target, via])
	get_tree().create_timer(CONNECT_TIMEOUT_S).timeout.connect(func() -> void:
		if not in_session and _connect_started > 0 and multiplayer.multiplayer_peer \
				and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			_on_connection_failed())


func _on_connected_to_server() -> void:
	_pin_throttle(1)
	var ms := Time.get_ticks_msec() - _connect_started
	slog.peer_id = multiplayer.get_unique_id()
	slog.event("net_connected", {"connect_ms": ms, "via": _connect_via})
	join_status.text = "Connected in %d ms, joining..." % ms
	request_join.rpc_id(1, PROTOCOL, my_name)


func _on_connection_failed() -> void:
	if in_session:
		return
	slog.peer_id = 0
	slog.event("net_connect_failed", {"via": _connect_via,
			"after_ms": Time.get_ticks_msec() - _connect_started})
	slog.open_unjoined(0)
	join_status.text = "Couldn't reach %s. Check the code, that the host is running, and the host's firewall / port forward." % _connect_target
	multiplayer.multiplayer_peer = null
	_connect_started = 0
	if args.has("join") and _run_seconds > 0.0:
		_quit()


@rpc("any_peer", "call_remote", "reliable")
func request_join(protocol: int, display_name: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		apply_join_refused.rpc_id(id, "different version of the spike")
		return
	if roster.size() >= MAX_PLAYERS:
		apply_join_refused.rpc_id(id, "the farm is full")  # doc 06 section 2
		return
	var used := roster.values().map(func(v): return v["slot"])
	var slot := 0
	while slot in used:
		slot += 1
	roster[id] = {"slot": slot, "name": display_name.left(24)}
	slog.event("net_peer_joined", {"joined": id, "players": roster.size()})
	apply_join_accepted.rpc_id(id, slot, session_id, slog.now())
	_send_roster()
	_ensure_capsule(id)
	_refresh_host_panel()


@rpc("authority", "call_remote", "reliable")
func apply_join_refused(reason: String) -> void:
	join_status.text = "The host refused: %s" % reason
	slog.event("net_join_refused", {"reason": reason})
	multiplayer.multiplayer_peer = null


@rpc("authority", "call_remote", "reliable")
func apply_join_accepted(slot: int, p_session_id: String, host_t: float) -> void:
	session_id = p_session_id
	slog.open(session_id, multiplayer.get_unique_id(), host_t)
	in_session = true
	menu.visible = false
	_spawn_me(slot)


@rpc("authority", "call_remote", "reliable")
func apply_roster(r: Dictionary) -> void:
	for id: int in capsules.keys():
		if not r.has(id):
			_drop_capsule(id)
	roster = r
	for id: int in roster:
		_ensure_capsule(id)


@rpc("any_peer", "call_remote", "reliable")
func request_leave() -> void:
	if is_host:
		_leaving_peers[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_remote", "reliable")
func apply_host_leaving() -> void:
	_show_host_left("quit")


func _on_peer_connected(id: int) -> void:
	if is_host:
		_pin_throttle(id)
		print("voice spike: peer %d connected, waiting for request_join" % id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	var reason := "host_quit" if _quitting else ("quit" if _leaving_peers.has(id) else "timeout")
	_leaving_peers.erase(id)
	if roster.has(id):
		_log_speaker_stats(id)
		roster.erase(id)
		slog.event("net_peer_left", {"left": id, "reason": reason})
		_send_roster()
	_drop_capsule(id)
	_refresh_host_panel()


func _on_server_disconnected() -> void:
	_show_host_left("disconnected")


## Doc 06 section 5 "Host left": the card, then back to the menu. No host migration.
func _show_host_left(how: String) -> void:
	if is_host or not in_session:
		return
	_log_stats()
	slog.event("net_host_left", {"how": how})
	in_session = false
	_set_card("The host left. The season continues from the last dawn save. Any farmhand from this season can host it.")
	for id: int in capsules.keys():
		_drop_capsule(id)
	if me:
		me.queue_free()
		me = null
	multiplayer.multiplayer_peer = null
	if _run_seconds > 0.0:
		_quit()


# --- Movement -----------------------------------------------------------------------------------

func _send_move() -> void:
	var b := PackedByteArray()
	b.resize(17)
	b.encode_float(1, me.position.x)
	b.encode_float(5, me.position.y)
	b.encode_float(9, me.position.z)
	b.encode_float(13, me.rotation.y)
	var mp := multiplayer as SceneMultiplayer
	if is_host:
		b[0] = PKT_MOVE_RELAY
		var r := PackedByteArray([0, 0, 0, 0])
		r.encode_u32(0, 1)
		b = b.slice(0, 1) + r + b.slice(1)
		for id: int in roster:
			if id != 1 and _can_send(id):
				mp.send_bytes(b, id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, CH_MOVE)
	else:
		b[0] = PKT_MOVE
		mp.send_bytes(b, 1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, CH_MOVE)


func _apply_move(id: int, b: PackedByteArray, at: int) -> void:
	if not capsules.has(id):
		return
	var c: Node3D = capsules[id]
	c.position = Vector3(b.decode_float(at), b.decode_float(at + 4), b.decode_float(at + 8))
	c.rotation.y = b.decode_float(at + 12)


# --- Packets ------------------------------------------------------------------------------------

func _on_peer_packet(from: int, b: PackedByteArray) -> void:
	if b.is_empty():
		return
	var mp := multiplayer as SceneMultiplayer
	match b[0]:
		PKT_MOVE:
			if is_host and roster.has(from) and b.size() >= 17:
				_apply_move(from, b, 1)
				var r := PackedByteArray([PKT_MOVE_RELAY, 0, 0, 0, 0])
				r.encode_u32(1, from)
				r.append_array(b.slice(1))
				for id: int in roster:
					if id != 1 and id != from and _can_send(id):
						mp.send_bytes(r, id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, CH_MOVE)
		PKT_MOVE_RELAY:
			if not is_host and b.size() >= 21:
				_apply_move(b.decode_u32(1), b, 5)
		0x01:  # client voice frame -> host
			if _trace: print("TRACE rx %d %d %.3f %d" % [from, (b[2] << 8) | b[3], slog.now(), Time.get_ticks_usec()])
			if is_host and roster.has(from) and b.size() > 5:
				_host_take_voice(from, b)
		0x02:  # relayed voice frame -> client
			if not is_host and b.size() > 5:
				var speaker := _peer_for_slot(b[1])
				if speaker > 0:
					voice.receive(speaker, b[2], (b[3] << 8) | b[4], b.slice(5))


func _peer_for_slot(slot: int) -> int:
	for id: int in roster:
		if int(roster[id]["slot"]) == slot:
			return id
	return 0


## Doc 06 "Host relay": check the sender has a slot, read the volume byte, send the relay form
## (volume dropped) to every other peer, and decode it for the host's own playback.
func _host_take_voice(from: int, b: PackedByteArray) -> void:
	var flags := b[1]
	var seq := (b[2] << 8) | b[3]
	var vol := b[4]
	_host_volume[from] = maxi(int(_host_volume.get(from, 0)), vol)
	var relay := PackedByteArray([0x02, int(roster[from]["slot"]), flags, b[2], b[3]])
	relay.append_array(b.slice(5))
	_relay(relay, from)
	voice.receive(from, flags, seq, b.slice(5))


func _relay(relay: PackedByteArray, except_id: int) -> void:
	var mp := multiplayer as SceneMultiplayer
	for id: int in roster:
		if id != 1 and id != except_id and _can_send(id):
			if _sim_loss > 0.0 and randf() < _sim_loss:
				_sim_dropped += 1
				continue
			mp.send_bytes(relay, id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, CH_VOICE)
	_relayed_frames += 1


var _relayed_frames := 0
var _sim_loss := 0.0
var _sim_dropped := 0
var _trace := false


func _on_local_voice_frame(f: PackedByteArray) -> void:
	if _trace: print("TRACE tx %d %.3f %d" % [(f[2] << 8) | f[3], slog.now(), Time.get_ticks_usec()])
	if not in_session:
		return
	if is_host:
		# The host's own frames take the same path minus the network hop (doc 06 "Host relay").
		_host_volume[1] = maxi(int(_host_volume.get(1, 0)), f[4])
		var relay := PackedByteArray([0x02, 0, f[1], f[2], f[3]])
		relay.append_array(f.slice(5))
		_relay(relay, 1)
	else:
		if _sim_loss > 0.0 and randf() < _sim_loss:
			_sim_dropped += 1
			return
		(multiplayer as SceneMultiplayer).send_bytes(f, 1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, CH_VOICE)


## Doc 06 "The volume byte": the host reads the loudest byte per speaker every 100 ms. The spike
## has no creature, so it only shows it on the host HUD. Volumes are never logged or kept.
func _host_hearing_tick() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _host_heard_at < 0.1:
		return
	_host_heard_at = now
	_host_heard = _host_volume.duplicate()
	_host_volume.clear()


# --- Stats and logs -----------------------------------------------------------------------------

func _enet() -> ENetMultiplayerPeer:
	return multiplayer.multiplayer_peer as ENetMultiplayerPeer


func _rtt(id: int) -> Dictionary:
	var e := _enet()
	if e == null:
		return {}
	var pp := e.get_peer(id)
	if pp == null:
		return {}
	return {"rtt_ms": int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)),
			"enet_loss": snappedf(pp.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / float(ENetPacketPeer.PACKET_LOSS_SCALE), 0.0001)}


func _log_stats() -> void:
	if not in_session:
		return
	_log_bandwidth()
	if is_host:
		for id: int in roster:
			if id != 1:
				var r := _rtt(id)
				if not r.is_empty():
					slog.event("net_rtt", {"to": id, "rtt_ms": r["rtt_ms"], "enet_loss": r["enet_loss"]})
		slog.event("voice_relay_stats", {"relayed_frames": _relayed_frames})
	else:
		var r := _rtt(1)
		if not r.is_empty():
			slog.event("net_rtt", {"to": 1, "rtt_ms": r["rtt_ms"], "enet_loss": r["enet_loss"]})
	slog.event("voice_sent", {"input": voice.input_name, "encoded": voice.frames_encoded,
			"sent": voice.frames_sent, "bytes": voice.bytes_sent, "talk_spurts": voice.talk_spurts,
			"max_opus_bytes": voice.max_packet_bytes, "sim_dropped": _sim_dropped})
	for id: int in voice.speaker_ids():
		_log_speaker_stats(id)
	slog.event("voice_mix", {"samples": voice.mix_samples, "clicks": voice.mix_clicks,
			"max_delta": snappedf(voice.mix_max_delta, 0.0001), "click_delta": voice.click_delta,
			"speakers": voice.speaker_ids().size(), "fps": Engine.get_frames_per_second()})


func _log_speaker_stats(id: int) -> void:
	var s := voice.speaker_stats(id)
	if s.is_empty():
		return
	var lost: int = s["lost"]
	var total: int = s["decoded"] + lost
	s["loss"] = snappedf(lost / float(total), 0.0001) if total > 0 else 0.0
	slog.event("voice_stats", s)


func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	if in_session:
		_log_stats()
		if is_host:
			for id: int in roster:
				if id != 1 and _can_send(id):
					apply_host_leaving.rpc_id(id)
		else:
			request_leave.rpc_id(1)
		slog.event("spike_end", {"seconds": snappedf(_elapsed, 0.01), "host": is_host,
				"peers": roster.size()})
	elif not is_host:
		slog.open_unjoined(slog.peer_id)
		slog.event("spike_end", {"seconds": snappedf(_elapsed, 0.01), "host": false, "peers": 0})
	# Let the reliable goodbye go out before the peer closes.
	for _i in 5:
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.poll()
		await get_tree().create_timer(0.05).timeout
	if upnp:
		upnp.cleanup()
	in_session = false
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	slog.close()
	voice.shutdown()
	# Give the audio thread a few mixes to drop the stopped playbacks (else ObjectDB leak warning).
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()


# --- UI -----------------------------------------------------------------------------------------

var _vpn_text: RichTextLabel


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	menu = PanelContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.custom_minimum_size = Vector2(620, 0)
	var mv := VBoxContainer.new()
	menu.add_child(mv)
	var title := Label.new()
	title.text = "Voice spike (PP-02)"
	title.add_theme_font_size_override("font_size", 28)
	mv.add_child(title)
	var host_btn := Button.new()
	host_btn.text = "Host"
	host_btn.pressed.connect(_host)
	mv.add_child(host_btn)
	mv.add_child(HSeparator.new())
	var l1 := Label.new()
	l1.text = "Join with a code (like SC07-21W2):"
	mv.add_child(l1)
	var h1 := HBoxContainer.new()
	join_code_edit = LineEdit.new()
	join_code_edit.placeholder_text = "XXXX-XXXX"
	join_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_code_edit.text_submitted.connect(func(t: String) -> void: _join_from_text(t))
	h1.add_child(join_code_edit)
	var jb1 := Button.new()
	jb1.text = "Join"
	jb1.pressed.connect(func() -> void: _join_from_text(join_code_edit.text))
	h1.add_child(jb1)
	mv.add_child(h1)
	var l2 := Label.new()
	l2.text = "...or type an IP (VPN IPs too), optionally IP:port:"
	mv.add_child(l2)
	var h2 := HBoxContainer.new()
	join_ip_edit = LineEdit.new()
	join_ip_edit.placeholder_text = "100.101.102.103 or 203.0.113.7:45121"
	join_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_ip_edit.text_submitted.connect(func(t: String) -> void: _join_raw(t))
	h2.add_child(join_ip_edit)
	var jb2 := Button.new()
	jb2.text = "Join"
	jb2.pressed.connect(func() -> void: _join_raw(join_ip_edit.text))
	h2.add_child(jb2)
	mv.add_child(h2)
	join_status = Label.new()
	join_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	mv.add_child(join_status)
	ui.add_child(menu)

	host_panel = PanelContainer.new()
	host_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	host_panel.visible = false
	var hv := VBoxContainer.new()
	host_panel.add_child(hv)
	upnp_line = Label.new()
	upnp_line.add_theme_font_size_override("font_size", 30)
	upnp_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	hv.add_child(upnp_line)
	host_details = RichTextLabel.new()
	host_details.bbcode_enabled = true
	host_details.fit_content = true
	host_details.selection_enabled = true
	hv.add_child(host_details)
	var ph := HBoxContainer.new()
	public_edit = LineEdit.new()
	public_edit.placeholder_text = "your public IPv4 address"
	public_edit.custom_minimum_size.x = 260
	public_edit.text_changed.connect(_on_public_typed)
	ph.add_child(public_edit)
	public_code = Label.new()
	ph.add_child(public_code)
	hv.add_child(ph)
	_vpn_text = RichTextLabel.new()
	_vpn_text.bbcode_enabled = true
	_vpn_text.fit_content = true
	_vpn_text.selection_enabled = true
	hv.add_child(_vpn_text)
	players_label = Label.new()
	players_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	players_label.add_theme_font_size_override("font_size", 20)
	hv.add_child(players_label)
	ui.add_child(host_panel)

	hud = Label.new()
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.offset_left = 12
	hud.offset_bottom = -12
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	ui.add_child(hud)

	card = Label.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	card.add_theme_font_size_override("font_size", 22)
	card.add_theme_color_override("font_outline_color", Color.BLACK)
	card.add_theme_constant_override("outline_size", 8)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.custom_minimum_size = Vector2(900, 0)
	card.position.y -= 120
	ui.add_child(card)


func _set_card(text: String) -> void:
	card.text = text
	if not in_session and menu:
		menu.visible = true


func _update_hud() -> void:
	if not in_session or voice == null:
		hud.text = ""
		return
	var mode := "OPEN MIC (voice activity)" if voice.mic_mode == SpikeVoice.MicMode.OPEN else "PUSH-TO-TALK (hold V)"
	var talking := "MUTED" if voice.muted else ("TALKING" if voice.transmitting else "quiet")
	var lines: Array[String] = []
	lines.append("%s - you are %s   |   %s   |   input: %s, level %d dB" % [
			"HOST" if is_host else "CLIENT", my_name, mode, voice.input_name, roundi(voice.last_level_db)])
	lines.append("Mic: %s   |   WASD move, Q/E turn, T toggle push-to-talk, V talk (PTT), M mute, H host screen, Esc quit" % talking)
	var players: Array[String] = []
	for id: int in roster:
		var info: Dictionary = roster[id]
		var bits := "%s (peer %d)" % [info["name"], id]
		if id != multiplayer.get_unique_id():
			var target := id if is_host else 1
			var r := _rtt(target) if (is_host or id == 1) else {}
			if not r.is_empty():
				bits += " rtt %d ms" % r["rtt_ms"]
			var lvl := voice.speaker_level(id)
			bits += " " + "|".repeat(clampi(int(lvl * 40.0), 0, 20))
		if is_host and _host_heard.has(id):
			bits += " [creature hears %d]" % _host_heard[id]
		players.append(bits)
	lines.append("Players: " + ";  ".join(players))
	hud.text = "\n".join(lines)
	if is_host and players_label:
		players_label.text = "Players connected: %d   %s" % [roster.size(), ";  ".join(players)]


## Host: true while `id` is fully connected and hasn't said it is leaving. Sending to a peer that
## is mid-disconnect makes ENet print "Unable to send packet on channel 0, max channels: 0".
func _can_send(id: int) -> bool:
	if _leaving_peers.has(id):
		return false
	var e := _enet()
	var pp := e.get_peer(id) if e else null
	return pp != null and pp.get_state() == ENetPacketPeer.STATE_CONNECTED


func _send_roster() -> void:
	for id: int in roster:
		if id != 1 and _can_send(id):
			apply_roster.rpc_id(id, roster)


var _bw_at := -1.0


## Doc 06 section 13 asks the spike to measure bandwidth. ENet's host counters cover everything
## this peer sent and received (ENet headers included); 28 bytes of UDP/IPv4 header are added per
## datagram, so the figures are what the home connection carries.
func _log_bandwidth() -> void:
	var e := _enet()
	if e == null or e.host == null:
		return
	var now := slog.now()
	var sent := e.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var recv := e.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	var sent_p := e.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
	var recv_p := e.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)
	if _bw_at >= 0.0 and now > _bw_at:
		var s := now - _bw_at
		slog.event("net_bandwidth", {"seconds": snappedf(s, 0.01), "players": roster.size(),
				"up_kbps": snappedf((sent + 28 * sent_p) * 8.0 / s / 1000.0, 0.1),
				"down_kbps": snappedf((recv + 28 * recv_p) * 8.0 / s / 1000.0, 0.1),
				"up_datagrams_per_s": snappedf(sent_p / s, 0.1)})
	_bw_at = now


func _maybe_screenshot() -> void:
	if not args.has("screenshot") or _shot_done:
		return
	if _elapsed < float(args.get("screenshot-at", 10.0)):
		return
	_shot_done = true
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(str(args["screenshot"]))
	print("voice spike: screenshot %s -> %s" % [args["screenshot"], error_string(err)])


var _shot_done := false
var _stalled := false


## ENet's RTT throttle (enet_peer_throttle) drops a share of *unreliable* packets on the sender
## each time a round trip comes back slower than the running mean plus twice its variance, and
## recovers slowly. A start-up hitch on one window cost 37 voice frames (about 0.7 s) in PP-02's
## windowed run; with a forced 300 ms hitch (--stall-at) ENet's default lost 4 and 13 frames in two
## runs, pinned 0 and 0. Voice has its own concealment, so deceleration 0 keeps the throttle full.
## (Bandwidth congestion is not handled by this; doc 06 section 13 puts 4 players at well under
## 1 Mbps.) --enet-throttle keeps ENet's default for comparison.
func _pin_throttle(id: int) -> void:
	if args.has("enet-throttle"):
		return
	var e := _enet()
	var pp := e.get_peer(id) if e else null
	if pp:
		pp.throttle_configure(5000, 2, 0)  # ENet defaults are (5000, 2, 2)
