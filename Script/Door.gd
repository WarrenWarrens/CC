extends Area2D
class_name Door

@export var door_id: String = ""
## false = the door opens as soon as a player walks into it.
## true  = the player has to stand next to it and press the "interact" button (G by default).
@export var require_interact: bool = false
## The floor this door stands on. Whoever comes OUT of this door is put on this floor.
@export var door_floor_id: int = 0
## Camera rise of that floor (0 = ground floor, -102 = one 102px ledge up). Only needed if the camera sits wrong after the door.
@export var door_elevation: float = 0.0
## Easier than door_elevation: tick this and the camera is framed the same way as when the level starts
## (the player's spawn height here, compared with where they started). Use it on doors to a higher or lower floor.
@export var auto_elevation: bool = false

@export_group("Destination")
@export_file("*.tscn") var destination_scene_path: String = ""
@export var destination_door_id: String = ""

@export_group("Requirements")
@export var is_locked: bool = false
@export var required_item: String = ""
@export var require_enemies_defeated: bool = false

@onready var spawn_point: Marker2D = $SpawnPoint

var is_cooling_down: bool = false
var _players_in_range: Array[Node2D] = []
var _prompt: Label
const COOLDOWN_TIME: float = 1.0 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if require_interact:
		_build_prompt()
	
	if SceneManager.target_door_id == door_id:
		_start_cooldown()
		call_deferred("_spawn_player")

func _physics_process(_delta: float) -> void:
	if not require_interact or _players_in_range.is_empty():
		return
	if Input.is_action_just_pressed("interact"):
		_try_open(_players_in_range[0])


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	_players_in_range.append(body)
	if _prompt:
		_prompt.visible = true
	if not require_interact:
		_try_open(body)


func _on_body_exited(body: Node2D) -> void:
	_players_in_range.erase(body)
	if _prompt and _players_in_range.is_empty():
		_prompt.visible = false


## "Press G" above the door, only for doors that need a button.
func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.text = "[%s]" % _interact_key_name()
	_prompt.top_level = true        # not scaled or moved with the door's sprite
	_prompt.z_index = 100
	_prompt.visible = false
	add_child(_prompt)
	_prompt.global_position = global_position + Vector2(-12.0, -70.0)


func _interact_key_name() -> String:
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
	return "Interact"


func _try_open(body: Node2D) -> void:
	if is_cooling_down:
		return
		
	if not _can_open(body):
		return
		
	if destination_door_id.is_empty():
		push_warning("Door '%s' has no destination_door_id assigned!" % door_id)
		return

	if not destination_scene_path.is_empty():
		SceneManager.change_scene(destination_scene_path, destination_door_id)
		return

	_teleport_locally(body)

func _can_open(player: Node2D) -> bool:
	if is_locked:
		print("Door is locked!")
		return false
		
	if not required_item.is_empty() and player.has_method("has_item"):
		if not player.has_item(required_item):
			print("You need the ", required_item, " to enter!")
			return false
			
	if require_enemies_defeated:
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

	SceneManager.fade_and_run(func():
		player.global_position = target_door.spawn_point.global_position
		target_door._start_cooldown()
		target_door._arrive(player)
		_snap_cameras(player)
	)

func _start_cooldown() -> void:
	is_cooling_down = true
	get_tree().create_timer(COOLDOWN_TIME).timeout.connect(func(): is_cooling_down = false)

func _spawn_player() -> void:
	var player = get_tree().get_first_node_in_group("players")
	if player:
		player.global_position = spawn_point.global_position
		_arrive(player)
		_snap_cameras(player)
		SceneManager.target_door_id = ""

## Called on the door the player comes OUT of: puts them on this door's floor.
func _arrive(player: Node2D) -> void:
	var walker := player as Walker
	if walker == null:
		return
	walker.floor_id = door_floor_id
	walker.elevation = (spawn_point.global_position.y - walker.start_y) if auto_elevation else door_elevation
	walker.refresh_z()   # draw order and which walls we collide with follow the floor

func _find_door_in_scene(target_id: String) -> Door:
	for door in get_tree().get_nodes_in_group("doors"):
		if door is Door and door.door_id == target_id:
			return door
	return null

func _snap_cameras(player: Node2D) -> void:
	if "current_slope" in player: player.current_slope = 0.0

	var player_cam = player.get_node_or_null("Camera2D")
	if player_cam and player_cam is Camera2D:
		player_cam.position_smoothing_enabled = false
		player_cam.global_position = player.global_position
		player_cam.reset_smoothing()
		
		get_tree().create_timer(0.1).timeout.connect(func(): 
			if is_instance_valid(player_cam):
				player_cam.position_smoothing_enabled = true
		)

	var level_cam := get_tree().get_first_node_in_group("level_camera") as LevelCamera
	if level_cam:
		level_cam.snap()
