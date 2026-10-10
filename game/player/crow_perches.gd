class_name CrowPerches
extends Node
## P5-52 Crowkeeper (doc 01 Roles row pending the CEO, Q-352; numbers in `data/roles.json` `crowkeeper`, all placeholder).
## The Crowkeeper presses `place_perch` (P) at a field or corn edge to set a bait perch (up to `max_perches`; pressing
## beside their own perch takes it back up). Host: when anything moves within `flush_radius_m` of a perch, its crows burst
## up cawing: a `noise_crow_flush` the creature hears, a public `perch_flush` scare every peer draws, a cooldown. Movers are
## living players (not the owner: inference, they would flush their own perch every time they tended it), loose animals
## (pen animals pace all day: inference), the creature, and the creature's fake-out crows (Scares `fake_out` within the radius).
## It warns that something is near, never what: no marker, no list of who set it off, the same burst for a teammate and the creature.
## Wire: `request_store(&"perch")` in, `apply_scare(&"perches", ...)` out (state, extra "x:z:owner;..."; late joiners ask via
## `farm_state`) and `apply_scare(&"perch_flush", ...)`. Perch nodes stay out of group `crow_perches` (creature cover, check_farm).

const TICK_S := 0.25  ## host check period (placeholder)
const PERCH_EMPTY_S := 60.0  ## the flushed crow's perch stays empty this long (same as ai_director.json `crows` `perch_empty_s`)

var perches: Array = []  ## every peer: {pos: Vector3, owner: int, cd: float (host)}
var _nodes: Array[Node3D] = []
var _prev: Dictionary = {}  ## host: mover id -> last position
var _t := 0.0
var sources_override: Callable = Callable()  ## tests: returns mover id -> Vector3


static func perk(key: StringName) -> float:
	return float(Roles.perks(&"crowkeeper")[key])


func _ready() -> void:
	Net.apply_received.connect(_on_apply)
	if Game.is_host() and OS.get_cmdline_user_args().has("--autoperch"):  # QA: place a perch at 6 s, flush it at 10 s (multi-instance sync check)
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			var edge := Node3D.new()  # the barn is not at an edge: make one under the host
			edge.add_to_group(&"creature_cover")
			add_child(edge)
			edge.global_position = Game.players[1].pos
			Log.event(&"qa_autoperch", {"refused": String(toggle(1))}))
		get_tree().create_timer(10.0).timeout.connect(func() -> void:
			if not perches.is_empty():
				flush(perches[0], "qa"))
	if Game.is_host():
		Net.request_received.connect(_on_request)


# --- host ----------------------------------------------------------------------------------------

func _on_request(what: StringName, peer: int, args: Array) -> void:
	if what == &"store" and args[0] == &"perch":
		var why := toggle(peer)
		if why != &"" and peer != 1:
			Net.to_peers(&"apply_refused", [&"perch", why], [peer])
		elif why != &"":
			Net.apply_received.emit(&"refused", [&"perch", why])
	elif what == &"farm_state":
		_send(peer)


## Host: `peer` places a perch where they stand, or takes up their own within `pickup_m`. Returns the refusal, "" when done.
func toggle(peer: int) -> StringName:
	var st: Dictionary = Game.players.get(peer, {})
	if not st.has("pos") or Game.is_ghost(peer):
		return &"ghost"
	if Roles.of(peer) != &"crowkeeper":
		return &"not_crowkeeper"
	var at := Vector3(st.pos.x, 0.0, st.pos.z)
	for i in perches.size():
		if int(perches[i].owner) == peer and _flat(perches[i].pos, at) <= perk(&"pickup_m"):
			perches.remove_at(i)
			Log.event(&"perch_removed", {"player": peer})
			_send()
			return &""
	if perches.filter(func(p: Dictionary) -> bool: return int(p.owner) == peer).size() >= int(perk(&"max_perches")):
		return &"perches_full"
	if not at_edge(at, get_tree().get_nodes_in_group(&"plot_spots") + get_tree().get_nodes_in_group(&"creature_cover")):
		return &"not_at_edge"
	for p in perches:
		if _flat(p.pos, at) < perk(&"min_gap_m"):
			return &"too_close"
	perches.append({"pos": at, "owner": peer, "cd": 0.0})
	Log.event(&"perch_placed", {"player": peer, "position": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)]})
	_send()
	return &""


## A field or corn edge: within `edge_m` of any spot node (plot_spots = field plots, creature_cover = corn cover points).
static func at_edge(at: Vector3, spots: Array) -> bool:
	for n: Node3D in spots:
		if _flat(n.global_position, at) <= perk(&"edge_m"):
			return true
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _physics_process(delta: float) -> void:
	if not Game.is_host() or perches.is_empty():
		_prev.clear()
		return
	for p in perches:
		p.cd = maxf(float(p.cd) - delta, 0.0)
	_t += delta
	if _t >= TICK_S:
		_t = 0.0
		step()


## Host: one check. Public so the test can drive it. Returns how many perches flushed.
func step() -> int:
	var now := _sources()
	var flushed := 0
	for p in perches:
		if float(p.cd) > 0.0:
			continue
		for id in now:
			if _flat(now[id], p.pos) <= perk(&"flush_radius_m") and _flat(now[id], _prev.get(id, now[id])) >= perk(&"move_eps_m") and not (id is int and id == int(p.owner)):
				flush(p, id)
				flushed += 1
				break
	_prev = now
	return flushed


## Where everything that can set a perch off is: living players, loose animals, the creature (id -> position).
func _sources() -> Dictionary:
	if sources_override.is_valid():
		return sources_override.call()
	var out := {}
	for peer in Game.players:
		var st: Dictionary = Game.players[peer]
		if st.has("pos") and not Game.is_ghost(peer):
			out[peer] = st.pos
	var animals := get_tree().get_first_node_in_group(&"animals")
	for i in (animals.herd.size() if animals else 0):
		if animals.is_loose(i):
			out["a%d" % i] = animals.herd[i].pos
	var cr := get_tree().get_first_node_in_group(&"creature") as Node3D
	if cr:
		out["creature"] = cr.global_position
	return out


## Host: the perch's crows burst. `by` only goes in the log, never to a client.
func flush(p: Dictionary, by: Variant) -> void:
	p.cd = perk(&"flush_cooldown_s")
	NoiseBus.emit_kind(&"crow_flush", p.pos, 0)  # source 0: no player to blame, no ghost to filter
	Log.event(&"perch_flush", {"position": [snappedf(p.pos.x, 0.1), snappedf(p.pos.z, 0.1)], "owner": p.owner, "by": str(by)})
	var pos: Vector3 = p.pos + Vector3.UP
	Net.to_peers(&"apply_scare", [&"perch_flush", -1, pos, ""])
	Net.apply_received.emit(&"scare", [&"perch_flush", -1, pos, ""])


func _send(peer: int = 0) -> void:
	var parts: PackedStringArray = []
	for p in perches:
		parts.append("%.2f:%.2f:%d" % [p.pos.x, p.pos.z, p.owner])
	var args := [&"perches", -1, Vector3.ZERO, ";".join(parts)]
	Net.to_peers(&"apply_scare", args, [peer] if peer > 1 else [])
	if peer <= 1:
		Net.apply_received.emit(&"scare", args)


# --- every peer ----------------------------------------------------------------------------------

func _on_apply(what: StringName, args: Array) -> void:
	if what != &"scare":
		return
	match args[0]:
		&"perches":
			if not Game.is_host():
				perches.clear()
				for s: String in String(args[3]).split(";", false):
					var a := s.split(":")
					perches.append({"pos": Vector3(float(a[0]), 0.0, float(a[1])), "owner": int(a[2]), "cd": 0.0})
			Log.event(&"perches_seen", {"count": perches.size()})
			_show()
		&"perch_flush":
			Log.event(&"perch_flush_seen", {"position": [snappedf(args[2].x, 0.1), snappedf(args[2].z, 0.1)]})
			Soundscape.play_3d(&"sfx_crow_burst", args[2])
			var scares := get_parent().get_node_or_null(^"Scares")
			if scares:
				scares._crow_burst(args[2])
			_empty(args[2])
		&"fake_out":
			if Game.is_host():  # the creature's fake crows count as movement
				for p in perches:
					if float(p.cd) <= 0.0 and _flat(p.pos, args[2]) <= perk(&"flush_radius_m"):
						flush(p, "fake_out")


## Look: a post with a crossbar and a crow on it (the same animal_crow as the farm's perches).
func _show() -> void:
	while _nodes.size() > perches.size():
		_nodes.pop_back().queue_free()
	while _nodes.size() < perches.size():
		var n := Node3D.new()
		var post := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.05
		m.bottom_radius = 0.07
		m.height = 1.6
		post.mesh = m
		post.position.y = 0.8
		n.add_child(post)
		var bar := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.7, 0.05, 0.05)
		bar.mesh = b
		bar.position.y = 1.5
		n.add_child(bar)
		var crow := (load("res://assets/models/animal_crow.glb") as PackedScene).instantiate() as Node3D
		crow.name = "Crow"
		crow.position = Vector3(0.0, 1.55, 0.0)
		n.add_child(crow)
		for ap in crow.find_children("*", "AnimationPlayer"):
			(ap as AnimationPlayer).get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
			(ap as AnimationPlayer).play(&"idle")
		add_child(n)
		_nodes.append(n)
	for i in _nodes.size():
		_nodes[i].global_position = perches[i].pos


## The flushed perch's crow is gone for a while.
func _empty(at: Vector3) -> void:
	for n in _nodes:
		if _flat(n.global_position, at) < 0.5 and n.has_node(^"Crow"):
			n.get_node(^"Crow").visible = false
			await get_tree().create_timer(PERCH_EMPTY_S).timeout
			if is_instance_valid(n) and n.has_node(^"Crow"):
				n.get_node(^"Crow").visible = true
			return


# --- client input --------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Game.console_open or event is InputEventMouse or not event.is_action_pressed(&"place_perch") or event.is_echo():
		return
	if Roles.of(Game.local_peer()) == &"crowkeeper" and not Game.is_ghost(Game.local_peer()):
		Net.to_host(&"request_store", [&"perch", &""])
