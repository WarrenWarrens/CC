extends Area2D
class_name Door

@export var door_id: String = ""

@export_group("Destination")
@export_file("*.tscn") var destination_scene_path: String = ""
@export var destination_door_id: String = ""

@export_group("Requirements")
@export var is_locked: bool = false
@export var required_item: String = ""
@export var require_enemies_defeated: bool = false

@onready var spawn_point: Marker2D = $SpawnPoint

# Cooldown to prevent teleport loops or spamming
var is_cooling_down: bool = false
const COOLDOWN_TIME: float = 1.0 # 1 second cooldown

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# If the player just arrived at this scene and this is the target door
	if SceneManager.target_door_id == door_id:
		# Start cooldown immediately upon arrival so they can't instantly trigger it
		_start_cooldown()
		call_deferred("_spawn_player")

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players") or is_cooling_down:
		return
		
	# Check all requirements before allowing passage
	if not _can_open(body):
		return
		
	if destination_door_id.is_empty():
		push_warning("Door '%s' has no destination_door_id assigned!" % door_id)
		return

	# Cross-scene transition
	if not destination_scene_path.is_empty():
		SceneManager.change_scene(destination_scene_path, destination_door_id)
		return

	# Same-scene local teleport
	_teleport_locally(body)

func _can_open(player: Node2D) -> bool:
	if is_locked:
		print("Door is locked!")
		# Optional: Play a locked sound or show a UI message
		return false
		
	# Check if an item is required and if the player has it
	if not required_item.is_empty() and player.has_method("has_item"):
		if not player.has_item(required_item):
			print("You need the ", required_item, " to enter!")
			return false
			
	# Check if the room requires all enemies to be dead
	if require_enemies_defeated:
		# Assumes you put all your Enemy root nodes into an "enemies" group
		var enemies = get_tree().get_nodes_in_group("enemies")
		if enemies.size() > 0:
			print("Cannot proceed! ", enemies.size(), " enemies remain.")
			return false
			
	return true

func _teleport_locally(player: Node2D) -> void:
	var target_door = _find_door_in_scene(destination_door_id)
	if not target_door:
		push_error("Local door target '%s' not found!" % destination_door_id)
		return

	player.global_position = target_door.spawn_point.global_position
	
	# Apply cooldown to the DESTINATION door so the player doesn't instantly teleport back
	target_door._start_cooldown()
	
	_snap_cameras(player)

func _start_cooldown() -> void:
	is_cooling_down = true
	get_tree().create_timer(COOLDOWN_TIME).timeout.connect(func(): is_cooling_down = false)

func _spawn_player() -> void:
	var player = get_tree().get_first_node_in_group("players")
	if player:
		player.global_position = spawn_point.global_position
		_snap_cameras(player)
		SceneManager.target_door_id = ""

func _find_door_in_scene(target_id: String) -> Door:
	for door in get_tree().get_nodes_in_group("doors"):
		if door is Door and door.door_id == target_id:
			return door
	return null

func _snap_cameras(player: Node2D) -> void:
	if "elevation" in player: player.elevation = 0.0
	if "current_slope" in player: player.current_slope = 0.0

	var player_cam = player.get_node_or_null("Camera2D")
	if player_cam and player_cam is Camera2D:
		player_cam.reset_smoothing()

	var level_cam = get_tree().get_first_node_in_group("level_camera")
	if level_cam and level_cam is Camera2D:
		level_cam.global_position = player.global_position
		level_cam.reset_smoothing()
