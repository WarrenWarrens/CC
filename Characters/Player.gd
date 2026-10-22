extends Walker  
enum FightingStyle { RED, BLUE, YELLOW, PURPLE }
var current_style = FightingStyle.RED 
enum State { NORMAL, JUMPING, ATTACKING, GUARDING, DODGING, STUNNED, AIMING }
var current_state = State.NORMAL

const SPEED = 300.0
const DEPTH_SQUASH = 0.6
#const GRAVITY = 900.0
const JUMP_FORCE = 400.0
const DODGE_SPEED = 600.0
const SPRINT_SPEED_MULT = 1.6
const SPRINT_JUMP_MULT = 1.25
const SPRINT_STAMINA_DRAIN = 5.0

var is_sprinting = false
var sprint_stamina_accumulator = 0.0 

#var altitude = 0.0
#var z_velocity = 0.0
var current_slope = 0.0
var facing_direction = Vector2.RIGHT
var _hit_targets: Array = []

# Combos: the player runs "the current move" (an AttackDef). See Characters/AttackDef.gd.
const COMBO_WINDOW := 0.25         # seconds after a move ends in which the next press still continues the combo
var light_start: AttackDef
var heavy_start: AttackDef
var current_attack: AttackDef
var _buffer := ""                  # "light" or "heavy": pressed during the current move
var _combo_from: AttackDef         # the move that just ended, while the combo window is open
var _combo_left := 0.0

var is_invincible = false
const I_FRAME_DURATION = 0.5

var aim_angle = 0.0
const MAX_AIM_ANGLE = deg_to_rad(45.0)
const AIM_SPEED = 2.0
var can_shoot = true
const FIRE_RATE = 0.5

@onready var aim_ray = $Visuals/AimRay
@onready var laser_line = $Visuals/AimRay/LaserLine
@onready var style_indicator = $Visuals/StyleIndicator
@onready var body_sprite = $Visuals/Body
@onready var visuals = $Visuals
@onready var hitbox = $Visuals/Hitbox
@onready var hit_shape: CollisionShape2D = $Visuals/Hitbox/CollisionShape2D
@onready var laser_glow = $Visuals/AimRay/LaserLine/LaserGlow
@onready var hit_light = $Visuals/AimRay/HitLight
@onready var stats: Stats = $Stats
@export var player_index := 0
@onready var camera: Camera2D = $Camera2D
@export var camera_base_y := 120.0
@export var auto_camera_base := true 
@export var camera_limits := Rect2i(0, -10000, 5000, 20000)
var _last_floor := -99
var speed_mult := 1.0

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
	
	add_to_group("players")
	hit_shape.shape = RectangleShape2D.new()   # the scene's shape is shared; each move resizes its own
	
	laser_line.visible = false
	aim_ray.enabled = false
	aim_ray.add_exception(self)
	laser_glow.visible = false
	hit_light.visible = false
	
	#switch_style(FightingStyle.RED)
	var slots := GameSession.get_slots()
	var slot: Dictionary = slots[mini(player_index, slots.size() - 1)]
	var def: CharacterDef = slot["def"]
	stats.apply_character(def)
	speed_mult = def.speed_mult
	if def.sprite_frames:
		body_sprite.sprite_frames = def.sprite_frames
		body_sprite.play("Idle")
	def.apply_skin(body_sprite, slot["tint"])
	light_start = def.light_attack if def.light_attack else AttackDef.new()
	heavy_start = def.heavy_attack if def.heavy_attack else AttackDef.default_heavy()
	GameSession.register_player(stats)
	stats.died.connect(_on_died)
	switch_style(def.starting_style)

func _physics_process(delta):
	move_intent = Input.get_vector("left", "right", "up", "down")
	_combo_left = maxf(_combo_left - delta, 0.0)
	if not traversing:
		if current_state != State.JUMPING:
			air_step(delta)
		match current_state:
			State.NORMAL:
				handle_movement(delta)
				update_animations("Idle", "Walk")
				handle_actions()
			State.AIMING:
				handle_aiming(delta)
			State.JUMPING:
				handle_movement(delta) 
				handle_jump(delta)
			State.ATTACKING:
				handle_attack()
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
		if floor_id != _last_floor:
			_last_floor = floor_id
			print("floor ", floor_id, "  elevation ", snappedf(elevation, 0.1))
			
	camera.global_position = Vector2(global_position.x, camera_base_y + elevation)
	
func handle_jump(delta):
	if air_step(delta):
		current_state = State.NORMAL

func _traversal_done():
	current_state = State.NORMAL
	
#func get_elevation_shift() -> float:
	#var total := 0.0
	#for r in get_tree().get_nodes_in_group("ramps"):
		#total += r.get_elevation_shift(global_position)
	#return total
	

func handle_movement(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	is_sprinting = false
	var current_speed = SPEED
	
	
	if Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO and is_grounded():
		sprint_stamina_accumulator += SPRINT_STAMINA_DRAIN * delta
		
		if sprint_stamina_accumulator >= 1.0:
			if stats.use_stamina(1):
				sprint_stamina_accumulator -= 1.0
				is_sprinting = true
			else:
				sprint_stamina_accumulator = 0.0
		else:
			is_sprinting = true
			
		if is_sprinting:
			current_speed = SPEED * SPRINT_SPEED_MULT

	velocity = ramp_adjust(Vector2(input_dir.x * current_speed, input_dir.y * current_speed * DEPTH_SQUASH))
	move_and_slide()
	
	if input_dir.x != 0:
		facing_direction.x = sign(input_dir.x)
		visuals.scale.x = facing_direction.x
	
	#velocity = ramp_adjust(Vector2(input_dir.x * SPEED, input_dir.y * SPEED * DEPTH_SQUASH))
	#move_and_slide()
	#
	#if input_dir.x != 0:
		#facing_direction.x = sign(input_dir.x)
		#visuals.scale.x = facing_direction.x 

func update_animations(idle_anim, walk_anim):
	if velocity.length() > 0:
		if is_sprinting:
			body_sprite.play("Sprint")
		else:
			body_sprite.play(walk_anim)
	else:
		body_sprite.play(idle_anim)

func handle_actions():
	if Input.is_action_just_pressed("ui_accept"):
		current_state = State.JUMPING
		z_velocity = JUMP_FORCE * (SPRINT_JUMP_MULT if is_sprinting else 1.0)
		body_sprite.play("Jump")
	elif Input.is_action_just_pressed("light"):
		start_attack(_first_move("light"))
	elif Input.is_action_just_pressed("heavy"):
		start_attack(_first_move("heavy"))
	elif Input.is_action_pressed("guard"):
		current_state = State.GUARDING
		body_sprite.play("Guard")
	elif Input.is_action_just_pressed("dodge") and stats.use_stamina(5):
		current_state = State.DODGING
		velocity = ramp_adjust(facing_direction * DODGE_SPEED)
		body_sprite.play("Dodge")
		get_tree().create_timer(0.3).timeout.connect(func(): current_state = State.NORMAL)
	elif Input.is_action_just_pressed("aim"): 
		current_state = State.AIMING


func is_grounded() -> bool:
	return current_state != State.JUMPING and altitude <= 0.0

func take_damage(amount, knockback_dir):
	if stats.health <= 0: return
	if traversing: return
	
	if is_invincible or current_state == State.DODGING:
		return
	elif current_state == State.GUARDING:
		stats.take_damage(ceili(amount / 2.0))
		hitbox.set_deferred("monitoring", false)
		velocity = knockback_dir * 75
		stats.use_stamina(2)
		return
	else:
		if current_state == State.AIMING:
			exit_aim() 
		hitbox.set_deferred("monitoring", false)
		current_attack = null            # a hit breaks the combo
		_combo_left = 0.0
		body_sprite.speed_scale = 1.0
		current_state = State.STUNNED
		body_sprite.play("Stun")
		velocity = knockback_dir * 200
		stats.take_damage(amount)
		
		is_invincible = true
		
		var tween = create_tween().set_loops(10) 
		tween.tween_property(body_sprite, "modulate:a", 0.3, I_FRAME_DURATION / 20.0)
		tween.tween_property(body_sprite, "modulate:a", 1.0, I_FRAME_DURATION / 20.0)
		
		get_tree().create_timer(0.5).timeout.connect(func(): current_state = State.NORMAL)
		
		get_tree().create_timer(I_FRAME_DURATION).timeout.connect(func(): is_invincible = false)
	
#func fall(delta):
	#if altitude <= 0.0:
		#return
	#z_velocity -= GRAVITY * delta
	#altitude = maxf(altitude + z_velocity * delta, 0.0)
	#if altitude == 0.0:
		#z_velocity = 0.0
	#body_sprite.position.y = -altitude
	
	
func _on_body_animation_finished():
	if current_state == State.ATTACKING:
		end_attack()


func _on_hitbox_area_entered(area):
	if current_state == State.ATTACKING and current_attack:
		var target = area.owner
		if target and target != self and target.has_method("take_damage") and not _hit_targets.has(target):
			if target is Walker and target.floor_id != floor_id:
				return   # you can't hit someone on another floor
			_hit_targets.append(target)
			var knockback = global_position.direction_to(target.global_position) * current_attack.knockback_scale
			target.take_damage(current_attack.damage, knockback)
			stats.add_psy(10)

func _on_body_frame_changed() -> void:
	if current_state == State.ATTACKING and current_attack:
		hitbox.set_deferred("monitoring", body_sprite.frame in current_attack.hit_frames)


# --- attacks and combos -----------------------------------------------------------

## The move a fresh press starts. Inside the combo window it continues the combo, otherwise it is the first move.
func _first_move(kind: String) -> AttackDef:
	var root := light_start if kind == "light" else heavy_start
	if _combo_left > 0.0 and _combo_from:
		var next := _combo_from.next_light if kind == "light" else _combo_from.next_heavy
		return next if next else root
	return root


func start_attack(a: AttackDef) -> void:
	if a == null or not stats.use_stamina(a.stamina_cost):
		return
	current_attack = a
	_buffer = ""
	_combo_left = 0.0
	_hit_targets.clear()
	current_state = State.ATTACKING
	hit_shape.shape.size = a.hitbox_size
	hit_shape.position = a.hitbox_offset
	var anim: StringName = a.animation if body_sprite.sprite_frames.has_animation(a.animation) else &"Attack"
	body_sprite.speed_scale = a.speed_scale
	body_sprite.sprite_frames.set_animation_loop(anim, false)   # a looping move would never finish and the player would be stuck
	body_sprite.play(anim)
	body_sprite.set_frame_and_progress(0, 0.0)   # play() alone would not restart a move that is already playing
	hitbox.set_deferred("monitoring", 0 in a.hit_frames)


## Runs every physics frame of an attack: step forward, and chain into the next move if a button was pressed.
func handle_attack() -> void:
	var a := current_attack
	if Input.is_action_just_pressed("light"):
		_buffer = "light"
	elif Input.is_action_just_pressed("heavy"):
		_buffer = "heavy"

	var lunging: bool = not a.hit_frames.is_empty() and body_sprite.frame <= a.hit_frames[0]

	velocity = ramp_adjust(Vector2(facing_direction.x * a.lunge, 0.0)) if lunging else Vector2.ZERO
	move_and_slide()

	if _buffer != "" and body_sprite.frame >= a.cancel_frame:
		var next := a.next_light if _buffer == "light" else a.next_heavy
		_buffer = ""
		start_attack(next)   # no next move (or no stamina) = the press is ignored


func end_attack() -> void:
	hitbox.monitoring = false
	body_sprite.speed_scale = 1.0
	_combo_from = current_attack
	_combo_left = COMBO_WINDOW
	current_attack = null
	current_state = State.NORMAL


func handle_aiming(delta):
	velocity = Vector2.ZERO
	move_and_slide()

	laser_line.visible = true
	aim_ray.enabled = true
	laser_glow.visible = true

	if body_sprite.animation != "Aim":
		body_sprite.play("Aim")
	elif body_sprite.frame == body_sprite.sprite_frames.get_frame_count("Aim") - 1:
		body_sprite.pause() 
	var input_x = Input.get_axis("left", "right")
	if input_x != 0:
		facing_direction.x = sign(input_x)
		visuals.scale.x = facing_direction.x 
		
	var input_y = Input.get_axis("up", "down")
	aim_angle += input_y * AIM_SPEED * delta
	aim_angle = clamp(aim_angle, -MAX_AIM_ANGLE, MAX_AIM_ANGLE)
	aim_ray.rotation = aim_angle

	aim_ray.force_raycast_update()

	if aim_ray.is_colliding():
		var hit_point = aim_ray.to_local(aim_ray.get_collision_point())
		laser_line.set_point_position(1, Vector2(hit_point.x, 0))

		laser_glow.offset = Vector2.ZERO
		
		laser_glow.position = Vector2(hit_point.x / 2.0, 0)
		
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
	elif Input.is_action_pressed("light"): 
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
	body_sprite.play() 

func _input(event):
	if current_state == State.AIMING and event is InputEventMouseMotion:
		aim_angle += event.relative.y * 0.005
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			switch_style(FightingStyle.RED)
		elif event.keycode == KEY_2:
			switch_style(FightingStyle.BLUE)
		elif event.keycode == KEY_3:
			switch_style(FightingStyle.YELLOW)
		elif event.keycode == KEY_4:
			switch_style(FightingStyle.PURPLE)
func _on_died() -> void:
	set_physics_process(false)    # stand-in until you have a death animation
	create_tween().tween_property(self, "modulate:a", 0.3, 0.5)
	
func switch_style(new_style):
	current_style = new_style

	match current_style:
		FightingStyle.RED:
			style_indicator.color = Color.RED
			print("STYLE: Switched to RED (Brawler)")
		FightingStyle.BLUE:
			style_indicator.color = Color.BLUE
			print("STYLE: Switched to BLUE (Rush)")
		FightingStyle.YELLOW:
			style_indicator.color = Color.YELLOW
			print("STYLE: Switched to YELLOW (Beast)")
		FightingStyle.PURPLE:
			style_indicator.color = Color.PURPLE
			print("STYLE: Switched to PURPLE (Dragon)")
