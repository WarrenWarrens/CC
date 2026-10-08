
extends Walker  
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

@export var camera_base_y := 120
@onready var camera: Camera2D = $Camera2D


func _ready():
	camera.top_level = true
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0   
	camera.global_position = Vector2(global_position.x, camera_base_y)
	camera.reset_smoothing()

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
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			move_and_slide()
			
	update_floor_layer()
	camera.global_position = Vector2(global_position.x, camera_base_y + get_elevation_shift())
	
	
func get_elevation_shift() -> float:
	var total := 0.0
	for r in get_tree().get_nodes_in_group("ramps"):
		total += r.get_elevation_shift(global_position)
	return total
	

func handle_movement():
	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = ramp_adjust(Vector2(input_dir.x * SPEED, input_dir.y * SPEED * DEPTH_SQUASH))
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
	elif Input.is_action_just_pressed("punch") and PlayerStats.use_stamina(2):
		current_state = State.PUNCHING
		body_sprite.play("Attack")
		hitbox.monitoring = true
	elif Input.is_action_pressed("guard"):
		current_state = State.GUARDING
		body_sprite.play("Guard")
	elif Input.is_action_just_pressed("dodge") and PlayerStats.use_stamina(5):
		current_state = State.DODGING
		velocity = ramp_adjust(facing_direction * DODGE_SPEED)
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
	PlayerStats.add_psy(10)

func is_grounded() -> bool:
	return current_state != State.JUMPING


func take_damage(amount, knockback_dir):
	if current_state == State.DODGING:
		return
	elif current_state == State.GUARDING:
		PlayerStats.take_damage(ceili(amount / 2.0))
		hitbox.set_deferred("monitoring", false)
		velocity = knockback_dir * 75
		PlayerStats.use_stamina(2)

		return
	else:
		hitbox.set_deferred("monitoring", false)
		current_state = State.STUNNED
		body_sprite.play("Stun")
		velocity = knockback_dir * 200
		get_tree().create_timer(0.5).timeout.connect(func(): current_state = State.NORMAL)
		PlayerStats.take_damage(amount)
	

func _on_body_animation_finished():
	if body_sprite.animation == "Attack":
		hitbox.monitoring = false
		current_state = State.NORMAL


func _on_hitbox_area_entered(area):
	if current_state == State.PUNCHING:
		var target = area.owner
		if target and target != self and target.has_method("take_damage"):
			var knockback = global_position.direction_to(target.global_position)
			target.take_damage(10, knockback)
			PlayerStats.add_psy(10)
