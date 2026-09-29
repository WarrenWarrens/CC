extends Node2D

#d@onready var ramp_assist = $RampAssist

func _ready() -> void:
	pass


func _process(_delta) -> void:
	pass


func _on_ramp_assist_up_body_entered(body: Node2D) -> void:
	if "current_slope" in body:
		body.current_slope = -0.3 
		_unlock_camera(body)

	
func _on_ramp_assist_down_body_exited(body: Node2D) -> void:
	if "current_slope" in body:
		body.current_slope = 0.0
		_lock_camera(body)

func _on_ramp_assist_down_body_entered(body: Node2D) -> void:
	if "current_slope" in body:
		body.current_slope = 0.3 
		_unlock_camera(body)

func _on_ramp_assist_up_body_exited(body: Node2D) -> void:
	if "current_slope" in body:
		body.current_slope = 0.0
		_lock_camera(body)
		
func _unlock_camera(body: Node2D) -> void:
	if body.name == "Player":
		var player_camera = body.get_node("Camera2D")
		player_camera.limit_top = -10000 
		player_camera.limit_bottom = 10000

func _lock_camera(body: Node2D) -> void:
	if body.name == "Player":
		var player_camera = body.get_node("Camera2D")
		var tween = create_tween()

		var screen_height = 360
		var new_bottom = body.global_position.y + 120 

		tween.tween_property(player_camera, "limit_top", new_bottom - screen_height, 1.0)
		tween.tween_property(player_camera, "limit_bottom", new_bottom, 1.0)
