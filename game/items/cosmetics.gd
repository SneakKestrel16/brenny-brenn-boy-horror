extends Node
## P5-05 (doc 01 Store, doc 02 s21.5, doc 07 s8, D-144, Q-255 item 3): hats and overalls. Autoload `Cosmetics`.
## Host-authoritative like the store: a client sends `request_cosmetic(op, id)` (`buy` or `wear`; `wear` with an
## empty id takes the slot off), the host validates, mutates, logs and broadcasts the whole look table with
## `apply_cosmetics`. Rows are `data/cosmetics.json` records of kind `hat` or `overalls`; nothing here is a number
## except the placeholder look of a cosmetic whose P5-06 model is not in `assets/models/` yet.
## Ownership is kept by the player's uid (the roster id, doc 02 s21.5) so it survives a rejoin, a new peer id, the
## save (group `saveable`, extras key `cosmetics`) and the next season (this autoload outlives a Main). It has no
## gameplay effect: nothing reads it except looks.

signal changed  ## the look table changed (every peer)

const SLOTS := [&"hat", &"overalls"]
## Placeholder hat looks until `char_hat_<id>.glb` lands (P5-06): colour, brim radius, crown height, crown top radius (0 = cone).
const HAT_LOOK := {&"flat_cap": [Color(0.4, 0.38, 0.34), 0.2, 0.08, 0.14], &"bucket_hat": [Color(0.6, 0.55, 0.38), 0.24, 0.12, 0.14],
		&"tin_pot": [Color(0.62, 0.64, 0.66), 0.15, 0.14, 0.13], &"party_cone": [Color(0.8, 0.2, 0.55), 0.12, 0.3, 0.0],
		&"turnip_crown": [Color(0.55, 0.3, 0.6), 0.16, 0.16, 0.2], &"top_hat": [Color(0.08, 0.08, 0.1), 0.22, 0.28, 0.14]}
## Placeholder overalls tints until the glb extras `tint` exist.
const TINT_LOOK := {&"overalls_denim": Color(0.2, 0.3, 0.55), &"overalls_patched": Color(0.45, 0.33, 0.2),
		&"overalls_striped": Color(0.55, 0.55, 0.62), &"overalls_plaid": Color(0.5, 0.18, 0.16), &"overalls_gold": Color(0.8, 0.65, 0.2)}

var _owned: Dictionary = {}  ## host: uid -> Array[StringName]
var _worn: Dictionary = {}  ## host: uid -> {slot: id}
var _wire: Dictionary = {"owned": {}, "worn": {}}  ## every peer: peer id -> owned ids / {slot: id}
var save_key := "cosmetics"
var _poll := 0.0


func _ready() -> void:
	add_to_group(&"saveable")
	Net.request_received.connect(_on_request)
	Net.apply_received.connect(_on_apply)
	Game.player_joined.connect(func(_p: int) -> void: _send())
	Game.player_left.connect(func(_p: int) -> void: _send())


## Host: a joiner's uid can arrive after `player_joined` (Net admits a lobby joiner first), so a changed table is
## resent within a second. ponytail: a poll, not a hook into Net.profiles.
func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 1.0 and Game.is_host():
		_poll = 0.0
		if _table() != _wire:
			_send()


# --- rules ---------------------------------------------------------------------------------------

func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in Data.records(&"cosmetics"):
		if String(r.get("kind", "")) in ["hat", "overalls"]:
			out.append(StringName(r.id))
	return out


func rec(id: StringName) -> Dictionary:
	return Data.record(&"cosmetics", id) if id in ids() else {}


func slot_of(id: StringName) -> StringName:
	return StringName(String(rec(id).get("kind", "")))


## Doc 02 s21.5: sold only once the season's debt is paid (the mirrored `Debt` flags, so any peer can ask).
func sold_now() -> bool:
	var d := get_tree().get_first_node_in_group(&"debt")
	return d != null and not d.lost and d.paid > 0 and d.owed == 0


func owned_of(peer: int) -> Array:
	return _wire.owned.get(peer, [])


func look(peer: int) -> Dictionary:
	return _wire.worn.get(peer, {})


## Host: why `peer` cannot buy `id`, else empty. Near the crate until the season is over (then the Season's End card sells).
func why_not_buy(peer: int, id: StringName) -> StringName:
	var farm := get_tree().get_first_node_in_group(&"farm")
	if rec(id).is_empty():
		return &"no_item"
	if farm == null or not sold_now():
		return &"not_sold"
	if Game.is_ghost(peer):
		return &"ghost"
	if id in _owned.get(Save.uid_of(peer), []):
		return &"owned"
	if not Clock.season_over and farm.store.has_method(&"_too_far") and farm.store._too_far(peer):
		return &"too_far"
	if farm.coins < int(rec(id).price):
		return &"no_coins"
	return &""


func buy(peer: int, id: StringName) -> StringName:
	var why := why_not_buy(peer, id)
	if why != &"":
		Log.event(&"cosmetic_refused", {"item": String(id), "buyer": peer, "reason": String(why)})
		return why
	var farm := get_tree().get_first_node_in_group(&"farm")
	var uid := Save.uid_of(peer)
	if uid == "":
		return &"no_item"  # a bot has no roster id; it buys nothing
	farm.add_coins(-int(rec(id).price), &"cosmetic", peer)
	_owned[uid] = _owned.get(uid, []) + [id]
	Log.event(&"cosmetic_bought", {"item": String(id), "buyer": peer, "price": int(rec(id).price), "coins": farm.coins})
	wear(peer, id)
	return &""


## Host: put an owned cosmetic on, or take `id`'s slot off when `id` is empty and `slot` names it.
func wear(peer: int, id: StringName, slot: StringName = &"") -> StringName:
	var uid := Save.uid_of(peer)
	if uid == "":
		return &"no_item"
	if id == &"":
		if not slot in SLOTS:
			return &"no_item"
	elif not id in _owned.get(uid, []):
		return &"not_owned"
	else:
		slot = slot_of(id)
	var w: Dictionary = _worn.get(uid, {})
	w[slot] = id
	_worn[uid] = w
	Log.event(&"cosmetic_worn", {"peer": peer, "slot": String(slot), "item": String(id)})
	_send()
	return &""


# --- wire ----------------------------------------------------------------------------------------

func _table() -> Dictionary:
	var t := {"owned": {}, "worn": {}}
	for p in Game.players:
		var uid := Save.uid_of(p)
		if uid != "":
			t.owned[p] = _owned.get(uid, [])
			t.worn[p] = _worn.get(uid, {})
	return t


func _send() -> void:
	if not Game.is_host():
		return
	var t := _table()
	Net.to_peers(&"apply_cosmetics", [t])
	_apply(t)


func _apply(t: Dictionary) -> void:
	var me := Game.local_peer()
	if _wire.owned.has(me) and t.owned.get(me, []).size() > _wire.owned[me].size():  # the buyer hears the purchase (P5-07 cue)
		Soundscape.play_2d(&"ui_cosmetic_buy")
	_wire = t
	changed.emit()


func _on_apply(what: StringName, args: Array) -> void:
	if what == &"cosmetics" and not Game.is_host():
		_apply(args[0])


func _on_request(what: StringName, peer: int, args: Array) -> void:
	if what != &"cosmetic" or not Game.is_host():
		return
	var why := &""
	match args[0]:
		&"buy": why = buy(peer, StringName(args[1]))
		&"wear": why = wear(peer, StringName(args[1]), StringName(args[2]) if args.size() > 2 else &"")
		&"sync": _send()
	if why != &"":
		if peer == Game.local_peer():
			Net.apply_received.emit(&"refused", [&"cosmetic", why])
		else:
			Net.to_peers(&"apply_refused", [&"cosmetic", why], [peer])


# --- save (group `saveable`, host) ------------------------------------------------------------------

func save_state() -> Dictionary:
	var o := {}
	for u in _owned:
		o[u] = _owned[u].map(func(i: StringName) -> String: return String(i))
	var w := {}
	for u in _worn:
		w[u] = {}
		for s in _worn[u]:
			w[u][String(s)] = String(_worn[u][s])
	return {"owned": o, "worn": w}


func load_state(d: Dictionary) -> void:
	_owned.clear()
	_worn.clear()
	var known := ids()
	for u in d.get("owned", {}):
		_owned[str(u)] = Array(d.owned[u]).map(func(i: Variant) -> StringName: return StringName(str(i))).filter(func(i: StringName) -> bool: return i in known)
	for u in d.get("worn", {}):
		var w := {}
		for s in d.worn[u]:
			var i := StringName(str(d.worn[u][s]))
			if i == &"" or (i in _owned.get(str(u), []) and slot_of(i) == StringName(str(s))):
				w[StringName(str(s))] = i
		_worn[str(u)] = w
	_send()


# --- looks (every peer) ----------------------------------------------------------------------------

func _glb(prefix: String, id: StringName) -> PackedScene:
	var path := "res://assets/models/%s_%s.glb" % [prefix, String(id).trim_prefix("overalls_")]
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


## A hat node, origin at the band bottom (P5-06: the glb; else a placeholder from HAT_LOOK).
func make_hat(id: StringName) -> Node3D:
	var scene := _glb("char_hat", id)
	var hat: Node3D
	if scene:
		hat = scene.instantiate()
	else:
		hat = Node3D.new()
		var h: Array = HAT_LOOK.get(id, HAT_LOOK[&"flat_cap"])
		if h[3] > 0.0:
			hat.add_child(_cyl(h[0], h[1], h[1], 0.025, 0.0))
		hat.add_child(_cyl(h[0], h[3], 0.16, h[2], 0.0125 if h[3] > 0.0 else 0.0))
	hat.name = "CosmeticHat"
	return hat


func _cyl(col: Color, top: float, bottom: float, height: float, y: float) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position.y = y + height / 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mi.material_override = mat
	return mi


## Host and clients: forget everything (leaving a session; a saved season is loaded by `load_state`).
func reset() -> void:
	_owned.clear()
	_worn.clear()
	_wire = {"owned": {}, "worn": {}}
	changed.emit()


## The overalls tint: glTF extra `tint` (`#rrggbb`) on the glb's `Armature` node (P5-06), else TINT_LOOK. The extra
## `"player"` (patched, striped, plaid) means no override: transparent, the player colour stays (D-159).
func tint(id: StringName) -> Color:
	var scene := _glb("char_overalls", id)
	if scene:
		var root := scene.instantiate()
		var t: Variant = null
		for n: Node in [root] + root.find_children("*", "Node", true, false):
			if n.has_meta(&"extras") and n.get_meta(&"extras") is Dictionary and n.get_meta(&"extras").has("tint"):
				t = n.get_meta(&"extras").tint
				break
		root.free()
		if t is String:
			return Color(0, 0, 0, 0) if t == "player" else Color.html(t)
		if t is Array and t.size() >= 3:
			return Color(float(t[0]), float(t[1]), float(t[2]))
	return TINT_LOOK.get(id, Color(0.2, 0.24, 0.3))


## Overlay meshes of `char_overalls_<name>.glb` re-parented into a farmer Skeleton3D (P5-06); the meshes added.
func attach_overlay(skel: Skeleton3D, id: StringName) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var scene := _glb("char_overalls", id)
	if scene == null:
		return out
	var root := scene.instantiate()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		m.get_parent().remove_child(m)
		m.owner = null  # else the Skeleton3D add warns of an inconsistent owner
		skel.add_child(m)
		out.append(m)
	root.free()
	return out
