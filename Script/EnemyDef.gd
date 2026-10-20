class_name EnemyDef
extends CharacterDef
## An enemy type, built on CharacterDef: it already has display_name, max_health, speed_mult, sprite_frames and main_color,
## so these are only the enemy extras. Save them in res://Resources/Enemies/ (NOT res://Characters/, or the
## character-select screen would list them). Right-click > Create New > Resource > EnemyDef.
##   Barbarian: max_health 90, speed_mult 0.7, defence 3      Rusher: max_health 20, speed_mult 1.4

@export_group("Combat")
@export var damage := 10
@export var defence := 0                          # taken off every hit (a hit always does at least 1)
@export var base_speed := 120.0                   # px/s; speed_mult scales it
@export var attack_range := 50.0
@export var attack_cooldown := 1.2
@export var stun_time := 0.4
@export_range(0.0, 1.0) var knockback_resist := 0.0   # 1 = can't be knocked back
@export var detect_radius := 200.0                # how far away it notices a player
@export var lose_interest_distance := 300.0
@export var corpse_time := 3.0

@export_group("Extras")
@export var loot: LootTable
## Recolour the sprite's red clothing with main_color (same shader the players use).
@export var recolor := false


func _init() -> void:
	id = &"enemy"
	display_name = "Enemy"
	max_health = 30
	start_health = 30
