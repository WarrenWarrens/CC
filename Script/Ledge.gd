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
## BOTH: one node does both. Draw the zone on the LOWER floor's base (like a climb). Walkers on the lower
##       floor climb it; walkers on the upper floor drop off the same spot, one `height` further up the screen.
##       Walking off the lip drops the floor id and starts the fall at once.
## Direction: climbing means pushing `climb_direction` (screen up by default); dropping is the opposite.
##
## Scene layout:  Ledge (Area2D, this script)  >  CollisionShape2D (a RectangleShape2D band ~20px thick)
## `height` is the screen distance between the two strips' facing edges (the same number a ladder spans).

enum Kind { CLIMB, DROP, BOTH }

@export var kind := Kind.CLIMB
@export var lower_floor := 1
@export var upper_floor := 2
## Wall height in screen px = floor difference. The camera moves by exactly this much.
@export var height := 102.0
## The way you push to climb. Screen up for a normal wall; use (1,0) etc. for a side-on wall.
@export var climb_direction := Vector2.UP
## How far INTO the destination floor the walker lands, so it isn't left standing on the very edge.
@export var landing_offset := 8.0
## Drops only: false = just walking into the edge drops you, true = you have to be airborne.
@export var drop_needs_jump := false
## Climbs only: false = you don't have to jump, just walk into the cliff and keep pushing up
## for `climb_hold_time` seconds and the walker vaults it. Only for walls up to `max_auto_climb_height`.
@export var climb_needs_jump := true
@export var climb_hold_time := 0.15
@export var max_auto_climb_height := 130.0
## Climbs: how far above the wall's lip the SPRITE may be and still count (a high jump, e.g. off a platform).
## The walker switches floors the moment its sprite is level with the lip, not when its shadow reaches the wall.
@export var max_early_reach := 200.0
## Drops: if the walker is in the air over the zone it falls to the lower floor without needing a key held.
@export var airborne_ignores_push := true
@export var mantle_reach := 28.0          # climbs: how far above its head a walker can grab
@export var mantle_time := 0.45
@export var mantle_animation := &"Mantle"

var _up := Vector2.UP    # climb_direction, normalised
var _hold := {}          # walker instance id -> seconds spent pushing into the cliff (auto climb)
var _probe := CircleShape2D.new()
const LOCK_MS := 350     # after a walker uses a ledge, no ledge may grab it again for this long (stops ping-pong)


func _ready() -> void:
	_probe.radius = 4.0
	monitoring = false       # we test the walkers ourselves (see _physics_process); the Area2D is just the zone's shape
	monitorable = false
	_up = climb_direction.normalized()


## Is this walker climbing from here, or dropping from here? Returns "" if neither applies on its floor.
func _mode_for(w: Walker) -> StringName:
	if kind != Kind.DROP and w.floor_id == lower_floor:
		return &"climb"
	if kind != Kind.CLIMB and w.floor_id == upper_floor:
		return &"drop"
	return &""


func _physics_process(delta: float) -> void:
	var active := {}
	var now := Time.get_ticks_msec()
	for node in get_tree().get_nodes_in_group("walkers"):
		var w := node as Walker
		if w == null or w.traversing or w.surface != null:
			continue
		var mode := _mode_for(w)
		if mode == &"":
			continue
		if int(w.get_meta(&"ledge_lock", 0)) > now:
			continue
		var lift := _sprite_lift(w) if mode == &"climb" else 0.0
		# the point we test is the feet, moved up by how far the sprite is above the lip
		var p := w.global_position - Vector2(0.0, lift)
		if mode == &"drop" and kind == Kind.BOTH:
			p += Vector2(0.0, height)   # the drop zone is the same band one wall-height further up the screen
		# fast walkers can step over a thin band in one frame, so look at where they are heading too
		if not (_zone_contains(p) or _zone_contains(p + w.velocity * delta)):
			continue
		if _wants_through(w, mode, delta, active):
			_use(w, mode, lift)
	for id in _hold.keys():
		if not active.has(id):
			_hold.erase(id)   # stopped pushing or left the zone: start over next time


## Climbs only: how many px the walker's sprite is above the lip (0 = at or below it).
func _sprite_lift(w: Walker) -> float:
	if w.altitude <= height:
		return 0.0
	return minf(w.altitude - height, max_early_reach)


func _zone_contains(p: Vector2) -> bool:
	for child in get_children():
		var cs := child as CollisionShape2D
		if cs != null and not cs.disabled and cs.shape != null:
			if cs.shape.collide(cs.global_transform, _probe, Transform2D(0.0, p)):
				return true
		var cp := child as CollisionPolygon2D
		if cp != null and not cp.disabled:
			if Geometry2D.is_point_in_polygon(cp.to_local(p), cp.polygon):
				return true
	return false


func _wants_through(w: Walker, mode: StringName, delta: float, active: Dictionary) -> bool:
	var airborne := w.altitude > 0.0 or w.z_velocity > 0.0
	var push := _up if mode == &"climb" else -_up
	var pushing := w.move_intent.normalized().dot(push) >= 0.5
	if mode == &"drop":
		if airborne and airborne_ignores_push:
			return true                       # in the air over the edge: you fall
		if drop_needs_jump and not airborne:
			return false
		return pushing
	if not pushing:
		return false
	if airborne:
		return w.altitude + mantle_reach >= height     # a jump that reaches the lip
	if climb_needs_jump or height > max_auto_climb_height:
		return false
	var id := w.get_instance_id()                       # walking: has to keep pushing for a moment
	_hold[id] = float(_hold.get(id, 0.0)) + delta
	active[id] = true
	return _hold[id] >= climb_hold_time


func _use(w: Walker, mode: StringName, lift := 0.0) -> void:
	var climbing := mode == &"climb"
	var dy := -height if climbing else height          # screen-Y change: up for a climb, down for a drop
	var inset := landing_offset * signf(dy)             # "into" the destination strip
	w.set_meta(&"ledge_lock", Time.get_ticks_msec() + LOCK_MS)
	if lift > 0.0:
		w.shift_level(-lift, 0.0)    # the sprite is already above the lip: move the feet up to where it is, sprite stays put
	w.floor_id = upper_floor if climbing else lower_floor
	w.shift_level(dy + inset, dy)
	w.refresh_z()
	if not climbing:
		return   # the sprite is now above its feet and Walker.air_step brings it down
	if lift > 0.0:
		w.altitude = maxf(w.altitude, 1.0)   # came in high: no mantle, the jump just carries on over the upper floor
		w.sync_body()
		return
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
