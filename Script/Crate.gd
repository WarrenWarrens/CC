extends StaticBody2D

@export var hits_to_break := 3
@export var drop_scene: PackedScene            
@export var drop_count := 1
@export var toss_distance := Vector2(45, 80)  

var _hits := 0
var _broken := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var footprint: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox


func take_damage(_amount, knockback_dir: Vector2) -> void:
	if _broken:
		return
	_hits += 1
	if _hits >= hits_to_break:
		_break(knockback_dir)
	else:
		_wobble()


func _wobble() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "position:x", 3.0, 0.04)
	tween.tween_property(sprite, "position:x", -3.0, 0.04)
	tween.tween_property(sprite, "position:x", 0.0, 0.04)


func _break(knockback_dir: Vector2) -> void:
	_broken = true
	footprint.set_deferred("disabled", true)
	hurtbox.set_deferred("monitorable", false)

	for i in drop_count:
		_spawn_drop(knockback_dir)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _spawn_drop(knockback_dir: Vector2) -> void:
	if drop_scene == null:
		return
	var item := drop_scene.instantiate() as Pickup
	var dir := (-knockback_dir).rotated(randf_range(-0.6, 0.6))
	var target := global_position + dir * randf_range(toss_distance.x, toss_distance.y)
	_add_drop.call_deferred(item, get_parent(), global_position, target)


func _add_drop(item: Pickup, parent: Node, from: Vector2, to: Vector2) -> void:
	parent.add_child(item)
	item.global_position = from
	item.toss(to)
