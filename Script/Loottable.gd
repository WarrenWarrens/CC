class_name LootTable
extends Resource
## What something drops. Used by crates, chests, lockers and enemies alike: give them a `loot` export and call
## `loot.drop(self)` when they break or die. Make it a .tres to share one table between many things,
## or create it inline in the Inspector for a one-off.

@export var entries: Array[LootEntry] = []
@export var rolls := 1                              # how many times to roll the table
@export_range(0.0, 1.0) var nothing_chance := 0.0   # chance a roll drops nothing
@export var toss_distance := Vector2(45, 80)        # min / max px the items fly


## Spawns the loot around `source` (a crate, an enemy...). `knockback_dir` throws it away from the hit.
func drop(source: Node2D, knockback_dir := Vector2.ZERO) -> void:
	var f = source.get("floor_id")
	var floor_id: int = 0 if f == null else int(f)
	var parent := source.get_parent()
	for r in rolls:
		if randf() < nothing_chance:
			continue
		var e := _pick()
		if e == null or e.item == null:
			continue
		for i in randi_range(e.min_count, maxi(e.min_count, e.max_count)):
			var dir := Vector2.DOWN.rotated(randf() * TAU)
			if knockback_dir != Vector2.ZERO:
				dir = (-knockback_dir).rotated(randf_range(-0.6, 0.6))
			var target := _keep_inside(source, floor_id, source.global_position + dir * randf_range(toss_distance.x, toss_distance.y))
			Pickup.spawn(e.item, parent, source.global_position, floor_id, target)


## Stops a toss at the first wall of this floor, so items never land outside the play area.
func _keep_inside(source: Node2D, floor_id: int, target: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(source.global_position, target, Walker.floor_bit(floor_id))
	var hit := source.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return target
	var back: Vector2 = (source.global_position - target).normalized()
	return hit.position + back * 8.0   # a little in front of the wall


func _pick() -> LootEntry:
	var total := 0.0
	for e in entries:
		total += e.weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	for e in entries:
		roll -= e.weight
		if roll <= 0.0:
			return e
	return entries.back()
