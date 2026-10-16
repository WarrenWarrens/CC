extends Node

var target_door_id: String = ""
var fade_rect: ColorRect

func _ready() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100 
	add_child(canvas)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) 
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade_rect)

func fade_and_run(action: Callable) -> void:
	# 1. Fade to Black
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.25)
	await tween.finished
	
	action.call()
	
	await get_tree().create_timer(0.5).timeout
	
	tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.25)

func change_scene(scene_path: String, door_id: String) -> void:
	target_door_id = door_id
	fade_and_run(func(): get_tree().change_scene_to_file(scene_path))
