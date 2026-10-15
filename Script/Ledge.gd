class_name Ledge
extends Area2D
## A climb or a drop across the wall between two FLOORS, where there is no ramp.
##
## Picture the wall face between two strips of floor:
##
##     upper floor  ..........................   <- the LIP (top edge of the wall)
##     ============= wall face, `height` px ====
##     lower floor  ..........................   <- the BASE (bottom edge of the wall)
##
## CLIMB: the zone is a thin band on the LOWER floor, right along the base. Jump at the wall while
##        pushing up and the walker grabs the lip, climbs, and ends up on the upper floor (floor id goes up).
## DROP:  the zone is a thin band on the UPPER floor, right along the lip. Push down (or jump off, if
##        `drop_needs_jump`) and the walker falls to the lower floor (floor id goes down).
## For a wall you can climb AND jump off, use two Ledge nodes, one of each kind.
##
## Scene layout:  Ledge (Area2D, this script)  >  CollisionShape2D (a RectangleShape2D band ~20px thick)
## `height` is the screen distance between the two strips' facing edges (the same number a ladder spans).

enum Kind { CLIMB, DROP }

@export var kind := Kind.CLIMB
@export var lower_floor := 1
@export var upper_floor := 2
## Wall height in screen px = floor difference. The camera moves by exactly this much.
@export var height := 102.0
## How far INTO the destination floor the walker lands, so it isn't left standing on the very edge.
@export var landing_offset := 8.0
## Drops only: false = just walking into the edge drops you, true = you have to be airborne.
@export var drop_needs_jump := false
@export var mantle_reach := 28.0          # climbs: how far above its head a walker can grab
@export var mantle_time := 0.45
@export var mantle_animation := &"Mantle"

var _from_floor := 0
var _to_floor := 0
var _dy := 0.0           # screen-Y change to the other floor: negative = up (climb), positive = down (drop)
var _push := Vector2.UP  # the direction the walker has to be pushing


func _ready() -> void:
	if kind == Kind.CLIMB:
		_from_floor = lower_floor
		_to_floor = upper_floor
		_dy = -height
		_push = Vector2.UP
	else:
		_from_floor = upper_floor
		_to_floor = lower_floor
		_dy = height
		_push = Vector2.DOWN


func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		var w := b as Walker
		if w == null or w.traversing or w.surface != null or w.floor_id != _from_floor:
			continue
		if _wants_through(w):
			_use(w)


func _wants_through(w: Walker) -> bool:
	if w.move_intent.normalized().dot(_push) < 0.5:
		return false
	var airborne := w.altitude > 0.0 or w.z_velocity > 0.0
	if kind == Kind.CLIMB:
		# has to be a jump that reaches the lip
		return airborne and w.altitude + mantle_reach >= height
	return airborne if drop_needs_jump else true


func _use(w: Walker) -> void:
	var inset := landing_offset * signf(_dy)    # "into" the destination strip: up for a climb, down for a drop
	w.floor_id = _to_floor
	w.shift_level(_dy + inset, _dy)
	w.refresh_z()
	if kind == Kind.DROP:
		return   # the sprite is now above its feet and Walker.air_step brings it down
	w.begin_traversal()
	w.play_anim(mantle_animation)
	var tw := w.create_tween()
	tw.tween_method(_climb_step.bind(w, w.altitude), 0.0, 1.0, mantle_time).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_climb_done.bind(w))


func _climb_step(k: float, w: Walker, from_alt: float) -> void:
	if not is_instance_valid(w):
		return
	w.altitude = lerpf(from_alt, 0.0, k)
	w.sync_body()


func _climb_done(w: Walker) -> void:
	if not is_instance_valid(w):
		return
	w.altitude = 0.0
	w.z_velocity = 0.0
	w.sync_body()
	w.end_traversal()
