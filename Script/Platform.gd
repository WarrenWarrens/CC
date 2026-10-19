class_name Platform
extends StaticBody2D
## A raised block you jump onto (stepping stones, crates, a low wall you can climb).
##
## Two shapes describe it:
##   Wall  (CollisionPolygon2D) where the block touches the ground. It is SOLID: walkers bump into it
##                              and have to jump over it. Rename your existing "CollisionPolygon2D" to "Wall"
##                              (or leave it, the old name still works).
##   Top   (Polygon2D)          where you can WALK on top, drawn in screen space (so it sits `height` px above
##                              the wall). It is a Polygon2D, NOT a collision shape, so it never blocks anything.
##                              It is coloured in the editor so you can see it, and hidden in game.
##
## If there is no Top node, the top is the Wall shape moved up by `height` (the old behaviour).
## Put the node's origin on the FRONT edge of the base, make it a direct child of your y-sorted root,
## and set z_index = floor*10 + 5.
##
## Heights up to ~88 can be jumped onto. Between 84 and (88 + mantle_reach) the walker grabs the edge and climbs.
## Taller than that = plain wall.

@export var floor_id := 0
## How tall the block is in screen px. Ignored (calculated for you) when `derive_height` is on and a Top exists.
@export var height := 50.0
## With a Top shape: height = how far the Top sits above the Wall (centre to centre).
@export var derive_height := true
## How far the camera rises while standing on this platform. Leave 0 for the first stones in a sequence
## and set the last one to the total climb, so the camera only shifts at the end.
@export var camera_rise := 0.0
@export var mantle_reach := 28.0     # how far above its head a walker can grab
@export var grab_distance := 14.0    # how close to the wall edge counts as "touching the wall"
@export var mantle_time := 0.45
@export var mantle_animation := &"Mantle"   # optional animation name on Visuals/Body
@export var show_top_in_game := false       # debug: keep the green Top shape visible while playing

var _wall := PackedVector2Array()
var _top := PackedVector2Array()
var _top_centroid := Vector2.ZERO
var _passable := {}   # walker instance id -> bool, so exceptions are only changed when they flip


func _ready() -> void:
	add_to_group("platforms")

	var wall_node := get_node_or_null("Wall") as CollisionPolygon2D
	if wall_node == null:
		wall_node = get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if wall_node == null:
		push_error("Platform '%s' needs a CollisionPolygon2D child named Wall (the solid base)." % name)
		return
	_wall = _polygon_to_global(wall_node, wall_node.polygon)

	var top_node := get_node_or_null("Top") as Polygon2D
	if top_node != null and top_node.polygon.size() >= 3:
		_top = _polygon_to_global(top_node, top_node.polygon)
		top_node.visible = show_top_in_game
		if derive_height:
			height = _centroid(_wall).y - _centroid(_top).y
			if height <= 0.0:
				push_warning("Platform '%s': the Top shape should be drawn ABOVE the Wall shape." % name)
	else:
		for p in _wall:
			_top.append(p + Vector2(0.0, -height))
	_top_centroid = _centroid(_top)


func _polygon_to_global(node: Node2D, poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(node.to_global(p))
	return out


func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / maxf(poly.size(), 1)


func wall_contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _wall)


func top_contains(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _top)


func _mantlable() -> bool:
	return height > Walker.JUMP_APEX - 4.0 and height <= Walker.JUMP_APEX + mantle_reach


func _closest_on(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := poly[0]
	var best_d := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


## Called by Walker.air_step while falling. Lands on the top if we cross its plane above the walkable area.
func try_land(w: Walker, prev_ground_alt: float) -> bool:
	if w.floor_id != floor_id or w.surface == self or w.traversing:
		return false
	if prev_ground_alt < height or w.ground_altitude() > height:
		return false
	# where our feet would be on the top plane must be inside the walkable Top shape
	if not top_contains(w.ground_pos() - Vector2(0.0, height)):
		return false
	w.set_surface(self)
	w.altitude = 0.0
	w.z_velocity = 0.0
	w.sync_body()
	return true


## Called every frame by Walker.update_floor_state: lets walkers pass through the wall when they are above
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
	if wall_contains(g) or g.distance_to(_closest_on(_wall, g)) > grab_distance:
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
	var on_top_plane := g - Vector2(0.0, height)           # where we would be on the top plane
	var edge := _closest_on(_top, on_top_plane)            # nearest point of the walkable area
	var inward := (_top_centroid - edge).normalized()
	var target := edge + inward * 10.0                     # feet position on top, a little in from the lip
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
