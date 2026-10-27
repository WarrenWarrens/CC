extends Walker  
enum FightingStyle { RED, BLUE, YELLOW, PURPLE }
var current_style = FightingStyle.RED 
enum State { NORMAL, JUMPING, ATTACKING, GUARDING, DODGING, STUNNED, AIMING, SLIDING, RAMMING }
var current_state = State.NORMAL

const SPEED = 200.0
const DEPTH_SQUASH = 0.6
const JUMP_FORCE = 400.0
const DODGE_SPEED = 300.0
const SPRINT_SPEED_MULT = 1.6
const SPRINT_JUMP_MULT = 1.25
const SPRINT_STAMINA_DRAIN = 2.0
const DODGE_DEPTH_MULT = 1

var is_sprinting = false
var sprint_locked := false        

# Ram: sprint, then HOLD heavy. You run forward carrying enemies until you let go, hit a wall, fall or run out of stamina.
const RAM_HOLD_TIME := 0.25       # a tap of heavy while sprinting is the sprint heavy; holding this long starts the ram
const RAM_MAX_CARRIED := 3
var ram: AttackDef
var _ram_pending := false         # heavy was pressed while sprinting: tap or hold?
var _ram_charge := 0.0
var _ram_time := 0.0
var _ram_victims: Array[Enemy] = []

const SLIDE_START_SPEED := SPEED * SPRINT_SPEED_MULT * 1.1
const SLIDE_FRICTION := 350.0     
const SLIDE_RAMP_ACCEL := 450.0    
const SLIDE_MAX_SPEED := 650.0
const SLIDE_MIN_SPEED := 90.0    
const SLIDE_STAMINA := 3.0
var _slide_speed := 0.0
var _slide_dir := Vector2.RIGHT
var sprint_stamina_accumulator = 0.0 


var current_slope = 0.0
var facing_direction = Vector2.RIGHT
var _hit_targets: Array = []

const COMBO_WINDOW := 0.25        
var light_start: AttackDef
var heavy_start: AttackDef
var sprint_light: AttackDef
var sprint_heavy: AttackDef
var jump_light: AttackDef
var jump_heavy: AttackDef
var _attack_time := 0.0           # seconds since the current move started
var current_attack: AttackDef
var _buffer := ""                 
var _combo_from: AttackDef        
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
const BACKPEDAL_MULT := 0.75    
var lock_on: LockOn

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
	lock_on = LockOn.new()
	add_child(lock_on)
	lock_on.setup(self, $Visuals/DetectZone)
	hit_shape.shape = RectangleShape2D.new()  
	
	laser_line.visible = false
	aim_ray.enabled = false
	aim_ray.add_exception(self)
	laser_glow.visible = false
	hit_light.visible = false
	
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
	sprint_light = def.sprint_light_attack
	sprint_heavy = def.sprint_heavy_attack
	jump_light = def.jump_light_attack
	jump_heavy = def.jump_heavy_attack
	ram = def.ram_attack
	GameSession.register_player(stats)
	stats.died.connect(_on_died)
	switch_style(def.starting_style)

func _physics_process(delta):
	move_intent = Input.get_vector("left", "right", "up", "down")
	if Input.is_action_just_pressed("lock_on"):
		lock_on.toggle()
	elif Input.is_action_just_pressed("lock_cycle"):
		lock_on.cycle()
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
				if current_state == State.JUMPING:
					handle_air_actions()
			State.SLIDING:
				handle_slide(delta)
			State.RAMMING:
				handle_ram(delta)
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
	


func handle_movement(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	is_sprinting = false
	var current_speed = SPEED
	if sprint_locked and not Input.is_action_pressed("sprint"):
		sprint_locked = false
	
	
	if Input.is_action_pressed("sprint") and not sprint_locked and input_dir != Vector2.ZERO and is_grounded():
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

	var look := lock_on.facing_toward()
	if look == 0.0:
		look = signf(input_dir.x)
	face(look)

	velocity = ramp_adjust(Vector2(input_dir.x * current_speed, input_dir.y * current_speed * DEPTH_SQUASH))
	if lock_on.target != null and input_dir.x != 0.0 and signf(input_dir.x) != facing_direction.x:
		velocity.x *= BACKPEDAL_MULT
	move_and_slide()
	


func face(dir: float) -> void:
	if dir != 0.0:
		facing_direction.x = dir
		visuals.scale.x = dir


var _step_timer := 0.0

func update_animations(idle_anim, walk_anim):
	if velocity.length() > 0:
		_step_timer -= get_physics_process_delta_time()
		if _step_timer <= 0.0:
			_step_timer = 0.25 if is_sprinting else 0.38   
			Audio.play(&"step", -10.0)
		if is_sprinting:
			body_sprite.play("Sprint")
		else:
			body_sprite.play(walk_anim)
	else:
		body_sprite.play(idle_anim)

func handle_actions():
	if _ram_pending:
		_update_ram_press(get_physics_process_delta_time())
		return
	if Input.is_action_just_pressed("ui_accept") and is_grounded():
		current_state = State.JUMPING
		z_velocity = JUMP_FORCE * (SPRINT_JUMP_MULT if is_sprinting else 1.0)
		Audio.play(&"jump")
		body_sprite.play("Jump")
	elif Input.is_action_just_pressed("light"):
		start_attack(_ground_move("light"))
	elif Input.is_action_just_pressed("heavy"):
		if is_sprinting and ram != null:
			_ram_pending = true          # tap = sprint heavy, hold = ram: decided in _update_ram_press
			_ram_charge = 0.0
		else:
			start_attack(_ground_move("heavy"))
	elif Input.is_action_just_pressed("slide") and is_sprinting and stats.use_stamina(SLIDE_STAMINA):
		_start_slide()
	elif Input.is_action_pressed("guard"):
		current_state = State.GUARDING
		body_sprite.play("Guard")
	elif Input.is_action_just_pressed("dodge") and stats.use_stamina(5):
		current_state = State.DODGING
		Audio.play(&"dodge")
		var dodge_dir = move_intent if move_intent != Vector2.ZERO else facing_direction
		velocity = ramp_adjust(Vector2(dodge_dir.x * DODGE_SPEED, dodge_dir.y * DODGE_SPEED * DODGE_DEPTH_MULT))
		body_sprite.play("Dodge")
		get_tree().create_timer(0.3).timeout.connect(func(): current_state = State.NORMAL)
	elif Input.is_action_just_pressed("aim"): 
		current_state = State.AIMING


## Ledges and ladders that tire you use these (see Walker).
func drain_stamina(amount: float) -> bool:
	return stats.use_stamina(amount)


func has_stamina() -> bool:
	return stats.stamina >= 1.0


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
		if current_state == State.RAMMING:
			_end_ram()
		_ram_pending = false
		hitbox.set_deferred("monitoring", false)
		current_attack = null           
		_combo_left = 0.0
		body_sprite.speed_scale = 1.0
		current_state = State.STUNNED
		body_sprite.play("Stun")
		velocity = knockback_dir * 200
		stats.take_damage(amount)
		Audio.play(&"hurt")
		
		is_invincible = true
		
		var tween = create_tween().set_loops(10) 
		tween.tween_property(body_sprite, "modulate:a", 0.3, I_FRAME_DURATION / 20.0)
		tween.tween_property(body_sprite, "modulate:a", 1.0, I_FRAME_DURATION / 20.0)
		
		get_tree().create_timer(0.5).timeout.connect(func(): current_state = State.NORMAL)
		
		get_tree().create_timer(I_FRAME_DURATION).timeout.connect(func(): is_invincible = false)
	

func _on_body_animation_finished():
	if current_state == State.ATTACKING:
		end_attack()


func _on_hitbox_area_entered(area):
	if current_state == State.ATTACKING and current_attack:
		var target = area.owner
		if target and target != self and target.has_method("take_damage") and not _hit_targets.has(target):
			if target is Walker and target.floor_id != floor_id:
				return  
			_hit_targets.append(target)
			var knockback = global_position.direction_to(target.global_position) * current_attack.knockback_scale
			target.take_damage(current_attack.damage, knockback)
			stats.add_psy(10)
			Audio.play(&"hit")

func _on_body_frame_changed() -> void:
	if current_state == State.ATTACKING and current_attack:
		hitbox.set_deferred("monitoring", body_sprite.frame in current_attack.hit_frames)



## Which move a button press on the ground starts: the sprint move while sprinting (if the character has one), otherwise the combo.
func _ground_move(kind: String) -> AttackDef:
	if is_sprinting:
		var special := sprint_light if kind == "light" else sprint_heavy
		if special != null:
			return special
	return _first_move(kind)


## Attacks in the air: the jump moves. A character with no jump move can't attack while jumping.
func handle_air_actions() -> void:
	if Input.is_action_just_pressed("light"):
		start_attack(jump_light)
	elif Input.is_action_just_pressed("heavy"):
		start_attack(jump_heavy)


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
	_attack_time = 0.0
	face(lock_on.facing_toward())   
	_buffer = ""
	_combo_left = 0.0
	_hit_targets.clear()
	current_state = State.ATTACKING
	if a == sprint_light or a == sprint_heavy:
		is_sprinting = false       # a sprint attack ends the sprint
		sprint_locked = true
	hit_shape.shape.size = a.hitbox_size
	hit_shape.position = a.hitbox_offset
	var anim: StringName = a.animation if body_sprite.sprite_frames.has_animation(a.animation) else &"Attack"
	body_sprite.speed_scale = a.speed_scale
	body_sprite.sprite_frames.set_animation_loop(anim, false)  
	Audio.play(&"swing")
	body_sprite.play(anim)
	body_sprite.set_frame_and_progress(0, 0.0) 
	hitbox.set_deferred("monitoring", 0 in a.hit_frames)


## Runs every physics frame of an attack: step forward, and chain into the next move if a button was pressed.
func handle_attack() -> void:
	var a := current_attack
	if Input.is_action_just_pressed("light"):
		_buffer = "light"
	elif Input.is_action_just_pressed("heavy"):
		_buffer = "heavy"

	_attack_time += get_physics_process_delta_time()

	# how fast the move carries us forward
	var lunge_speed := 0.0
	if a.lunge_time > 0.0:
		lunge_speed = a.lunge * maxf(1.0 - _attack_time / a.lunge_time, 0.0)   # momentum that fades out over lunge_time
	elif a.lunge_whole_move or (not a.hit_frames.is_empty() and body_sprite.frame <= a.hit_frames[0]):
		lunge_speed = a.lunge

	velocity = ramp_adjust(Vector2(facing_direction.x * lunge_speed, 0.0)) if lunge_speed > 0.0 else Vector2.ZERO
	move_and_slide()

	if _buffer != "" and body_sprite.frame >= a.cancel_frame:
		var next := a.next_light if _buffer == "light" else a.next_heavy
		_buffer = ""
		start_attack(next)  


func end_attack() -> void:
	hitbox.monitoring = false
	body_sprite.speed_scale = 1.0
	_combo_from = current_attack
	_combo_left = COMBO_WINDOW
	current_attack = null
	current_state = State.JUMPING if altitude > 0.0 else State.NORMAL   # a jump attack ends back in the jump


# --- ramming ----------------------------------------------------------------------

## Heavy was pressed while sprinting. Let go quickly = the sprint heavy. Held for RAM_HOLD_TIME = the ram.
func _update_ram_press(delta: float) -> void:
	_ram_charge += delta
	if not Input.is_action_pressed("heavy"):
		_ram_pending = false
		start_attack(_ground_move("heavy"))
	elif not is_sprinting:
		_ram_pending = false              # stopped sprinting before the ram started
	elif _ram_charge >= RAM_HOLD_TIME:
		_ram_pending = false
		_start_ram()


func _start_ram() -> void:
	if not stats.use_stamina(ram.stamina_cost):
		return
	current_state = State.RAMMING
	_ram_time = 0.0
	_hit_targets.clear()
	face(lock_on.facing_toward())
	hit_shape.shape.size = ram.hitbox_size
	hit_shape.position = ram.hitbox_offset
	hitbox.set_deferred("monitoring", true)
	var anim: StringName = ram.animation if body_sprite.sprite_frames.has_animation(ram.animation) else &"Sprint"
	body_sprite.sprite_frames.set_animation_loop(anim, true)
	body_sprite.speed_scale = ram.speed_scale
	body_sprite.play(anim)
	Audio.play(&"ram")


func handle_ram(delta: float) -> void:
	_ram_time += delta
	var still_holding := Input.is_action_pressed("sprint") and Input.is_action_pressed("heavy")
	var has_energy := stats.use_stamina(ram.stamina_per_second * delta)

	velocity = ramp_adjust(Vector2(facing_direction.x * ram.lunge, move_intent.y * ram.lunge * DEPTH_SQUASH * 0.5))
	var before := global_position
	move_and_slide()
	_carry_victims(global_position - before)

	var hit_wall := _ram_time > 0.15 and absf(get_real_velocity().x) < ram.lunge * 0.3
	if not still_holding or not has_energy or hit_wall or altitude > 0.0:
		_end_ram()


## Picks up enemies the ram touches and moves everyone we are carrying along with us.
func _carry_victims(moved: Vector2) -> void:
	for area in hitbox.get_overlapping_areas():
		var target = area.owner
		if target == null or target == self or not target.has_method("take_damage"):
			continue
		if target is Walker and target.floor_id != floor_id:
			continue
		if target is Enemy:
			if target.current_state != Enemy.State.DEAD and not _ram_victims.has(target) and _ram_victims.size() < RAM_MAX_CARRIED:
				_grab(target)
		elif not _hit_targets.has(target):
			_hit_targets.append(target)          # a crate or wall in the way: smash it, don't carry it
			target.take_damage(ram.damage, Vector2(facing_direction.x, 0.0))

	for victim in _ram_victims:
		if is_instance_valid(victim) and victim.current_state != Enemy.State.DEAD:
			victim.move_and_collide(moved)


func _grab(enemy: Enemy) -> void:
	_ram_victims.append(enemy)
	enemy.begin_traversal()                      # the enemy's AI stops while we carry it
	enemy.hitbox.set_deferred("monitoring", false)
	enemy.play_anim(&"Stun")
	add_collision_exception_with(enemy)          # so we don't get stuck on the enemy we are pushing
	enemy.add_collision_exception_with(self)


## Ends the ram: everyone we carried is thrown forward with a lot of knockback.
func _end_ram() -> void:
	hitbox.set_deferred("monitoring", false)
	body_sprite.speed_scale = 1.0
	current_state = State.NORMAL
	is_sprinting = false
	sprint_locked = true             # let go of sprint before the next sprint or ram
	var throw := Vector2(facing_direction.x, 0.0) * ram.knockback_scale
	for victim in _ram_victims:
		if not is_instance_valid(victim):
			continue
		_free_victim(victim)
		if victim.current_state != Enemy.State.DEAD:
			victim.take_damage(ram.damage, throw)
			stats.add_psy(10)
	_ram_victims.clear()


## Lets enemies go without hurting them (the player died or was hit).
func _release_victims() -> void:
	for victim in _ram_victims:
		if is_instance_valid(victim):
			_free_victim(victim)
	_ram_victims.clear()


func _free_victim(victim: Enemy) -> void:
	remove_collision_exception_with(victim)
	victim.remove_collision_exception_with(self)
	victim.end_traversal()


# --- sliding ----------------------------------------------------------------------

func _start_slide() -> void:
	current_state = State.SLIDING
	is_sprinting = false
	_slide_speed = SLIDE_START_SPEED
	_slide_dir = Vector2(signf(move_intent.x) if move_intent.x != 0.0 else facing_direction.x, move_intent.y)
	face(_slide_dir.x)
	Audio.play(&"slide")
	_play_once(&"Slide", &"Dodge")


func handle_slide(delta: float) -> void:
	_slide_dir.y = move_toward(_slide_dir.y, move_intent.y, 2.0 * delta)        # steer up and down a little
	# get_slope() times the direction is positive going DOWN a ramp, negative going up
	var downhill := signf(_slide_dir.x) * get_slope()
	_slide_speed += (SLIDE_RAMP_ACCEL * downhill - SLIDE_FRICTION) * delta
	_slide_speed = minf(_slide_speed, SLIDE_MAX_SPEED)
	velocity = ramp_adjust(Vector2(_slide_dir.x * _slide_speed, _slide_dir.y * _slide_speed * DEPTH_SQUASH))
	move_and_slide()
	# out of speed, or ran into a wall
	if _slide_speed < SLIDE_MIN_SPEED or get_real_velocity().length() < SLIDE_MIN_SPEED * 0.5:
		current_state = State.NORMAL


## Plays an animation once and holds its last frame. Uses `fallback` if the character has no `anim`.
func _play_once(anim: StringName, fallback: StringName) -> void:
	var a := anim if body_sprite.sprite_frames.has_animation(anim) else fallback
	body_sprite.sprite_frames.set_animation_loop(a, false)
	body_sprite.play(a)


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
	var look := lock_on.facing_toward()
	face(look if look != 0.0 else Input.get_axis("left", "right"))

	if lock_on.target != null:
		var to_target = visuals.to_local(lock_on.aim_point()) - aim_ray.position
		aim_angle = atan2(to_target.y, absf(to_target.x))
	else:
		aim_angle += Input.get_axis("up", "down") * AIM_SPEED * delta
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
	Audio.play(&"shoot")
	SoftLight.flash(get_parent(), aim_ray.global_transform * Vector2(14.0, 0.0))   # muzzle flash

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
	_release_victims()
	set_physics_process(false)    
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
