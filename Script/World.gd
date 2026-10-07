extends Node2D

const HUD_SCENE := preload("res://Scenes/HUD.tscn")
@export var show_hud := true
func _ready() -> void:
	if show_hud:
		add_child(HUD_SCENE.instantiate())

func _process(_delta) -> void:
	pass
