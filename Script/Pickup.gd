class_name Pickup
extends Area2D
## A world item. What it IS comes from its `item` (an ItemDef), so one scene covers every item.
## Three ways to get one into the world:
##   1. Place the Pickup scene in a level and pick the ItemDef in the Inspector.
##   2. Pickup.spawn(item_def, parent, position, floor_id, toss_target) from code (crates, enemies, scripts).
##   3. loot_table.drop(self) from anything that should drop things.

## Where your Pickup scene lives. Change this to its real path.
const SCENE_PATH := "res://Scenes/Pickup.tscn"

@export var item: ItemDef
## Only players on this floor can see / collect it. Spawned drops inherit their source's floor.
@export var floor_id := 0
## true = walk over it. false = stand next to it and press the "interact" action.
@export var auto_pickup := true
@export var name_radius := 90.0          # how close a player gets before the name appears
@export var hover_height := 14.0
@export var bob_amount := 4.0
@export var bob_speed := 2.5

var altitude := 0.0
var _time := randf() * TAU
var _tossing := false
var _collected := false
var _label: Label
var _label_shown := false
var _label_tween: Tween
var _detect: Area2D

@onready var sprite: Sprite2D = $Sprite2D


static func spawn(def: ItemDef, parent: Node, from: Vector2, on_floor := 0, to := Vector2.INF) -> void:
	var scene := load("res://Scenes/Pickup.tscn") as PackedScene
	if scene == null or parent == null:
		push_warning("Pickup.spawn: couldn't load %s. Fix Pickup.SCENE_PATH." % SCENE_PATH)
		return
	var p := scene.instantiate() as Pickup
	p.item = def
	p.floor_id = on_floor
	# deferred: drops are usually spawned from inside a physics callback (a hit, a death)
	(func():
		if not is_instance_valid(parent):
			return
		parent.add_child(p)
		p.global_position = from
		if to != Vector2.INF:
			p.toss(to)
	).call_deferred()


func _ready() -> void:
	if item == null:
		push_warning("Pickup '%s' has no item set." % name)
	elif item.texture:
		sprite.texture = item.texture
	z_index = floor_id * Walker.FLOOR_Z_STEP + Walker.FLOOR_Z_CHARACTER - 1   # just behind characters on its floor
	_build_detect_zone()
	_build_label()
	_set_altitude(hover_height)


func _process(delta: float) -> void:
	if not _tossing:
		_time += delta * bob_speed
		_set_altitude(hover_height + sin(_time) * bob_amount)
	if _label:
		var half_h := (sprite.texture.get_height() * absf(sprite.scale.y) * 0.5) if sprite.texture else 16.0
		_label.position = Vector2(-_label.size.x * 0.5, -altitude - half_h - _label.size.y - 4.0)


func _physics_process(_delta: float) -> void:
	if _collected or item == null:
		return
	_show_label(_player_in(_detect) != null)
	if _tossing:
		return
	var who := _player_in(self)
	if who == null or not item.can_use(who):
		return
	if auto_pickup or (InputMap.has_action("interact") and Input.is_action_just_pressed("interact")):
		_collect(who)


## First player on our floor overlapping `zone`, or null.
func _player_in(zone: Area2D) -> Walker:
	for b in zone.get_overlapping_bodies():
		var w := b as Walker
		if w != null and w.is_in_group("players") and w.floor_id == floor_id:
			return w
	return null


func _collect(who: Walker) -> void:
	_collected = true
	item.apply(who)
	_show_label(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", sprite.scale * 1.4, 0.12)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)


func _set_altitude(value: float) -> void:
	altitude = value
	sprite.position.y = -value


func toss(target: Vector2, duration := 0.5, arc_height := 30.0) -> void:
	_tossing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target, duration)
	tween.tween_method(func(p: float): _set_altitude(hover_height + sin(p * PI) * arc_height), 0.0, 1.0, duration)
	tween.chain().tween_callback(_land)


func _land() -> void:
	_time = 0.0
	_tossing = false


# --- name label (built in code, so the scene needs no changes) ----------------------------------

func _build_detect_zone() -> void:
	_detect = get_node_or_null("DetectZone") as Area2D
	if _detect != null:
		return
	_detect = Area2D.new()
	_detect.name = "DetectZone"
	_detect.collision_layer = 0
	_detect.collision_mask = collision_mask      # sees whatever the pickup itself sees (the players)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = name_radius
	cs.shape = circle
	_detect.add_child(cs)
	add_child(_detect)


func _build_label() -> void:
	_label = Label.new()
	_label.text = item.display_name if item else ""
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", item.name_color if item else Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.z_as_relative = false
	_label.z_index = 100
	_label.modulate.a = 0.0
	add_child(_label)
	_label.reset_size()


func _show_label(shown: bool) -> void:
	if _label == null or shown == _label_shown:
		return
	_label_shown = shown
	if _label_tween:
		_label_tween.kill()
	_label_tween = create_tween()
	_label_tween.tween_property(_label, "modulate:a", 1.0 if shown else 0.0, 0.15)
