extends Node

var health = 100
var max_health = 200
var action = true

func reset():
	health = 100
	action = true
	
func _ready() -> void:
	pass 

func _process(delta: float) -> void:
	pass

func take_damage(amount: int):
	var damage_to_health = amount 
	change_health(-damage_to_health)
	
	if health <= 0:
		game_over()
		
func game_over():
	reset()
	get_tree().reload_current_scene()

func change_health(amount: int):
	health = clamp(health + amount, 0, max_health)

func change_action(value: int):
	action = (value == 1)
	
func get_health() -> String:
	return str(health)

func get_action() -> bool:
	return action
