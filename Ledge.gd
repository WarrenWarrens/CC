class_name Ledge
extends Area2D
## A drop or climb between two FLOORS where there is no ramp (the wall face between two strips).
##
## Scene layout:
##   Ledge (Area2D, this script, collision layer 0 / mask 1)
##   '- CollisionPolygon2D   a band on the walkable strip of `from_floor`, hugging the edge you cross
##
## Drop:  zone on the UPPER strip's bottom edge.  dy = wall height (positive), push_dir = DOWN.
## Climb: zone on the LOWER strip's top edge.     dy = -wall height (negative), push_dir = UP.
## Measure the wall height in the editor: distance on screen between the two strips' facing edges.

enum Trigger { WALK_OFF, JUMP }

@export var from_floor := 1
@export var to_floor := 0
## Screen-Y change between the floors. Positive = to_floor is lower (a drop), negative = higher (a climb).
## The camera moves by exactly this much.
@export var dy := 120.0
## Extra Y added on arrival so you land inside the other strip, not on its very edge.
@export var landing_offset := 8.0
@export var trigger := Trigger.WALK_OFF   # drops only: walk off, or require a jump
@export var push_dir := Vector2.DOWN      # the direction the walker must be pushing
@export var mantle_reach := 28.0          # climbs: how far above its head a walker can grab
@export var mantle_time := 0.45
@export var mantle_animation := &"Mantle"


func _physics_process(_delta: float) -> void:
	for b in get_overlapping_bodies():
		var w := b as Walker
		if w == null or w.traversing or w.surface != null or w.floor_id != from_floor:
			continue
		if _wants_through(w):
			_use(w)


func _wants_through(w: Walker) -> bool:
	if w.move_intent.normalized().dot(push_dir.normalized()) < 0.5:
		return false
	var airborne := w.altitude > 0.0 or w.z_velocity > 0.0
	if dy < 0.0:
		# climbing: has to be a jump that reaches the lip
		return airborne and w.altitude + mantle_reach >= -dy
	return airborne if trigger == Trigger.JUMP else true


func _use(w: Walker) -> void:
	w.floor_id = to_floor
	w.shift_level(dy + landing_offset, dy)
	w.refresh_z()
	if dy >= 0.0:
		return   # a drop: the sprite is now above its feet and Walker.air_step brings it down
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
