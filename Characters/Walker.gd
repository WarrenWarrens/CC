class_name Walker
extends CharacterBody2D

const FLOOR_Z_STEP := 10        # every floor owns a band of 10 z_index values
const FLOOR_Z_CHARACTER := 5    # characters sit at floor * 10 + 5 (+1 while standing on a platform)
const GRAVITY := 900.0
const JUMP_APEX := 88.0         # highest a normal jump reaches: JUMP_FORCE^2 / (2 * GRAVITY)
const FLOOR_LAYER_FIRST := 9    # physics layer 9 = walls of floor 0, layer 10 = floor 1 ... up to floor 7 (layer 16)
## How many physics layers the floor walls use. A level can have MORE floors than this: floor 8 reuses floor 0's
## layer, floor 9 reuses floor 1's, and so on (see floor_bit). That is safe as long as floors that share a layer
## are far apart in the world, which they are in a tower where every floor sits above the last.
const FLOOR_LAYERS := 8
const FLOOR_LAYER_BITS := 0xFF << (FLOOR_LAYER_FIRST - 1)

## The floor this character stands on. Ramps, ledges and ladders change it as it moves,
## so you only need to set it on characters that START on a floor other than 0.
@export var floor_id := 0

## Screen-Y shift from ramps/ledges/platforms (negative = higher up). The player's camera follows this.
var elevation := 0.0

## Pixels above the surface we are standing on. The sprite is drawn this far above the feet.
var altitude := 0.0
var z_velocity := 0.0

## The platform we stand on (null = the floor). While on one, our position is in "top surface" space:
## surface_h px higher on screen than the same spot on the ground.
var surface: Platform = null
var surface_h := 0.0
var surface_camera := 0.0

## True while a mantle / ladder / ledge climb is moving us. Skip input, AI and physics while it is set.
var traversing := false

## What the player is pressing / what the AI wants, as a direction (set it every frame, even while traversing).
var move_intent := Vector2.ZERO

var ramps: Array[Ramp] = []
var _tracked_ramp: Ramp = null
var _tracked_progress := 0.0
## Where this walker was placed when the level started. Doors can use it to frame the camera the same way (see Door.auto_elevation).
var start_y := 0.0
var _base_mask := 0     # the collision mask set in the scene, without the per-floor wall bits


## The collision-mask bit for the walls of one floor. Floors repeat every FLOOR_LAYERS (floor 9 uses floor 1's bit).
static func floor_bit(f: int) -> int:
	return 1 << (FLOOR_LAYER_FIRST - 1 + posmod(f, FLOOR_LAYERS))


func _enter_tree() -> void:
	add_to_group("walkers")
	start_y = global_position.y
	_base_mask = collision_mask & ~FLOOR_LAYER_BITS
	refresh_collision()


## Which walls we collide with depends on the floor we are on: the scene's own mask, plus the walls of THIS floor.
## On a platform top we ignore the ground walls (layer 1) and all floor walls; the platform's edge is handled by top_contains.
func refresh_collision() -> void:
	var m := _base_mask
	if surface != null:
		m &= ~1
	else:
		m |= floor_bit(floor_id)
	if m != collision_mask:
		collision_mask = m


# --- ramps ------------------------------------------------------------------

func enter_ramp(r: Ramp) -> void:
	if not ramps.has(r):
		ramps.append(r)


func exit_ramp(r: Ramp) -> void:
	ramps.erase(r)


## Newest overlapping ramp that actually connects the floor we are on.
func get_active_ramp() -> Ramp:
	if surface != null:
		return null
	# Stick with the ramp we are already climbing, even if another ramp overlaps it on screen.
	if _tracked_ramp != null and ramps.has(_tracked_ramp):
		return _tracked_ramp
	# Otherwise only accept a ramp whose END for our current floor we are standing at.
	for i in range(ramps.size() - 1, -1, -1):
		var r: Ramp = ramps[i]
		var end := r.end_progress_for(floor_id)
		if end >= 0.0 and absf(r.progress_at(global_position) - end) < 0.4:
			return r
	_warn_floor_mismatch()
	return null


var _warned_ramps := {}

## One-time warning when we stand at the end of a ramp that doesn't join our floor. Usually that means
## floor_id is out of sync (wrong starting floor on a Player/Enemy, or a ramp with the wrong floor numbers).
func _warn_floor_mismatch() -> void:
	for r in ramps:
		if _warned_ramps.has(r) or r.connects(floor_id):
			continue
		var progress := r.progress_at(global_position)
		if progress < 0.25 or progress > 0.75:
			_warned_ramps[r] = true
			push_warning("%s is at the end of ramp '%s' (joins floors %d and %d) but its floor_id is %d. If it should be able to use that ramp, its floor_id is out of sync. (Harmless if the ramps just overlap on screen.)" % [name, r.name, r.low_floor, r.high_floor, floor_id])


func get_slope() -> float:
	var r: Ramp = get_active_ramp()
	return r.get_slope() if r else 0.0


func is_grounded() -> bool:
	return altitude <= 0.0


# Call on any velocity you assign fresh each frame.
func ramp_adjust(v: Vector2) -> Vector2:
	if is_grounded():
		v.y += v.x * get_slope()
	return v


# --- height above the surface ------------------------------------------------

## Where our feet are on the ground, ignoring any platform we stand on.
func ground_pos() -> Vector2:
	return global_position + Vector2(0.0, surface_h)


## Height above the ground (not above the platform).
func ground_altitude() -> float:
	return altitude + surface_h


func sync_body() -> void:
	var body := get_node_or_null("Visuals/Body") as Node2D
	if body:
		body.position.y = -altitude


func play_anim(anim: StringName) -> void:
	var body := get_node_or_null("Visuals/Body") as AnimatedSprite2D
	if body and body.sprite_frames and body.sprite_frames.has_animation(anim):
		body.play(anim)


## Moves the feet dy screen px (negative = up) WITHOUT the sprite visibly jumping:
## the difference goes into `altitude`. camera_dy is how much the camera should follow.
func shift_level(dy: float, camera_dy: float) -> void:
	global_position.y += dy
	altitude += dy
	elevation += camera_dy
	sync_body()


## Stand on a platform (or on the ground again with null). Position, altitude, camera and collisions follow.
func set_surface(p: Platform) -> void:
	var new_h := p.height if p else 0.0
	var new_cam := p.camera_rise if p else 0.0
	shift_level(surface_h - new_h, surface_camera - new_cam)
	surface = p
	surface_h = new_h
	surface_camera = new_cam
	refresh_z()   # also updates the collision mask


## One physics step of gravity. Call it every frame (Player: in every state; Enemy: at the top of _physics_process).
## Returns true on the frame we touch down, on the floor or on a platform.
func air_step(delta: float) -> bool:
	if traversing or (altitude <= 0.0 and z_velocity <= 0.0):
		return false
	var prev_ground_alt := ground_altitude()
	z_velocity -= GRAVITY * delta
	altitude += z_velocity * delta
	if z_velocity < 0.0:
		for p in get_tree().get_nodes_in_group("platforms"):
			if (p as Platform).try_land(self, prev_ground_alt):
				return true
	if altitude <= 0.0:
		altitude = 0.0
		z_velocity = 0.0
		sync_body()
		return true
	sync_body()
	return false


# --- traversal (mantle, ladder, ledge) ----------------------------------------

func begin_traversal() -> void:
	traversing = true
	velocity = Vector2.ZERO


func end_traversal() -> void:
	traversing = false
	_traversal_done()


## Override in Player / Enemy to return to a normal state.
func _traversal_done() -> void:
	pass


# --- per-frame bookkeeping ------------------------------------------------------

func refresh_z() -> void:
	var z := floor_id * FLOOR_Z_STEP + FLOOR_Z_CHARACTER + (1 if surface != null else 0)
	if z != z_index:
		z_index = z
	refresh_collision()


## Call once per physics frame (Player and Enemy _physics_process), after moving.
func update_floor_state() -> void:
	if traversing:
		return

	# Walked off the edge of a platform?
	if surface != null and not surface.top_contains(global_position):
		set_surface(null)

	for p in get_tree().get_nodes_in_group("platforms"):
		(p as Platform).update_for(self)

	# Ramps: remember the floor, accumulate camera elevation along the path actually walked.
	var r: Ramp = get_active_ramp()
	if r != _tracked_ramp:
		_leave_tracked_ramp()
		_tracked_ramp = r
		if r:
			# we stepped on from one of the ends, so start from 0 or 1
			_tracked_progress = roundf(r.progress_at(global_position))

	if _tracked_ramp:
		var progress := _tracked_ramp.progress_at(global_position)
		elevation += _tracked_ramp.rise * (progress - _tracked_progress)
		_tracked_progress = progress
		floor_id = _tracked_ramp.floor_at(progress)

	refresh_z()


# Settle on whichever end of the ramp we left from, so elevation never drifts.
func _leave_tracked_ramp() -> void:
	if _tracked_ramp == null:
		return
	var end := roundf(_tracked_progress)
	elevation += _tracked_ramp.rise * (end - _tracked_progress)
	floor_id = _tracked_ramp.floor_at(end)
	_tracked_ramp = null
