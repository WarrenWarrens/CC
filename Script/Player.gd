
extends Walker  
enum State { NORMAL, JUMPING, PUNCHING, GUARDING, DODGING, STUNNED, AIMING }
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
var _hit_targets: Array = []
const HIT_FRAMES := [1, 2] 

var is_invincible = false
const I_FRAME_DURATION = 0.5

var aim_angle = 0.0
const MAX_AIM_ANGLE = deg_to_rad(45.0)
const AIM_SPEED = 2.0
var can_shoot = true
const FIRE_RATE = 0.5

@onready var aim_ray = $Visuals/AimRay
@onready var laser_line = $Visuals/AimRay/LaserLine

@onready var body_sprite = $Visuals/Body
@onready var visuals = $Visuals
@onready var hitbox = $Visuals/Hitbox
@onready var laser_glow = $Visuals/AimRay/LaserLine/LaserGlow
@onready var hit_light = $Visuals/AimRay/HitLight

@onready var camera: Camera2D = $Camera2D
@export var camera_base_y := 120.0
@export var auto_camera_base := true 
@export var camera_limits := Rect2i(0, -10000, 5000, 20000)

func _ready():
	camera.limit_left = camera_limits.position.x
	camera.limit_top = camera_limits.position.y
	camera.limit_right = camera_limits.end.x
	camera.limit_bottom = camera_limits.end.y
	camera.top_level = true
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0   
	if auto_camera_base:
		camera_base_y = global_position.y
	camera.global_position = Vector2(global_position.x, camera_base_y)
	camera.reset_smoothing()
	
	laser_line.visible = false
	aim_ray.enabled = false
	aim_ray.add_exception(self)
	laser_glow.visible = false
	hit_light.visible = false

func _physics_process(delta):
	if current_state != State.JUMPING and altitude <= 0.0:
		fall(delta)
		
	match current_state:
		State.NORMAL:
			handle_movement()
			update_animations("Idle", "Walk")
			handle_actions()
		State.AIMING:
			handle_aiming(delta)
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
			
	update_floor_state()
	camera.global_position = Vector2(global_position.x, camera_base_y + elevation)	
	
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
		_hit_targets.clear()
		_on_body_frame_changed()
		
	elif Input.is_action_pressed("guard"):
		current_state = State.GUARDING
		body_sprite.play("Guard")
	elif Input.is_action_just_pressed("dodge") and PlayerStats.use_stamina(5):
		current_state = State.DODGING
		velocity = ramp_adjust(facing_direction * DODGE_SPEED)
		body_sprite.play("Dodge")
		get_tree().create_timer(0.3).timeout.connect(func(): current_state = State.NORMAL)
	elif Input.is_action_just_pressed("aim"): 
		current_state = State.AIMING

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
	#if current_state == State.DODGING:
		#return
	#elif current_state == State.GUARDING:
		#PlayerStats.take_damage(ceili(amount / 2.0))
		#hitbox.set_deferred("monitoring", false)
		#velocity = knockback_dir * 75
		#PlayerStats.use_stamina(2)
#
		#return
	#else:
		#hitbox.set_deferred("monitoring", false)
		#current_state = State.STUNNED
		#body_sprite.play("Stun")
		#velocity = knockback_dir * 200
		#get_tree().create_timer(0.5).timeout.connect(func(): current_state = State.NORMAL)
		#PlayerStats.take_damage(amount)
		
	if is_invincible or current_state == State.DODGING:
		return
	elif current_state == State.GUARDING:
		PlayerStats.take_damage(ceili(amount / 2.0))
		hitbox.set_deferred("monitoring", false)
		velocity = knockback_dir * 75
		PlayerStats.use_stamina(2)
		return
	else:
		if current_state == State.AIMING:
			exit_aim() 
		hitbox.set_deferred("monitoring", false)
		current_state = State.STUNNED
		body_sprite.play("Stun")
		velocity = knockback_dir * 200
		PlayerStats.take_damage(amount)
		
		is_invincible = true
		
		var tween = create_tween().set_loops(10) 
		tween.tween_property(body_sprite, "modulate:a", 0.3, I_FRAME_DURATION / 20.0)
		tween.tween_property(body_sprite, "modulate:a", 1.0, I_FRAME_DURATION / 20.0)
		
		get_tree().create_timer(0.5).timeout.connect(func(): current_state = State.NORMAL)
		
		get_tree().create_timer(I_FRAME_DURATION).timeout.connect(func(): is_invincible = false)
	
func fall(delta):
	if altitude <= 0.0:
		return
	z_velocity -= GRAVITY * delta
	altitude = maxf(altitude + z_velocity * delta, 0.0)
	if altitude == 0.0:
		z_velocity = 0.0
	body_sprite.position.y = -altitude
	
	
func _on_body_animation_finished():
	if body_sprite.animation == "Attack":
		hitbox.monitoring = false
		current_state = State.NORMAL


func _on_hitbox_area_entered(area):
	if current_state == State.PUNCHING:
		var target = area.owner
		if target and target != self and target.has_method("take_damage") and not _hit_targets.has(target):
			_hit_targets.append(target)
			var knockback = global_position.direction_to(target.global_position)
			target.take_damage(10, knockback)
			PlayerStats.add_psy(10)

func _on_body_frame_changed() -> void:
	if current_state == State.PUNCHING and body_sprite.animation == "Attack":
		hitbox.set_deferred("monitoring", body_sprite.frame in HIT_FRAMES)
		
#func handle_aiming(delta):
	#velocity = Vector2.ZERO
	#move_and_slide()
	#
	#laser_line.visible = true
	#aim_ray.enabled = true
	#laser_glow.visible = true
#
	#body_sprite.play("Idle") 
	#
	#var input_x = Input.get_axis("left", "right")
	#if input_x != 0:
		#facing_direction.x = sign(input_x)
		#visuals.scale.x = facing_direction.x 
		#
	#var input_y = Input.get_axis("up", "down")
	#aim_angle += input_y * AIM_SPEED * delta
	#aim_angle = clamp(aim_angle, -MAX_AIM_ANGLE, MAX_AIM_ANGLE)
	#aim_ray.rotation = aim_angle
#
	#if aim_ray.is_colliding():
		#var hit_point = aim_ray.to_local(aim_ray.get_collision_point())
		#laser_line.set_point_position(1, Vector2(hit_point.x, 0))
#
		## Position the LaserGlow halfway down the active laser beam so it hugs the beam
		#laser_glow.position = hit_point / 2.0
		## Optional: scale the light's range or texture scale based on distance if you want it to look tighter
#
		## Move the HitLight to the exact point of impact and turn it on
		#hit_light.position = hit_point
		#hit_light.visible = true
	#else:
		#laser_line.set_point_position(1, Vector2(500, 0))
#
		## If not colliding, put the glow light halfway down the maximum 500px beam length
		#laser_glow.position = Vector2(250, 0)
#
		## Turn off the HitLight if we are aiming at empty space
		#hit_light.visible = false
#
	#if Input.is_action_just_pressed("aim"):
		#exit_aim()
	#elif Input.is_action_pressed("punch"): 
		#shoot()
func handle_aiming(delta):
	velocity = Vector2.ZERO
	move_and_slide()

	laser_line.visible = true
	aim_ray.enabled = true
	laser_glow.visible = true

	body_sprite.play("Shoot") 

	var input_x = Input.get_axis("left", "right")
	if input_x != 0:
		facing_direction.x = sign(input_x)
		visuals.scale.x = facing_direction.x 
		
	var input_y = Input.get_axis("up", "down")
	aim_angle += input_y * AIM_SPEED * delta
	aim_angle = clamp(aim_angle, -MAX_AIM_ANGLE, MAX_AIM_ANGLE)
	aim_ray.rotation = aim_angle

	# CRITICAL: Force the raycast to calculate its new collision point right now
	aim_ray.force_raycast_update()

	if aim_ray.is_colliding():
		var hit_point = aim_ray.to_local(aim_ray.get_collision_point())
		laser_line.set_point_position(1, Vector2(hit_point.x, 0))

		# FIX 1: Force the offset to 0 so the light stays perfectly centered
		laser_glow.offset = Vector2.ZERO
		
		# Position it exactly halfway down the beam
		laser_glow.position = Vector2(hit_point.x / 2.0, 0)
		
		# FIX 2: Dynamically read the texture width so the stretch math is flawless
		var glow_width = laser_glow.texture.get_width()
		laser_glow.scale.x = hit_point.x / float(glow_width)

		hit_light.position = hit_point
		hit_light.visible = true
	else:
		laser_line.set_point_position(1, Vector2(500, 0))

		laser_glow.offset = Vector2.ZERO
		laser_glow.position = Vector2(250, 0)
		var glow_width = laser_glow.texture.get_width()
		laser_glow.scale.x = 500.0 / float(glow_width)

		hit_light.visible = false

	if Input.is_action_just_pressed("aim"):
		exit_aim()
	elif Input.is_action_pressed("punch"): 
		shoot()

func shoot():
	if not can_shoot:
		return
		
	can_shoot = false

	if aim_ray.is_colliding():
		var collider = aim_ray.get_collider()
		
		var target = collider.owner 
		
		if target and target != self and target.has_method("take_damage"):
			target.take_damage(5, Vector2.ZERO) 
			
	get_tree().create_timer(FIRE_RATE).timeout.connect(func(): can_shoot = true)

func exit_aim():
	current_state = State.NORMAL
	laser_line.visible = false
	aim_ray.enabled = false
	laser_glow.visible = false 
	hit_light.visible = false  
	aim_angle = 0.0
	aim_ray.rotation = 0.0

func _input(event):
	if current_state == State.AIMING and event is InputEventMouseMotion:
		aim_angle += event.relative.y * 0.005
