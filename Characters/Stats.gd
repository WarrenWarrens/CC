class_name Stats
extends Node
## Per-player stats. Add as a child Node named "Stats" in Player.tscn.
## Same variable names and rules as your PlayerStats autoload, so StatBar can read it with get(stat) as before.
## Differences: no game_over() reload (it emits `died`; GameSession decides what happens), and
## apply_character() sets the maximums from a CharacterDef.

signal died

var health := 100
var max_health := 200
var action := true

var stamina := 20.0
var max_stamina := 20.0
var stamina_regen := 6.0
var stamina_regen_delay := 1.0
var _stamina_timer := 0.0

var psy := 0.0
var max_psy := 100.0
var psy_chunks := 4
var psy_decay := 8.0
var psy_decay_delay := 3.0
var _psy_timer := 0.0
var _psy_floor := 0.0

var _dead := false


func apply_character(def: CharacterDef) -> void:
	max_health = def.max_health
	health = def.start_health
	max_stamina = def.max_stamina
	stamina = max_stamina
	stamina_regen = def.stamina_regen


func reset() -> void:
	health = mini(100, max_health)
	action = true
	stamina = max_stamina
	psy = 0.0
	_psy_floor = 0.0
	_stamina_timer = 0.0
	_psy_timer = 0.0
	_dead = false


func _process(delta: float) -> void:
	if _stamina_timer > 0.0:
		_stamina_timer -= delta
	elif stamina < max_stamina:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)

	if _psy_timer > 0.0:
		_psy_timer -= delta
	elif psy > _psy_floor:
		psy = maxf(psy - psy_decay * delta, _psy_floor)


func take_damage(amount: int) -> void:
	change_health(-amount)
	if health <= 0 and not _dead:
		_dead = true
		died.emit()


func change_health(amount: int) -> void:
	health = clampi(health + amount, 0, max_health)


func use_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	_stamina_timer = stamina_regen_delay
	return true


func add_psy(amount: float) -> void:
	psy = minf(psy + amount, max_psy)
	_update_psy_floor()
	_psy_timer = psy_decay_delay


func spend_psy(amount: float) -> bool:
	if psy < amount:
		return false
	psy -= amount
	_update_psy_floor()
	_psy_timer = psy_decay_delay
	return true


func _update_psy_floor() -> void:
	var chunk := max_psy / psy_chunks
	_psy_floor = floorf(psy / chunk + 0.0001) * chunk


func change_action(value: int) -> void:
	action = (value == 1)


func get_health() -> String:
	return str(health)


func get_action() -> bool:
	return action
