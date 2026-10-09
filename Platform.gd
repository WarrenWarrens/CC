class_name Platform
extends StaticBody2D
## A raised block you jump onto (stepping stones, crates, a low wall you can climb).
##
## Scene layout:
##   Platform (StaticBody2D, this script)   <- put its origin on the FRONT edge of the base, and make it a direct
##   |                                         child of your y-sorted root. Set z_index = floor*10 + 5.
##   |- CollisionPolygon2D   the BASE footprint on the ground (where it touches the floor). Build mode: Solids.
##   '- Sprite2D (or any art) drawn above the origin
##
## The top surface is the base moved up by `height`. Heights up to ~88 can be jumped onto.
## Between 84 and (88 + mantle_reach) the walker grabs the edge and climbs. Taller than that = plain wall.

@export var floor_id := 0
## How tall the block is in screen px.
@export var height := 50.0
## How far the camera rises while standing on this platform. Leave 0 for the first stones in a sequence
## and set the last one to the total climb, so the camera only shifts at the end.
@export var camera_rise := 0.0
@export var mantle_reach := 28.0     # how far above its head a walker can grab
@export var grab_distance := 14.0    # how close to the base edge counts as "touching the wall"
@export var mantle_time := 0.45
@export var mantle_animation := &"Mantle"   # optional animation name on Visuals/Body

var _base := PackedVector2Array()
var _top := PackedVector2Array()
var _centroid := Vector2.ZERO
var _passable := {}   # walker instance id -> bool, so exceptions are only changed when they flip


func _ready() -> void:
	add_to_group("platforms")
	var poly := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if poly == null:
		push_error("Platform '%s' needs a CollisionPolygon2D child (the base footprint)." % name)
		return
	var sum := Vector2.ZERO
	for p in poly.polygon:
		var g := poly.to_global(p)
		_base.append(g)
		_top.append(g + Vector2(0.0, -height))
		sum += g
	_centroid = sum / _base.size()


func base_contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _base)


func top_contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _top)


func _mantlable() -> bool:
	return height > Walker.JUMP_APEX - 4.0 and height <= Walker.JUMP_APEX + mantle_reach


func _closest_on_base(p: Vector2) -> Vector2:
	var best := _base[0]
	var best_d := INF
	for i in _base.size():
		var q := Geometry2D.get_closest_point_to_segment(p, _base[i], _base[(i + 1) % _base.size()])
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


## Called by Walker.air_step while falling. Lands on the top if we cross its plane above the base.
func try_land(w: Walker, prev_ground_alt: float) -> bool:
	if w.floor_id != floor_id or w.surface == self or w.traversing:
		return false
	if prev_ground_alt < height or w.ground_altitude() > height:
		return false
	if not base_contains(w.ground_pos()):
		return false
	w.set_surface(self)
	w.altitude = 0.0
	w.z_velocity = 0.0
	w.sync_body()
	return true


## Called every frame by Walker.update_floor_state: lets walkers pass through the base when they are above
## it, and starts a mantle when they are airborne against a wall they can just reach.
func update_for(w: Walker) -> void:
	if w.floor_id != floor_id:
		_set_passable(w, true)
		return
	var g_alt := w.ground_altitude()
	var passable := w.surface != null or g_alt >= height - 1.0
	_set_passable(w, passable)
	if passable or w.traversing or not _mantlable():
		return
	if g_alt <= 0.0 and w.z_velocity <= 0.0:
		return   # on the ground: walking into a wall does nothing, you have to jump
	if g_alt + mantle_reach < height:
		return
	var g := w.ground_pos()
	if base_contains(g) or g.distance_to(_closest_on_base(g)) > grab_distance:
		return
	_mantle(w, g)


func _set_passable(w: Walker, passable: bool) -> void:
	var id := w.get_instance_id()
	if _passable.get(id, false) == passable:
		return
	_passable[id] = passable
	if passable:
		w.add_collision_exception_with(self)
	else:
		w.remove_collision_exception_with(self)


func _mantle(w: Walker, g: Vector2) -> void:
	var edge := _closest_on_base(g)
	var inward := (_centroid - edge).normalized()
	var target := edge + inward * 10.0 - Vector2(0.0, height)   # feet position on top, a little in from the lip
	w.begin_traversal()
	w.set_surface(self)       # feet jump up by `height`; the sprite now hangs below them
	w.play_anim(mantle_animation)
	var tw := w.create_tween()
	tw.tween_method(_mantle_step.bind(w, w.global_position, target, w.altitude), 0.0, 1.0, mantle_time) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_mantle_done.bind(w))


func _mantle_step(k: float, w: Walker, from_pos: Vector2, to_pos: Vector2, from_alt: float) -> void:
	if not is_instance_valid(w):
		return
	w.global_position = from_pos.lerp(to_pos, k)
	w.altitude = lerpf(from_alt, 0.0, k)
	w.sync_body()


func _mantle_done(w: Walker) -> void:
	if not is_instance_valid(w):
		return
	w.altitude = 0.0
	w.z_velocity = 0.0
	w.sync_body()
	w.end_traversal()
