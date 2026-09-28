extends Node2D



func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func _on_elevation_trigger_upper_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var player_camera = body.get_node("Camera2D")
		var tween = create_tween()
		tween.tween_property(player_camera, "limit_top", 0, 1.0)
		tween.tween_property(player_camera, "limit_bottom", 360, 1.0)


func _on_elevation_trigger_lower_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var player_camera = body.get_node("Camera2D")
		var tween = create_tween()
		tween.tween_property(player_camera, "limit_top", 240, 1.0)
		tween.tween_property(player_camera, "limit_bottom", 600, 1.0)


func _on_ramp_assist_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.current_slope = -0.5 

func _on_ramp_assist_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		body.current_slope = 0.0
