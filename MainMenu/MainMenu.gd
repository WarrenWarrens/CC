extends Node2D

var level: int = 1
## Music for this screen. Drag a .wav / .ogg / .mp3 here in the Inspector (select the root node).
## Leave it empty to keep whatever is already playing; the same track in two scenes carries on without restarting.
@export var music: AudioStream
@onready var music_slider = $CenterContainer/SettingsMenu/MusicVolumeSlider
@onready var sfx_slider = $CenterContainer/SettingsMenu/SfxVolumeSlider


func _ready() -> void:
	Audio.play_music(music)
	music_slider.value = Audio.get_volume(&"Music")  
	sfx_slider.value = Audio.get_volume(&"SFX")
	$CenterContainer/SettingsMenu/Fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false

func _on_play_pressed() -> void:
	$CenterContainer/MenuButtons.visible = false
	$CenterContainer/LevelsMenu.visible = true

func _on_options_pressed() -> void:
	$CenterContainer/MenuButtons.visible = false
	$CenterContainer/SettingsMenu.visible = true

func _on_credits_pressed() -> void:
	$CenterContainer/MenuButtons.visible = false
	$CenterContainer/CreditsMenu.visible = true

func _on_exit_pressed() -> void:
	get_tree().quit()
	

func _on_music_volume_slider_value_changed(value: float) -> void:
	Audio.set_volume(&"Music", value)


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	Audio.set_volume(&"SFX", value)


func _on_button_pressed() -> void:
	Audio.save_settings()
	$CenterContainer/MenuButtons.visible = true
	$CenterContainer/SettingsMenu.visible = false
	$CenterContainer/CreditsMenu.visible = false


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _on_test_level_button_pressed() -> void:
	#get_tree().change_scene_to_file("res://Scenes/WorldFive.tscn")
	GameSession.open_select("res://Scenes/WorldFive.tscn")


func _on_back_button_pressed() -> void:
	$CenterContainer/MenuButtons.visible = true
	$CenterContainer/SettingsMenu.visible = false
	$CenterContainer/CreditsMenu.visible = false
	$CenterContainer/LevelsMenu.visible = false
