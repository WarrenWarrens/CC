extends CanvasLayer
## The stat bars. By default they stack in the top-left corner.
## Tick `bottom_bar` to try the other layout: one row along the bottom of the screen, with the game
## shifted up by `strip_height` so nothing is hidden behind it. Untick it to go back; nothing else changes.

@export var bottom_bar := false
@export var strip_height := 40.0
@export var strip_color := Color(0, 0, 0, 0.85)
@export var bar_spacing := 24.0


func _ready() -> void:
	if bottom_bar:
		_use_bottom_bar()


func bind(player_stats: Node) -> void:
	for bar in find_children("*", "StatBar", true, false):
		bar.bind(player_stats)


func _use_bottom_bar() -> void:
	var strip := ColorRect.new()
	strip.color = strip_color
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -strip_height
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	move_child(strip, 0)     # behind the bars

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(bar_spacing))
	strip.add_child(row)

	for bar in $VBoxContainer.get_children():
		bar.reparent(row)
	$VBoxContainer.queue_free()

	# move the game up: every camera looks `strip_height` lower, so the world sits that much higher on screen
	for cam in get_tree().current_scene.find_children("*", "Camera2D", true, false):
		cam.offset.y += strip_height
