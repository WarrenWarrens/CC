class_name EncounterZone
extends Area2D
## A fight arena. When a player walks into it: the way forward and back is blocked, the camera stops scrolling,
## enemies spawn, and everything opens again once they are all dead.
##
## Scene:  EncounterZone (this script)
##           > CollisionShape2D   a RectangleShape2D covering the whole arena (make it at least as wide as the screen, 640)
##           > Marker2D ...       optional spawn points (any number, any names). With none, enemies come in from the left/right edges.
## The player is checked by position, so the Area2D's own collision settings don't matter.

signal started
signal wave_started(wave: int)
signal cleared

@export var enemy_scene: PackedScene                 # your Enemy.tscn
## One enemy is spawned per entry, each with its own EnemyDef. Empty = `count` default enemies.
@export var roster: Array[EnemyDef] = []
@export var count := 3
@export var waves := 1                               # the roster is spawned again for every extra wave
@export var wave_delay := 1.5
@export var floor_id := 0                            # the walls only block walkers on this floor
@export var trigger_margin := 40.0                   # the player must be this far inside before it starts
@export var lock_camera := true
@export var wall_thickness := 24.0

enum S { IDLE, FIGHTING, WAITING, DONE }
var _state := S.IDLE
var _wave := 0
var _timer := 0.0
var _alive := {}                                     # instance id -> true, for living enemies of this encounter
var _walls: Array[StaticBody2D] = []
var _camera: Camera2D
var _saved_limits := []


func _ready() -> void:
	monitoring = false
	monitorable = false


func _physics_process(delta: float) -> void:
	match _state:
		S.IDLE:
			if _player_inside() != null:
				_start()
		S.FIGHTING:
			if _alive.is_empty():
				if _wave >= waves:
					_finish()
				else:
					_state = S.WAITING
					_timer = wave_delay
		S.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_next_wave()


func _arena_rect() -> Rect2:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rs := cs.shape as RectangleShape2D if cs else null
	if rs == null:
		push_error("EncounterZone '%s' needs a CollisionShape2D with a RectangleShape2D." % name)
		return Rect2()
	return Rect2(cs.global_position - rs.size * 0.5, rs.size)


func _player_inside() -> Walker:
	var inner := _arena_rect().grow(-trigger_margin)
	for p in get_tree().get_nodes_in_group("players"):
		var w := p as Walker
		if w != null and w.floor_id == floor_id and inner.has_point(w.global_position):
			return w
	return null


func _start() -> void:
	_state = S.FIGHTING
	_wave = 0
	_lock()
	started.emit()
	_next_wave()


func _finish() -> void:
	_state = S.DONE
	_unlock()
	cleared.emit()


func _next_wave() -> void:
	_wave += 1
	_state = S.FIGHTING
	wave_started.emit(_wave)
	var r := _arena_rect()
	var markers: Array[Marker2D] = []
	for c in get_children():
		if c is Marker2D:
			markers.append(c)
	var total := roster.size() if not roster.is_empty() else count
	for i in total:
		var pos: Vector2
		if not markers.is_empty():
			pos = markers[i % markers.size()].global_position
		else:
			var x := r.position.x + 24.0 if i % 2 == 0 else r.end.x - 24.0
			pos = Vector2(x, randf_range(r.position.y + 20.0, r.end.y - 20.0))
		_spawn(roster[i] if not roster.is_empty() else null, pos)


func _spawn(def: EnemyDef, pos: Vector2) -> void:
	if enemy_scene == null:
		push_error("EncounterZone '%s' has no enemy_scene." % name)
		return
	var e := enemy_scene.instantiate() as Enemy
	if e == null:
		push_error("EncounterZone '%s': enemy_scene's root must use Enemy.gd." % name)
		return
	if def:
		e.def = def
	e.floor_id = floor_id
	get_parent().add_child(e)
	e.global_position = pos
	e.aggro(_nearest_player(pos))
	e.modulate.a = 0.0
	create_tween().tween_property(e, "modulate:a", 1.0, 0.3)
	_alive[e.get_instance_id()] = true
	e.died.connect(_on_enemy_gone)
	e.tree_exited.connect(_on_enemy_gone.bind(e))   # also counts an enemy that was removed some other way


func _on_enemy_gone(enemy: Enemy) -> void:
	_alive.erase(enemy.get_instance_id())


func _nearest_player(from: Vector2) -> Walker:
	var best: Walker = null
	for p in get_tree().get_nodes_in_group("players"):
		var w := p as Walker
		if w != null and (best == null or w.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = w
	return best


# --- the lock ------------------------------------------------------------------------------------

func _lock() -> void:
	var r := _arena_rect()
	var t := wall_thickness
	var size := Vector2(t, r.size.y + 400.0)
	_walls.append(_make_wall(Vector2(r.position.x - t * 0.5, r.get_center().y), size))
	_walls.append(_make_wall(Vector2(r.end.x + t * 0.5, r.get_center().y), size))
	if lock_camera:
		_camera = get_viewport().get_camera_2d()
		if _camera:
			_saved_limits = [_camera.limit_left, _camera.limit_right, _camera.limit_smoothed]
			_camera.limit_smoothed = true
			_camera.limit_left = int(r.position.x)
			_camera.limit_right = int(r.end.x)


func _unlock() -> void:
	for w in _walls:
		w.queue_free()
	_walls.clear()
	if _camera and is_instance_valid(_camera) and not _saved_limits.is_empty():
		_camera.limit_left = _saved_limits[0]
		_camera.limit_right = _saved_limits[1]
		_camera.limit_smoothed = _saved_limits[2]


func _make_wall(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Walker.floor_bit(floor_id)   # only blocks walkers on this floor
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	body.add_child(cs)
	add_child(body)
	body.global_position = center
	return body
