class_name Pickup
extends Area2D


@export var hover_height := 14.0   
@export var bob_amount := 4.0     
@export var bob_speed := 2.5      

var altitude := 0.0             
var _time := randf() * TAU        
var _tossing := false
var _collected := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_set_altitude(hover_height)


func _process(delta: float) -> void:
	if _tossing:
		return
	_time += delta * bob_speed
	_set_altitude(hover_height + sin(_time) * bob_amount)


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


func _on_body_entered(body: Node2D) -> void:
	if _collected or body.name != "Player":
		return
	_collected = true
	#stats.change_health(20)
	queue_free()
