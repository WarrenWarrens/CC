extends Walker  

enum State { IDLE, CHASING, ATTACKING, STUNNED, DEAD }
var current_state = State.IDLE

const SPEED = 120.0
var health = 30
var player = null
var target_offset = Vector2.ZERO
var current_slope = 0.0

@onready var body_sprite = $Visuals/Body
@onready var visuals = $Visuals
@onready var hitbox = $Visuals/Hitbox

func _ready():
	var random_angle = randf() * PI * 2
	target_offset = Vector2(cos(random_angle), sin(random_angle)) * 60.0
	
	#$DetectionZone.body_entered.connect(_on_detection_zone_body_entered)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			body_sprite.play("Idle")
			move_and_slide()
			
		State.CHASING:
			if player:
				if current_slope != 0.0 and velocity.x != 0:
					velocity.y += sign(velocity.x) * SPEED * current_slope
					chase_player()
			else:
				current_state = State.IDLE
				
		State.ATTACKING:
			velocity = Vector2.ZERO
			move_and_slide()
			
		State.STUNNED:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			move_and_slide()
			
		State.DEAD:
			velocity = Vector2.ZERO

func chase_player():
	var target_position = player.global_position + target_offset
	var distance_to_player = global_position.distance_to(player.global_position)
	
	var direction_to_player = sign(player.global_position.x - global_position.x)
	if direction_to_player != 0:
		visuals.scale.x = direction_to_player
		
	if distance_to_player < 50.0:
		current_state = State.ATTACKING
		body_sprite.play("Attack")
		hitbox.monitoring = true
		return

	var move_direction = global_position.direction_to(target_position)
	if global_position.distance_to(target_position) > 10.0:
		velocity = move_direction * SPEED
		body_sprite.play("Walk")
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		body_sprite.play("Idle")


func take_damage(amount, knockback_dir):
	if current_state == State.DEAD:
		return
		
	health -= amount
	hitbox.set_deferred("monitoring", false)
	
	if health <= 0:
		current_state = State.DEAD
		body_sprite.play("Stun") 
		queue_free() 
	else:
		current_state = State.STUNNED
		body_sprite.play("Stun")
		velocity = knockback_dir * 150 
		
		get_tree().create_timer(0.4).timeout.connect(_recover_from_stun)

func _recover_from_stun():
	if current_state != State.DEAD:
		current_state = State.CHASING


func _on_detection_zone_body_entered(body):
	if body.name == "Player":
		player = body
		if current_state == State.IDLE:
			current_state = State.CHASING

func _on_animated_sprite_2d_animation_finished() -> void:
	if body_sprite.animation == "Attack":
			hitbox.monitoring = false
			if current_state != State.DEAD and current_state != State.STUNNED:
				current_state = State.CHASING


func _on_hitbox_area_entered(area):
	if current_state == State.ATTACKING:
		var target = area.owner
		if target and target != self and target.has_method("take_damage"):
			var knockback = global_position.direction_to(target.global_position)
			target.take_damage(10, knockback)
