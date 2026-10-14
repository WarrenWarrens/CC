extends Node

var target_door_id: String = ""

func change_scene(scene_path: String, door_id: String) -> void:
	target_door_id = door_id
	get_tree().change_scene_to_file(scene_path)
