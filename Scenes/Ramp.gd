class_name Ramp
extends Area2D

@export_range(1.0, 80.0) var angle_degrees := 40.0   # match your boundary polygon edges
@export var rises_to_right := true                    # false for your "Down" ramps

func get_slope() -> float:
	var s := tan(deg_to_rad(angle_degrees))
	return -s if rises_to_right else s

func _ready() -> void:
	body_entered.connect(func(b): if b.has_method("enter_ramp"): b.enter_ramp(self))
	body_exited.connect(func(b): if b.has_method("exit_ramp"): b.exit_ramp(self))
	
