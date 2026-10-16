class_name StatBar
extends Control

@export var title := "LIFE"
@export var stat := "health"             
@export var show_values := false         
@export var chunks := 0                   
@export var flash_when_full := false
@export var bar_width := 129.0
@export var width_per_point := 0.0        
@export var bar_height := 16.0
@export var font_size := 12
@export var fill_color := Color.RED
@export var empty_color := Color.WHITE
@export var divider_color := Color(0.8, 0.8, 0.8)
@export var flash_colors: Array[Color] = [Color.RED, Color.ORANGE, Color.YELLOW, Color.WHITE]
@export var flash_rate := 10.0           
@export var drain_speed := 0.4            

var _shown := 0.0
var _max := 1.0
var _target := 0.0
var _time := 0.0
var _header_h := 0.0
var _title_label: Label
var _value_label: Label

# FIX: Add a reference to hold the specific player's Stats node
var _target_stats: Stats = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_h = font_size + 4.0
	_title_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT)
	_title_label.text = title
	_value_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT)
	_value_label.visible = show_values
	
	# Fallback for singleplayer testing if bind() isn't called quickly enough
	if Engine.is_editor_hint() == false and _target_stats == null:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0 and players[0].has_node("Stats"):
			_target_stats = players[0].get_node("Stats")
			
	if _target_stats:
		_shown = float(_target_stats.get(stat))
	else:
		_shown = 0.0

func _make_label(align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.position = Vector2.ZERO
	add_child(l)
	return l

func _bar_w() -> float:
	return _max * width_per_point if width_per_point > 0.0 else bar_width

func _process(delta: float) -> void:
	_time += delta
	
	# FIX: Only attempt to read stats if we have a valid reference
	if not is_instance_valid(_target_stats):
		return
		
	# Read from the instanced Stats node, not the old PlayerStats Autoload
	_target = float(_target_stats.get(stat))
	_max = maxf(float(_target_stats.get("max_" + stat)), 0.001)
	_shown = move_toward(_shown, _target, _max * drain_speed * delta)

	var w := _bar_w()
	custom_minimum_size = Vector2(w, _header_h + bar_height)
	_title_label.size = Vector2(w, _header_h)
	_value_label.size = Vector2(w, _header_h)
	if show_values:
		_value_label.text = "%d/%d" % [ceili(_target), int(_max)]
	queue_redraw()

func _fill() -> Color:
	if flash_when_full and _target >= _max and not flash_colors.is_empty():
		return flash_colors[int(_time * flash_rate) % flash_colors.size()]
	return fill_color

func _draw() -> void:
	var w := _bar_w()
	draw_rect(Rect2(0, _header_h, w, bar_height), empty_color)
	var frac := clampf(_shown / _max, 0.0, 1.0)
	draw_rect(Rect2(0, _header_h, w * frac, bar_height), _fill())
	if chunks > 1:
		for i in range(1, chunks):
			draw_rect(Rect2(w * i / chunks - 1.0, _header_h, 2.0, bar_height), divider_color)
			
# FIX: Make bind setup the direct reference for this specific bar
func bind(target_stats: Stats) -> void:
	_target_stats = target_stats
	if is_inside_tree():
		_shown = float(_target_stats.get(stat))

func _bind_children(node: Node, stats: Stats) -> void:
	for c in node.get_children():
		if c is StatBar:
			c.bind(stats)
		_bind_children(c, stats)
