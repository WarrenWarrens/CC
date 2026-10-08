class_name Walker
extends CharacterBody2D

var ramps: Array[Ramp] = []

func enter_ramp(r: Ramp) -> void:
	if not ramps.has(r):
		ramps.append(r)

func exit_ramp(r: Ramp) -> void:
	ramps.erase(r)

func get_slope() -> float:
	return ramps.back().get_slope() if not ramps.is_empty() else 0.0

func ramp_adjust(v: Vector2) -> Vector2:
	if is_grounded():
		v.y += v.x * get_slope()
	return v
	
func is_grounded() -> bool:
	return true

func update_floor_layer() -> void:
	var z := Floors.character_z(self)
	if z != z_index:
		z_index = z
