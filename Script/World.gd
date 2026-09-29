extends Node2D

@onready var ramp_assist = $RampAssist

func _ready() -> void:
	pass


func _process(_delta) -> void:
	pass


func _on_ramp_assist_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.current_slope = -0.3

		var player_camera = body.get_node("Camera2D")
		player_camera.limit_top = -240
		player_camera.limit_bottom = 240

func _on_ramp_assist_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		body.current_slope = 0.0

		var player_camera = body.get_node("Camera2D")
		var tween = create_tween()

		# Calculate the new camera bounds based on the player's CURRENT Y position.
		# Assuming your screen height is 360:
		var screen_height = 360
		# If the player exits the top of the ramp
		if body.global_position.y < ramp_assist.global_position.y:
			# Snap the bottom limit to just below the player's current floor level
			# You might need to adjust the '+ 100' offset depending on where your floor art is
			var new_bottom = body.global_position.y + 100 
			tween.tween_property(player_camera, "limit_top", new_bottom - screen_height, 1.0)
			tween.tween_property(player_camera, "limit_bottom", new_bottom, 1.0)
			
		else:
			var new_bottom = body.global_position.y + 100
			tween.tween_property(player_camera, "limit_top", new_bottom - screen_height, 1.0)
			tween.tween_property(player_camera, "limit_bottom", new_bottom, 1.0)
