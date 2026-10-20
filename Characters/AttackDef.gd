class_name AttackDef
extends Resource
## One move in a combo. Make one .tres per move and link them together:
## light1.next_light = light2, light1.next_heavy = heavy1, and so on. Put the first moves on a CharacterDef.

@export var animation := &"Attack"                # falls back to "Attack" if the character has no animation with this name
@export var damage := 10
@export var knockback_scale := 1.0                # 2 = the target flies twice as far
@export var stamina_cost := 2.0
@export var speed_scale := 1.0                    # animation speed: heavy moves are slower

@export_group("Hit")
@export var hit_frames: Array[int] = [1, 2]       # animation frames where the hitbox is live
@export var hitbox_size := Vector2(47, 25)        # range
@export var hitbox_offset := Vector2(23.5, -28.5)
@export var lunge := 0.0                          # px/s the player steps forward until the first hit frame

@export_group("Chaining")
@export var cancel_frame := 2                     # earliest frame a buffered button press can start the next move
@export var next_light: AttackDef
@export var next_heavy: AttackDef


## The heavy move used when a character has none set.
static func default_heavy() -> AttackDef:
	var a := AttackDef.new()
	a.damage = 20
	a.knockback_scale = 2.0
	a.stamina_cost = 5.0
	a.speed_scale = 0.7
	a.hitbox_size = Vector2(60, 34)
	a.lunge = 60.0
	return a
