class_name LevelCamera
extends Camera2D
## One shared camera for all players. Add it to the level scene (not inside a Player).
##
## It reads the same `elevation` every Walker already tracks, so ramps, ledges, ladders and platforms
## keep working unchanged. Players only need to be in the "players" group (add_to_group("players") in Player._ready).
##
## X: centred between the left-most and right-most player.
## Y: follows the floor most players are on (ties go to the right-most player's floor),
##    using the average elevation of the players on that floor.

@export var base_y := 120.0          
@export var smoothing_speed := 8.0
@export var start_shared := true    


func _ready() -> void:
	add_to_group("level_camera")
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	limit_left = 0
	limit_right = 5000
	limit_top = -10000       
	limit_bottom = 10000
	set_shared(start_shared)
	var t = _target()
	if t != null:
		global_position = t
		reset_smoothing()


## Jump straight to where the camera should be (after a door), instead of gliding there.
func snap() -> void:
	var t = _target()
	if t == null:
		return
	position_smoothing_enabled = false
	global_position = t
	reset_smoothing()
	get_tree().create_timer(0.1).timeout.connect(func(): position_smoothing_enabled = true)


func set_shared(on: bool) -> void:
	enabled = on
	if on:
		make_current()
	for p in get_tree().get_nodes_in_group("players"):
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.enabled = not on
			if not on:
				cam.make_current()  


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var t = _target()
	if t != null:
		global_position = t


func _live_players() -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p is Walker:
			out.append(p)
	return out


func _target():
	var ps := _live_players()
	if ps.is_empty():
		return null

	# X: midpoint of the spread
	var min_x := INF
	var max_x := -INF
	for p in ps:
		min_x = minf(min_x, p.global_position.x)
		max_x = maxf(max_x, p.global_position.x)

	# Y: majority floor, ties broken by whoever is furthest right
	ps.sort_custom(func(a, b): return a.global_position.x > b.global_position.x)
	var counts := {}
	for p in ps:
		counts[p.floor_id] = counts.get(p.floor_id, 0) + 1
	var best_floor: int = ps[0].floor_id
	var best_count := 0
	for p in ps:
		if counts[p.floor_id] > best_count:
			best_count = counts[p.floor_id]
			best_floor = p.floor_id

	var sum := 0.0
	var n := 0
	for p in ps:
		if p.floor_id == best_floor:
			sum += p.elevation
			n += 1

	return Vector2((min_x + max_x) * 0.5, base_y + sum / n)
