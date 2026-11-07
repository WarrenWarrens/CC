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
##
## Zoom: the zoom_out / zoom_in keys step through `zoom_levels`. Zooming out grows the view up and sideways
## but keeps its BOTTOM edge where it was, so you never see further below the play area than at normal zoom.
## Nothing here assumes the 640x480 window: the view size is read from the viewport.

@export var base_y := 120.0          
@export var smoothing_speed := 8.0
@export var start_shared := true    

## The edges of the whole level, in pixels. The camera never shows past them.
@export var world_left := 0
@export var world_right := 5000
@export var world_top := -10000
@export var world_bottom := 10000

## 1.0 = normal. Smaller = zoomed out (0.5 shows twice as much). 0.5 and 0.75 stay sharp with pixel art at 640x480.
@export var zoom_levels: Array[float] = [1.0, 0.75, 0.5]
@export var zoom_time := 0.25

var _zoom_index := 0
var _zoom := 1.0                     # the zoom right now (animates between levels)
var _zoom_tween: Tween
var _applied_shift := 0.0            # how much of this camera's offset is currently the zoom shift


func _ready() -> void:
	add_to_group("level_camera")
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	limit_left = world_left
	limit_right = world_right
	limit_top = world_top
	limit_bottom = world_bottom
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_out"):
		set_zoom_level(_zoom_index + 1)
	elif event.is_action_pressed("zoom_in"):
		set_zoom_level(_zoom_index - 1)


## Goes to an entry of zoom_levels (0 = normal). Out-of-range numbers stop at the ends.
func set_zoom_level(index: int) -> void:
	_zoom_index = clampi(index, 0, zoom_levels.size() - 1)
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "_zoom", zoom_levels[_zoom_index], zoom_time).set_trans(Tween.TRANS_SINE)


## Zooms, and moves the view's centre up so its bottom edge stays put (the view grows upward).
## This uses the camera's offset, which is not smoothed, so the bottom edge never lags behind while the zoom animates.
## (It adds to the offset instead of replacing it, so the bottom stat bar's own offset is kept.)
func _apply_zoom() -> void:
	zoom = Vector2(_zoom, _zoom)
	var shift := get_viewport_rect().size.y * 0.5 * (1.0 - 1.0 / _zoom)
	offset.y += shift - _applied_shift
	_applied_shift = shift


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
	_apply_zoom()
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
