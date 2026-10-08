class_name Floors


const FLOOR_HEIGHT := 500.0   
const Z_STEP := 10
const CHARACTER_OFFSET := 5

const SWITCH_POINT := 0.5


static func elevation_shift(node: Node2D) -> float:
	var total := 0.0
	for r in node.get_tree().get_nodes_in_group("ramps"):
		total += r.get_elevation_shift(node.global_position)
	return total


static func floor_of(node: Node2D) -> int:
	var floors_up := -elevation_shift(node) / FLOOR_HEIGHT
	return floori(floors_up + 1.0 - SWITCH_POINT)


static func character_z(node: Node2D) -> int:
	return floor_of(node) * Z_STEP + CHARACTER_OFFSET
