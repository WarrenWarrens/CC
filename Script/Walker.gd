class_name Walker
extends CharacterBody2D

const FLOOR_Z_STEP := 10        # every floor owns a band of 10 z_index values
const FLOOR_Z_CHARACTER := 5    # characters sit at floor * 10 + 5

## The floor this character stands on. Ramps change it as it walks over them, so you
## only need to set it on characters that START on a floor other than 0.
@export var floor_id := 0

## Screen-Y shift collected from ramps (negative = higher up). The player's camera follows this.
var elevation := 0.0

var ramps: Array[Ramp] = []
var _tracked_ramp: Ramp = null
var _tracked_progress := 0.0


func enter_ramp(r: Ramp) -> void:
	if not ramps.has(r):
		ramps.append(r)


func exit_ramp(r: Ramp) -> void:
	ramps.erase(r)


## Newest overlapping ramp that actually connects the floor we are on.
## (Ramps of other floors can overlap on screen; those are ignored.)
func get_active_ramp() -> Ramp:
	# Stick with the ramp we are already climbing, even if another ramp overlaps it on screen.
	if _tracked_ramp != null and ramps.has(_tracked_ramp):
		return _tracked_ramp
	# Otherwise only accept a ramp whose END for our current floor we are standing at.
	for i in range(ramps.size() - 1, -1, -1):
		var r: Ramp = ramps[i]
		var end := r.end_progress_for(floor_id)
		if end >= 0.0 and absf(r.progress_at(global_position) - end) < 0.4:
			return r
	return null


func get_slope() -> float:
	var r: Ramp = get_active_ramp()
	return r.get_slope() if r else 0.0


func is_grounded() -> bool:
	return true


# Call on any velocity you assign fresh each frame.
func ramp_adjust(v: Vector2) -> Vector2:
	if is_grounded():
		v.y += v.x * get_slope()
	return v


## Call once per physics frame (Player and Enemy _physics_process).
## Remembers the floor, accumulates camera elevation along the path actually walked,
## and sets z_index from the floor.
func update_floor_state() -> void:
	var r: Ramp = get_active_ramp()
	if r != _tracked_ramp:
		_leave_tracked_ramp()
		_tracked_ramp = r
		if r:
			# we stepped on from one of the ends, so start from 0 or 1
			_tracked_progress = roundf(r.progress_at(global_position))

	if _tracked_ramp:
		var p := _tracked_ramp.progress_at(global_position)
		elevation += _tracked_ramp.rise * (p - _tracked_progress)
		_tracked_progress = p
		floor_id = _tracked_ramp.floor_at(p)

	var z := floor_id * FLOOR_Z_STEP + FLOOR_Z_CHARACTER
	if z != z_index:
		z_index = z


# Settle on whichever end of the ramp we left from, so elevation never drifts.
func _leave_tracked_ramp() -> void:
	if _tracked_ramp == null:
		return
	var end := roundf(_tracked_progress)
	elevation += _tracked_ramp.rise * (end - _tracked_progress)
	floor_id = _tracked_ramp.floor_at(end)
	_tracked_ramp = null
