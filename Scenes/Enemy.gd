extends CharacterBody2D

const SPEED = 120.0
var player = null
var is_chasing = false
var target_offset = Vector2.ZERO

@onready var detection_zone = $DetectionZone
@onready var sprite = $Visuals/Body 

func _ready():
	detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	var random_angle = randf() * PI * 2
	var distance_from_player = 60.0
	target_offset = Vector2(cos(random_angle), sin(random_angle)) * distance_from_player
func _physics_process(_delta):
	if is_chasing and player:
		var target_position = player.global_position + target_offset
		var direction = global_position.direction_to(target_position)
		velocity = direction * SPEED
		move_and_slide()
		
		if global_position.distance_to(target_position) > 10.0:
			velocity = direction * SPEED
			move_and_slide()
		
		if direction.x != 0:
			sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO

func _on_detection_zone_body_entered(body):
	if body.name == "Player":
		player = body
		is_chasing = true

func _on_detection_zone_body_exited(body):
	if body.name == "Player":
		is_chasing = false
		player = null
