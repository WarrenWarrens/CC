extends Node2D

const HUD_SCENE := preload("res://Scenes/HUD.tscn")
@export var show_hud := true
## Background music for this level. Drag a .wav / .ogg / .mp3 here in the Inspector.
@export var music: AudioStream
func _ready() -> void:
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.bind($Player.stats)
	Audio.play_music(music)
	
	#if show_hud:
		#add_child(HUD_SCENE.instantiate())

func _process(_delta) -> void:
	pass
	
