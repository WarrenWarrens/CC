class_name PauseMenu
extends CanvasLayer
## Pause screen. Escape (ui_cancel) opens and closes it. The whole UI is built in code, so there is nothing to set up:
## World.gd adds one with add_child(PauseMenu.new()).
## It keeps running while the game is paused (process_mode = Always); everything else stops.

var _root: Control
var _resume: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100                      # above the HUD
	_build()
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_set_open(not _root.visible)


func _set_open(open: bool) -> void:
	_root.visible = open
	get_tree().paused = open
	if open:
		_resume.grab_focus()
	else:
		Audio.save_settings()      # remember the slider positions


func _quit_to_menu() -> void:
	Audio.save_settings()
	get_tree().paused = false      # otherwise the menu scene would start frozen
	GameSession.back_to_menu()


# --- UI ---------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_resume = _add_button(box, "Resume", func(): _set_open(false))
	_add_slider(box, "Music Volume", &"Music", false)
	_add_slider(box, "Sound Volume", &"SFX", true)
	_add_button(box, "Quit to Menu", _quit_to_menu)


func _add_button(parent: Control, label: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


## A label + slider for one audio bus. `preview` plays a sound when you let go, so you can hear the new level.
func _add_slider(parent: Control, label: String, bus: StringName, preview: bool) -> void:
	var l := Label.new()
	l.text = label
	parent.add_child(l)

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = Audio.get_volume(bus)
	s.value_changed.connect(func(v: float): Audio.set_volume(bus, v))
	if preview:
		s.drag_ended.connect(func(_changed: bool): Audio.play(&"hit"))
	parent.add_child(s)
