class_name FloorWall
extends StaticBody2D
## A wall that only exists for walkers standing on certain floors.
##
## Add a CollisionShape2D / CollisionPolygon2D child, then tick the floors it should block in `floors`.
## (This script sets the physics layer for you: floor 0 = layer 9, floor 1 = layer 10 ... floor 7 = layer 16.
##  Walker.gd gives every Player/Enemy the layer of the floor it is on, so nothing else needs setting up.)
##
## Towers with more than 8 floors: floors repeat every 8, so for floor 9 tick "Floor 1", for floor 10 tick "Floor 2"...
## (floor number minus 8, minus 8 again, and so on). Floors that share a bit must be far apart in the world.
##
## Examples:  the cliff face under an upper floor -> tick the LOWER floor.
##            the edge of the upper floor         -> tick the UPPER floor (leave a gap where a drop Ledge goes).
##            a pillar that stands on every floor -> tick them all.

@export_flags("Floor 0", "Floor 1", "Floor 2", "Floor 3", "Floor 4", "Floor 5", "Floor 6", "Floor 7") var floors := 1


func _ready() -> void:
	collision_layer = floors << (Walker.FLOOR_LAYER_FIRST - 1)
	collision_mask = 0
