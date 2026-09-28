extends Node2D

@onready var ramp_assist = $RampAssist

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func _on_ramp_assist_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.current_slope = -0.5

		var player_camera = body.get_node("Camera2D")
		player_camera.limit_top = -240
		player_camera.limit_bottom = 240

func _on_ramp_assist_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		body.current_slope = 0.0

		var player_camera = body.get_node("Camera2D")
		var tween = create_tween()

		if body.global_position.y < ramp_assist.global_position.y:
			tween.tween_property(player_camera, "limit_top", -240, 1.0)
			tween.tween_property(player_camera, "limit_bottom", 0, 1.0)
		else:
			tween.tween_property(player_camera, "limit_top", 0, 1.0)
			tween.tween_property(player_camera, "limit_bottom", 240, 1.0)
