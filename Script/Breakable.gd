class_name Breakable
extends StaticBody2D
## Anything the player can smash: a crate, a chest, a locker, a vase, or a HIDDEN WALL that opens a secret room.
## Scene: StaticBody2D (this script) > the solid shape (CollisionShape2D OR CollisionPolygon2D),
##        Hurtbox (Area2D, same layer as your enemies' hurtbox) > its own shape, and an optional Sprite2D.
## What it looks like, what it drops and what it reveals are all exports.
##   crate:        broken_texture empty -> fades away, drops loot
##   chest:        broken_texture = open chest -> stays, opened
##   secret wall:  no loot, `reveal` = the hidden room, `floor_only_collision` on -> breaks and the way is open

signal broken

@export var max_health := 30.0            # a normal punch does 10, so 3 hits; heavy attacks break it faster
@export var floor_id := 0                 # drops land on this floor
@export var loot: LootTable
@export var broken_texture: Texture2D
@export var stays_solid := true           # only matters when it stays after breaking (chest)

@export_group("Walls and secrets")
## true = it only blocks walkers standing on `floor_id` (use for walls). false = blocks everyone, as a crate does.
@export var floor_only_collision := false
## Hidden at the start, faded in when this breaks: the secret room (any Node2D / TileMapLayer / Sprite2D...).
@export var reveal: Array[CanvasItem] = []
## Faded out when this breaks: e.g. a fake-wall picture that covers the entrance.
@export var hide_on_break: Array[CanvasItem] = []
@export var reveal_time := 0.4

var _health := 0.0
var _broken := false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")


func _ready() -> void:
	_health = max_health
	if floor_only_collision:
		collision_layer = Walker.floor_bit(floor_id)
	if hurtbox:
		# Hits find their target through the hurtbox's owner. When this Breakable is built straight into a level
		# scene (a wall, not an instanced crate), that owner would be the level, so point it at us.
		hurtbox.owner = self
	for n in reveal:
		n.visible = false
		n.modulate.a = 0.0


func take_damage(amount, knockback_dir: Vector2) -> void:
	if _broken:
		return
	_health -= float(amount)
	if _health <= 0.0:
		_break(knockback_dir)
	else:
		_wobble()


func _wobble() -> void:
	var target: Node2D = sprite if sprite else self
	var x0 := target.position.x
	var tween := create_tween()
	tween.tween_property(target, "position:x", x0 + 3.0, 0.04)
	tween.tween_property(target, "position:x", x0 - 3.0, 0.04)
	tween.tween_property(target, "position:x", x0, 0.04)


func _break(knockback_dir: Vector2) -> void:
	_broken = true
	if hurtbox:
		hurtbox.set_deferred("monitorable", false)
	if loot:
		loot.drop(self, knockback_dir)

	for n in reveal:
		n.visible = true
		create_tween().tween_property(n, "modulate:a", 1.0, reveal_time)
	for n in hide_on_break:
		var t := create_tween()
		t.tween_property(n, "modulate:a", 0.0, reveal_time)
		t.tween_callback(n.hide)
	broken.emit()

	var stays := broken_texture != null
	if stays and sprite:
		sprite.texture = broken_texture
	if not stays or not stays_solid:
		_disable_collision()
	if stays:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


## Turns off every solid shape directly under this body (the Hurtbox's own shapes are untouched).
func _disable_collision() -> void:
	for c in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", true)
