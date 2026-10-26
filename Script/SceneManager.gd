extends Node

var target_door_id: String = ""
var fade_rect: ColorRect

## load_scene() shows the loading screen for at least this long (seconds), and longer if the scene needs it.
const MIN_LOADING_TIME := 0.4
const FADE_TIME := 0.2

var _loading_layer: CanvasLayer
var _loading_bar: ProgressBar
var _loading := false

func _ready() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100 
	add_child(canvas)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) 
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade_rect)
	_build_loading_screen()

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


## Changes scene behind a loading screen: fade to black, show "Loading...", load the scene on a
## background thread, then fade into it. Takes MIN_LOADING_TIME, or as long as the load needs if that is longer.
func load_scene(path: String) -> void:
	if _loading:
		return
	_loading = true
	await _fade_to(1.0, FADE_TIME)
	_loading_layer.visible = true
	_loading_bar.value = 0.0

	ResourceLoader.load_threaded_request(path)
	var started := Time.get_ticks_msec()
	var progress := []
	var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while true:
		status = ResourceLoader.load_threaded_get_status(path, progress)
		if not progress.is_empty():
			_loading_bar.value = progress[0] * 100.0
		var waited := (Time.get_ticks_msec() - started) / 1000.0
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS and waited >= MIN_LOADING_TIME:
			break
		await get_tree().process_frame

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(path))
		await get_tree().process_frame
	else:
		push_error("Could not load scene: " + path)
	_loading_layer.visible = false
	await _fade_to(0.0, FADE_TIME)
	_loading = false


func _fade_to(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", alpha, time)
	await tween.finished


func _build_loading_screen() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 101          # above the black fade
	_loading_layer.visible = false
	add_child(_loading_layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var label := Label.new()
	label.text = "Loading..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(240, 10)
	_loading_bar.show_percentage = false
	box.add_child(_loading_bar)
