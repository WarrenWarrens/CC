extends Node2D

@export var radius := 14.0
@export_range(0.1, 1.0) var squash := 0.35           
@export var color := Color(0, 0, 0, 0.35)
@export var max_altitude := 90.0                     
@export_range(0.0, 2.0) var min_scale := 0.45        
@export_range(0.0, 1.0) var min_alpha_mult := 0.5     
@export var slope_follow_speed := 20.0              

@onready var _body := get_parent()


func _process(delta: float) -> void:
	var altitude := 0.0
	if "altitude" in _body:
		altitude = _body.altitude
	var t := clampf(altitude / max_altitude, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(1.0, min_scale, t)
	modulate.a = lerpf(1.0, min_alpha_mult, t)

	var target_rotation := 0.0
	if _body.has_method("get_slope"):
		target_rotation = atan(_body.get_slope())    
	rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-slope_follow_speed * delta))


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius, color)
