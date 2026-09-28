#extends CharacterBody2D
#
#const SPEED = 300.0
#const DEPTH_SQUASH = 0.6 
#
#
#var altitude = 0.0 
#var z_velocity = 0.0
#const GRAVITY = 900.0
#const JUMP_FORCE = 400.0
#var current_slope = 0.0
#
#@onready var body_sprite = $Visuals/Body
#
#func _physics_process(delta):
	#var input_dir = Input.get_vector("left", "right", "up", "down")
#
	#velocity.x = input_dir.x * SPEED
	#velocity.y = input_dir.y * SPEED * DEPTH_SQUASH 
	#
	#if current_slope != 0.0 and input_dir.x != 0:
		#velocity.y += input_dir.x * SPEED * current_slope
		#
	#move_and_slide()
	#
	#
	#if input_dir.x != 0:
		#body_sprite.flip_h = input_dir.x < 0
#
	#if is_grounded():
		#if Input.is_action_just_pressed("ui_accept"):
			#z_velocity = JUMP_FORCE
	#else:
		#z_velocity -= GRAVITY * delta
#
	#altitude += z_velocity * delta
	#
	#if altitude < 0:
		#altitude = 0.0
		#z_velocity = 0.0
#
	#
	#body_sprite.position.y = -altitude
	#
	#if not is_grounded():
		#pass
	#elif input_dir != Vector2.ZERO:
		#body_sprite.play("Walk")
	#else:
		#body_sprite.play("Idle")
#
#func is_grounded() -> bool:
	#return altitude <= 0.0
	
extends CharacterBody2D

enum State { NORMAL, JUMPING, PUNCHING, GUARDING, DODGING, STUNNED }
var current_state = State.NORMAL

const SPEED = 300.0
const DEPTH_SQUASH = 0.6
const GRAVITY = 900.0
const JUMP_FORCE = 400.0
const DODGE_SPEED = 600.0

var altitude = 0.0
var z_velocity = 0.0
var current_slope = 0.0
var facing_direction = Vector2.RIGHT

@onready var body_sprite = $Visuals/Body
@onready var visuals = $Visuals
@onready var hitbox = $Visuals/Hitbox

func _physics_process(delta):
	match current_state:
		State.NORMAL:
			handle_movement()
			update_animations("Idle", "Walk")
			handle_actions()
		State.JUMPING:
			handle_movement() 
			handle_jump(delta)
		State.PUNCHING:
			velocity = Vector2.ZERO
			move_and_slide()
		State.GUARDING:
			velocity = Vector2.ZERO
			move_and_slide()
			if Input.is_action_just_released("guard"):
				current_state = State.NORMAL
		State.DODGING:
			move_and_slide()
		State.STUNNED:
			velocity = Vector2.ZERO
			move_and_slide()

func handle_movement():
	var input_dir = Input.get_vector("left", "right", "up", "down")
	
	velocity.x = input_dir.x * SPEED
	velocity.y = input_dir.y * SPEED * DEPTH_SQUASH
	
	if current_slope != 0.0 and input_dir.x != 0:
		velocity.y += input_dir.x * SPEED * current_slope
		
	move_and_slide()
	
	if input_dir.x != 0:
		facing_direction.x = sign(input_dir.x)
		visuals.scale.x = facing_direction.x 

func update_animations(idle_anim, walk_anim):
	if velocity.length() > 0:
		body_sprite.play(walk_anim)
	else:
		body_sprite.play(idle_anim)

func handle_actions():
	if Input.is_action_just_pressed("ui_accept"):
		current_state = State.JUMPING
		z_velocity = JUMP_FORCE
		body_sprite.play("Jump") 
	elif Input.is_action_just_pressed("punch"):
		current_state = State.PUNCHING
		body_sprite.play("Attack")
		hitbox.monitoring = true
	elif Input.is_action_pressed("guard"):
		current_state = State.GUARDING
		body_sprite.play("Guard")
	elif Input.is_action_just_pressed("dodge"):
		current_state = State.DODGING
		velocity = facing_direction * DODGE_SPEED
		body_sprite.play("Dodge")
		get_tree().create_timer(0.3).timeout.connect(func(): current_state = State.NORMAL)

func handle_jump(delta):
	z_velocity -= GRAVITY * delta
	altitude += z_velocity * delta
	
	if altitude <= 0:
		altitude = 0.0
		z_velocity = 0.0
		current_state = State.NORMAL
		
	body_sprite.position.y = -altitude


func take_damage(amount, knockback_dir):
	if current_state == State.GUARDING or current_state == State.DODGING:
		return 
		
	current_state = State.STUNNED
	body_sprite.play("Stunned")
	velocity = knockback_dir * 200
	
	get_tree().create_timer(0.5).timeout.connect(func(): current_state = State.NORMAL)

func _on_body_animation_finished():
	if body_sprite.animation == "Attack":
		hitbox.monitoring = false
		current_state = State.NORMAL


func _on_hitbox_area_entered(area):
	var enemy = area.get_parent() 
	if enemy.has_method("take_damage"):
		var knockback = global_position.direction_to(enemy.global_position)
		enemy.take_damage(10, knockback)
