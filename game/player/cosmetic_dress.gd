extends Node
## P5-05 (doc 07 s8, Q-255 item 3): puts a player's worn cosmetics on their in-world body, on every peer. Child of the
## Player. The hat sits on the FarmerBody's `hat` bone (a worn hat replaces the role hat; the world body has no role hat
## yet, the lobby line-up swaps it) and the overalls use the body's tint slot (alpha 0 keeps the player colour, D-159).
## The local player's own body is hidden in first person, so it dresses nothing. Visual only.

var _player: CharacterBody3D
var _peer := -1
var _hat_id := &""
var _ov_id := &"-"
var _hat: Node3D


func _ready() -> void:
	_player = get_parent()
	Cosmetics.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if _player.is_local:
		return
	var look := Cosmetics.look(_player.peer)
	var hat := StringName(look.get(&"hat", &""))
	if hat != _hat_id:
		_hat_id = hat
		_hat = Cosmetics.make_hat(hat) if hat != &"" else null
		_player._mesh.wear_hat(_hat)
	var ov := StringName(look.get(&"overalls", &""))
	if ov != _ov_id:
		_ov_id = ov
		_player._mesh.set_overalls(Cosmetics.tint(ov) if ov != &"" else Color(0, 0, 0, 0), ov)


func _process(_delta: float) -> void:
	if _player.peer != _peer:  # the peer id is set after _ready
		_peer = _player.peer
		_refresh()
