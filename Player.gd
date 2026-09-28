extends CharacterBody2D

const SPEED = 300.0
const DEPTH_SQUASH = 0.6 


var altitude = 0.0 
var z_velocity = 0.0
const GRAVITY = 900.0
const JUMP_FORCE = 400.0
var current_slope = 0.0

@onready var body_sprite = $Visuals/Body

func _physics_process(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	velocity.x = input_dir.x * SPEED
	velocity.y = input_dir.y * SPEED * DEPTH_SQUASH 
	
	move_and_slide()
	
	if current_slope != 0.0 and input_dir.x != 0:
		velocity.y += input_dir.x * SPEED * current_slope
	
	if input_dir.x != 0:
		body_sprite.flip_h = input_dir.x < 0

	if is_grounded():
		if Input.is_action_just_pressed("ui_accept"):
			z_velocity = JUMP_FORCE
	else:
		z_velocity -= GRAVITY * delta

	altitude += z_velocity * delta
	
	if altitude < 0:
		altitude = 0.0
		z_velocity = 0.0

	
	body_sprite.position.y = -altitude
	
	if not is_grounded():
		pass
	elif input_dir != Vector2.ZERO:
		body_sprite.play("Walk")
	else:
		body_sprite.play("Idle")

func is_grounded() -> bool:
	return altitude <= 0.0
