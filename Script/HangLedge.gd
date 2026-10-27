class_name HangLedge
extends Area2D
## A ledge you HANG from (Metal Gear Solid 2 style), on the edge of an upper floor.
##
##     upper floor  ..........................   <- the LIP: you hang from here
##     ============= wall face, `height` px ====
##     lower floor  ..........................   <- the BASE: the zone is drawn here, like a Ledge
##
## Getting on:   from the LOWER floor, jump at the wall below the lip and you grab it.
##               from the UPPER floor, stand at the edge and hold down: you lower yourself onto it.
## While hanging: left / right shuffles along the ledge, down lets go (you fall to the lower floor),
##                up climbs onto the upper floor, but ONLY in the climbable sections.
##
## Scene layout:  HangLedge (this script)  >  one or more CollisionShape2D bands drawn on the lower floor's base.
##   - Every shape is part of the ledge: the player can hang anywhere along it.
##   - A shape whose NAME STARTS WITH "Climb" is a climbable section (e.g. "ClimbZone"). Put it inside a longer
##     "HangRange" shape and the player can only climb in the middle. Make a shape named "Climb..." and nothing
##     else for a ledge that can always be climbed, or no "Climb" shape at all for one that never can.
##
## Animations (all optional, on the character's SpriteFrames): "Hang", "HangMove" (shuffling), "Mantle" (climbing up).
## Characters can't be hurt while hanging, the same as on a ladder.

@export var lower_floor := 1
@export var upper_floor := 2
## Wall height in screen px: the same number as a Ledge or Ladder between these floors.
@export var height := 102.0
## How far above the feet the hands are. Decides how far below the lip the character hangs.
@export var hands_height := 60.0
## How far below the lip a jump can still catch it.
@export var grab_reach := 14.0
@export var can_grab_from_below := true
@export var can_hang_from_above := true
@export var hang_speed := 70.0           # px/s shuffling sideways
@export var enter_hold_time := 0.2       # seconds of holding down at the lip before you lower yourself
@export var landing_offset := 8.0        # climbing up: how far onto the upper floor you end up
@export var mantle_time := 0.45
@export var mantle_animation := &"Mantle"
@export var hang_animation := &"Hang"
@export var shuffle_animation := &"HangMove"

const LOCK_MS := 450      # after letting go or climbing, no ledge may grab this walker again for this long

var _probe := CircleShape2D.new()
var _hanging := {}        # Walker -> { "armed": bool }
var _hold := {}           # Walker -> seconds holding down at the lip


func _ready() -> void:
	_probe.radius = 2.0
	monitoring = false     # walkers are tested by position, the shapes only describe the zone
	monitorable = false


func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	for node in get_tree().get_nodes_in_group("players"):
		var w := node as Walker
		if w == null or w.traversing or w.surface != null or int(w.get_meta(&"ledge_lock", 0)) > now:
			_hold.erase(node)
			continue
		if w.floor_id == lower_floor and can_grab_from_below and _can_grab(w):
			_start(w, false)
		elif w.floor_id == upper_floor and can_hang_from_above and _wants_to_lower(w, delta):
			_start(w, true)
	for w in _hanging.keys():
		if is_instance_valid(w):
			_hang(w, delta)
		else:
			_hanging.erase(w)


# --- getting on --------------------------------------------------------------------

## In the air at the base of the wall with the hands near the lip.
func _can_grab(w: Walker) -> bool:
	if w.altitude <= 0.0 and w.z_velocity <= 0.0:
		return false
	return w.altitude + hands_height + grab_reach >= height and w.altitude <= height + 20.0 \
		and _in_zone(w.global_position, false)


## On the ground at the lip (the zone, one wall-height further up the screen), holding down.
func _wants_to_lower(w: Walker, delta: float) -> bool:
	if w.altitude > 0.0 or w.move_intent.y < 0.5 or not _in_zone(w.global_position + Vector2(0.0, height), false):
		_hold.erase(w)
		return false
	_hold[w] = float(_hold.get(w, 0.0)) + delta
	return _hold[w] >= enter_hold_time


func _start(w: Walker, from_above: bool) -> void:
	_hold.erase(w)
	w.begin_traversal()
	w.hanging = true
	if from_above:
		w.floor_id = lower_floor
		w.shift_level(height, height)    # feet down to the base, camera follows, the sprite stays where it was
	w.z_velocity = 0.0
	w.refresh_z()
	w.play_anim(hang_animation)
	_hanging[w] = {"armed": false}       # "armed" once the stick has been let go, so the down that lowered you doesn't also drop you


# --- hanging -----------------------------------------------------------------------

func _hang(w: Walker, delta: float) -> void:
	var intent := w.move_intent
	var state: Dictionary = _hanging[w]
	if absf(intent.y) < 0.3:
		state["armed"] = true

	# hold the sprite with its hands at the lip
	w.altitude = move_toward(w.altitude, height - hands_height, 300.0 * delta)
	w.sync_body()

	if absf(intent.x) > 0.2:
		var next := w.global_position + Vector2(signf(intent.x) * hang_speed * delta, 0.0)
		if _in_zone(next, false):
			w.global_position = next
		if w.has_method("face"):
			w.face(signf(intent.x))
		w.play_anim(shuffle_animation)
	else:
		w.play_anim(hang_animation)

	if not state["armed"]:
		return
	if intent.y > 0.5:
		_let_go(w)
	elif intent.y < -0.5 and _in_zone(w.global_position, true):
		_climb(w)


func _let_go(w: Walker) -> void:
	_release(w)
	w.end_traversal()    # gravity takes over from here: the altitude is still above the ground


func _release(w: Walker) -> void:
	_hanging.erase(w)
	w.hanging = false
	w.set_meta(&"ledge_lock", Time.get_ticks_msec() + LOCK_MS)


func _climb(w: Walker) -> void:
	_release(w)
	w.floor_id = upper_floor
	w.shift_level(-height - landing_offset, -height)    # feet up onto the upper floor; the sprite is left hanging below them
	w.refresh_z()
	w.play_anim(mantle_animation)
	var tween := w.create_tween()
	tween.tween_method(_climb_step.bind(w, w.altitude), 0.0, 1.0, mantle_time).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_climb_done.bind(w))


func _climb_step(k: float, w: Walker, from_altitude: float) -> void:
	if not is_instance_valid(w):
		return
	w.altitude = lerpf(from_altitude, 0.0, k)
	w.sync_body()


func _climb_done(w: Walker) -> void:
	if not is_instance_valid(w):
		return
	w.altitude = 0.0
	w.z_velocity = 0.0
	w.sync_body()
	w.end_traversal()


# --- the zone -----------------------------------------------------------------------

## Is the point inside the ledge? `climb_only` = only the sections whose name starts with "Climb".
func _in_zone(p: Vector2, climb_only: bool) -> bool:
	for child in get_children():
		if climb_only and not String(child.name).begins_with("Climb"):
			continue
		var cs := child as CollisionShape2D
		if cs != null and not cs.disabled and cs.shape != null:
			if cs.shape.collide(cs.global_transform, _probe, Transform2D(0.0, p)):
				return true
		var cp := child as CollisionPolygon2D
		if cp != null and not cp.disabled:
			if Geometry2D.is_point_in_polygon(cp.to_local(p), cp.polygon):
				return true
	return false
