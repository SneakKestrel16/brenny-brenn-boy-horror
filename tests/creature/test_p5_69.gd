extends SceneTree
## P5-69 (CEO D-188: "the creature should be the least visible possible", "dash across, limiting view of it in
## daytime"; doc 01 "What players see": by day parts and motion only). Solo host, time scale 4. The player stands at
## field A's plot centre, then field B's (doc 04: (30, -5.5), (72, -5.5)), 150 s each from the day's second third.
## A sighting is an open ray from the player's eye (1.65 m) to the creature's chest (1.2 m) on layers 1 and 5 (walls,
## corn). Reports the longest continuous sighting and the nearest one. Fails if the longest reaches 2 s (P5-65 QA
## measured up to 8.5 s at walk speed, seeds 2 and 4), the creature leaves lurk, or it walks under 50 m (hiding froze it).
##   for s in 1 2 3 4 5; do "$GODOT" --headless --audio-driver Dummy --path . -s res://tests/creature/test_p5_69.gd -- --host --port=3969$s --seed=$s --free-mouse; done
## Exits 0 on pass, 1 on any failure.

const FIELDS := [Vector3(30, 0, -5.5), Vector3(72, 0, -5.5)]
const HOLD_S := 150.0
const SCALE := 4.0
const MAX_S := 2.0
const MIN_WALK_M := 50.0

var _frames := 0
var cr: Node


func _initialize() -> void:
	change_scene_to_file.call_deferred("res://game/core/boot.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 60:
		_run()
	return false


func _run() -> void:
	var game := root.get_node("Game")
	var main := root.get_node("Main")
	cr = main.get_node("Creature")
	var clock := root.get_node("Clock")
	var me: int = game.players.keys()[0]
	Engine.time_scale = SCALE
	var longest := 0.0
	var nearest := INF
	var walked := 0.0
	var states := {}
	for f: Vector3 in FIELDS:
		game.players[me].freeze_until = Time.get_ticks_msec() + 3600000
		game.players[me].pos = f
		clock.t_phase = 0.4 * clock.length_of(&"day")
		var run := 0.0
		var t := 0.0
		var at: Vector3 = cr.global_position
		while t < HOLD_S:
			await physics_frame
			var dt := SCALE / Engine.physics_ticks_per_second
			t += dt
			states[cr.state] = true
			walked += Vector2(cr.global_position.x - at.x, cr.global_position.z - at.z).length()
			at = cr.global_position
			var eye := f + Vector3.UP * 1.65
			var chest: Vector3 = cr.global_position + Vector3.UP * 1.2
			var q := PhysicsRayQueryParameters3D.create(eye, chest, 1 | 16)
			if cr.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				run += dt
				longest = maxf(longest, run)
				nearest = minf(nearest, eye.distance_to(chest))
			else:
				run = 0.0
		print("  field (%d, %.1f): phase %s" % [f.x, f.z, clock.phase])
	Engine.time_scale = 1.0
	print("seed %d: longest sighting %.2f s, nearest %.1f m, walked %.0f m, states %s" % [game.seed_value, longest, nearest, walked, states.keys()])
	var ok := longest < MAX_S and walked > MIN_WALK_M and states.keys() == [&"lurk"]
	print("PASS" if ok else "FAILED")
	quit(0 if ok else 1)
