class_name Enemy
extends Walker
## Stats, speed, sprites and loot come from `def` (an EnemyDef). Set it in the Inspector on a placed enemy,
## or in code before add_child (the EncounterZone does this). With no def it uses the defaults below.

signal died(enemy: Enemy)

enum State { IDLE, CHASING, ATTACKING, STUNNED, DEAD }
var current_state = State.IDLE

const CORPSE_FADE = 1.0
const LOSE_INTEREST_TIME = 3.0

# Defaults; _apply_def() overwrites them from the EnemyDef.
var speed := 120.0
var damage := 10
var defence := 0
var attack_range := 50.0
var attack_cooldown := 1.2
var stun_time := 0.4
var knockback_resist := 0.0
var lose_interest_distance := 300.0
var corpse_time := 3.0
var health := 30

var attack_cooldown_left = 0.0
var time_far = 0.0
var player = null
var target_offset = Vector2.ZERO
var current_slope = 0.0

@onready var body_sprite = $Visuals/Body
@onready var visuals = $Visuals
@onready var hitbox = $Visuals/Hitbox
@export var loot: LootTable            # overrides the def's loot when set
@export var def: EnemyDef

func _ready():
	add_to_group("enemies")
	var random_angle = randf() * PI * 2
	target_offset = Vector2(cos(random_angle), sin(random_angle)) * 60.0
	if def:
		_apply_def()


func _apply_def() -> void:
	health = def.max_health
	speed = def.base_speed * def.speed_mult
	damage = def.damage
	defence = def.defence
	attack_range = def.attack_range
	attack_cooldown = def.attack_cooldown
	stun_time = def.stun_time
	knockback_resist = def.knockback_resist
	lose_interest_distance = def.lose_interest_distance
	corpse_time = def.corpse_time
	if def.sprite_frames:
		body_sprite.sprite_frames = def.sprite_frames
		body_sprite.play("Idle")
	if def.recolor:
		def.apply_skin(body_sprite, def.main_color)
	if def.detect_radius > 0.0:
		var zone_shape := $Visuals/DetectionZone/CollisionShape2D as CollisionShape2D
		var circle := (zone_shape.shape as CircleShape2D).duplicate() as CircleShape2D   # the scene's shape is shared
		circle.radius = def.detect_radius
		zone_shape.shape = circle


## Makes this enemy go after a player (the EncounterZone uses it so spawned enemies don't wait to notice anyone).
func aggro(target) -> void:
	if target == null or current_state == State.DEAD:
		return
	player = target
	if current_state == State.IDLE:
		current_state = State.CHASING

func _physics_process(delta):
	
	update_floor_state()
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	
	air_step(delta)
	if traversing:
		return
	
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			body_sprite.play("Idle")
			move_and_slide()
			
		State.CHASING:
			if player:
				chase_player(delta)
			else:
				current_state = State.IDLE
				
		State.ATTACKING:
			velocity = Vector2.ZERO
			move_and_slide()
			
		State.STUNNED:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			move_and_slide()
			
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			move_and_slide()
			
func _traversal_done():
	current_state = State.CHASING
	
func chase_player(delta):
	var target_position = player.global_position + target_offset
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > lose_interest_distance:
		time_far += delta
		if time_far >= LOSE_INTEREST_TIME:
			give_up()
			return
	else:
		time_far = 0.0
	
	var direction_to_player = sign(player.global_position.x - global_position.x)
	if direction_to_player != 0:
		visuals.scale.x = direction_to_player
		
	if distance_to_player < attack_range and attack_cooldown_left <= 0.0:
		current_state = State.ATTACKING
		body_sprite.play("Attack")
		hitbox.monitoring = true
		return

	var move_direction = global_position.direction_to(target_position)
	if global_position.distance_to(target_position) > 10.0:
		velocity = move_direction * speed
		body_sprite.play("Walk")
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		body_sprite.play("Idle")


func take_damage(amount, knockback_dir):
	if current_state == State.DEAD:
		return
		
	health -= maxi(1, int(amount) - defence)
	hitbox.set_deferred("monitoring", false)
	
	if health <= 0:
		die(knockback_dir)
	else:
		current_state = State.STUNNED
		body_sprite.play("Stun")
		velocity = knockback_dir * 150 * (1.0 - knockback_resist)

		get_tree().create_timer(stun_time).timeout.connect(_recover_from_stun)

func die(knockback_dir):
	current_state = State.DEAD
	velocity = knockback_dir * 150 * (1.0 - knockback_resist)
	body_sprite.play("Death")
	var table: LootTable = loot if loot else (def.loot if def else null)
	if table:
		table.drop(self, knockback_dir)
	died.emit(self)

	set_deferred("collision_layer", 0)                    
	$Visuals/Hurtbox.set_deferred("monitorable", false)   
	$Visuals/DetectionZone.set_deferred("monitoring", false)
	hitbox.set_deferred("monitoring", false)

	var tween = create_tween()
	tween.tween_interval(corpse_time)
	tween.tween_property(self, "modulate:a", 0.0, CORPSE_FADE)
	tween.tween_callback(queue_free)

func give_up():
	player = null
	time_far = 0.0
	current_state = State.IDLE

func _recover_from_stun():
	if current_state != State.DEAD:
		current_state = State.CHASING


func _on_detection_zone_body_entered(body):
	if body.is_in_group("players"):
		aggro(body)

func _on_animated_sprite_2d_animation_finished() -> void:
	if body_sprite.animation == "Attack":
			hitbox.monitoring = false
			attack_cooldown_left = attack_cooldown
			if current_state != State.DEAD and current_state != State.STUNNED:
				current_state = State.CHASING


func _on_hitbox_area_entered(area):
	if current_state == State.ATTACKING:
		var target = area.owner
		if target and target != self and target.has_method("take_damage"):
			if target is Walker and target.floor_id != floor_id:
				return   # you can't hit someone on another floor
			var knockback = global_position.direction_to(target.global_position)
			target.take_damage(damage, knockback)
