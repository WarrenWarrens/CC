class_name Ladder
extends Node2D
## A vertical ladder between two floors.
##
## Scene layout:
##   Ladder (Node2D, this script)
##   |- Bottom (Marker2D)   where feet stand at the foot of the ladder (on the lower floor)
##   |- Top    (Marker2D)   where feet stand at the top (on the upper floor), straight above Bottom
##   '- Sprite2D            the ladder art
##
## Stand at the bottom and press up to climb; stand at the top and press down to climb down.
## The camera follows because the climb adds exactly (Top.y - Bottom.y) to the walker's elevation.

@export var bottom_floor := 0
@export var top_floor := 1
@export var climb_speed := 90.0    # screen px per second
@export var grab_radius := 14.0
@export var climb_animation := &"Climb"   # optional animation name on Visuals/Body

@onready var bottom: Marker2D = $Bottom
@onready var top: Marker2D = $Top

var _climbers := {}   # Walker -> progress along the ladder, 0 = bottom, 1 = top


func _physics_process(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("walkers"):
		var w := node as Walker
		if w == null or _climbers.has(w) or w.traversing or w.surface != null or w.altitude > 0.0:
			continue
		if w.floor_id == bottom_floor and w.move_intent.y < -0.5 \
				and w.global_position.distance_to(bottom.global_position) < grab_radius:
			_start(w, 0.0)
		elif w.floor_id == top_floor and w.move_intent.y > 0.5 \
				and w.global_position.distance_to(top.global_position) < grab_radius:
			_start(w, 1.0)

	for w in _climbers.keys():
		if not is_instance_valid(w):
			_climbers.erase(w)
			continue
		_climb(w, delta)


func _start(w: Walker, progress: float) -> void:
	_climbers[w] = progress
	w.begin_traversal()
	w.global_position = bottom.global_position.lerp(top.global_position, progress)
	w.play_anim(climb_animation)


func _climb(w: Walker, delta: float) -> void:
	var length := maxf(bottom.global_position.distance_to(top.global_position), 1.0)
	var dir := -w.move_intent.y   # pushing up the screen = toward the top
	var p: float = _climbers[w]
	var new_p := clampf(p + dir * climb_speed * delta / length, 0.0, 1.0)

	var old_y := w.global_position.y
	w.global_position = bottom.global_position.lerp(top.global_position, new_p)
	w.elevation += w.global_position.y - old_y
	_climbers[w] = new_p

	if new_p >= 1.0 and dir > 0.0:
		_finish(w, top_floor)
	elif new_p <= 0.0 and dir < 0.0:
		_finish(w, bottom_floor)


func _finish(w: Walker, floor_number: int) -> void:
	_climbers.erase(w)
	w.floor_id = floor_number
	w.refresh_z()
	w.end_traversal()
