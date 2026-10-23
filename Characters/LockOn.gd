class_name LockOn
extends Node2D
## Lock-on targeting for one Player (Zelda / Dark Souls style). The Player creates it in _ready.
##
## Targets come from the player's DetectZone (the big circle): any enemy in it, alive, on the same floor.
## While `target` is set the player faces it, backs away slower, and its shots aim at it (see Player.gd).
## The marker above the target is drawn by this node, so no art is needed.

@export var marker_height := 70.0       # how far above the enemy's feet the marker floats
@export var marker_color := Color(1.0, 0.3, 0.25)

var target: Enemy = null
var _player: Walker
var _zone: Area2D
var _time := 0.0


func setup(player: Walker, zone: Area2D) -> void:
	_player = player
	_zone = zone
	zone.collision_layer = 0
	zone.collision_mask = 2        # layer 2 = enemy hurtboxes, so the zone only sees things that can be hit
	top_level = true               # we are positioned in the world, not relative to the player
	z_as_relative = false
	z_index = 200                  # on top of everything


## The lock-on button: lock the nearest enemy, or let go of the current one.
func toggle() -> void:
	if target != null:
		target = null
		return
	var best: Enemy = null
	for e in _candidates():
		if best == null or _dist(e) < _dist(best):
			best = e
	target = best
	if best != null:
		Audio.play(&"lock", -6.0)


## The cycle button: the next enemy to the right of the current one, wrapping around. With no target it locks the nearest.
func cycle() -> void:
	var list := _candidates()
	if list.is_empty():
		return
	if target == null:
		toggle()
		return
	list.sort_custom(func(a: Enemy, b: Enemy): return a.global_position.x < b.global_position.x)
	target = list[(list.find(target) + 1) % list.size()]
	Audio.play(&"lock", -6.0)


## -1 / +1 = which way the player has to face to look at the target, 0 = no target.
func facing_toward() -> float:
	if target == null:
		return 0.0
	return signf(target.global_position.x - _player.global_position.x)


## Where shots should go: the middle of the target's hurtbox.
func aim_point() -> Vector2:
	var shape := target.get_node_or_null("Visuals/Hurtbox/CollisionShape2D") as Node2D
	return shape.global_position if shape else target.global_position + Vector2(0.0, -21.0)


func _physics_process(delta: float) -> void:
	_time += delta
	if target != null and not _candidates().has(target):
		target = null          # it died, left the zone, or changed floor
	visible = target != null
	if target != null:
		global_position = target.global_position + Vector2(0.0, -marker_height - target.altitude + sin(_time * 6.0) * 2.0)
		queue_redraw()


func _candidates() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for area in _zone.get_overlapping_areas():
		var e := area.owner as Enemy
		if e != null and not out.has(e) and e.current_state != Enemy.State.DEAD and e.floor_id == _player.floor_id:
			out.append(e)
	return out


func _dist(e: Enemy) -> float:
	return _player.global_position.distance_squared_to(e.global_position)


func _draw() -> void:
	var tri := PackedVector2Array([Vector2(-7, -8), Vector2(7, -8), Vector2(0, 4)])   # a small arrow pointing down
	draw_colored_polygon(tri, marker_color)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.WHITE, 1.5)
