extends Node
# Mock database of what the player is currently carrying


var items = [
	{
		"id": "handgun",
		"name": "Handgun",
		"description": "A standard 9mm issue. Reliable but low stopping power.",
		"type": "weapon",
		"quantity": 1,
		"icon": "res://Assets/place.png", 
		"actions": ["Equip", "Examine"]
	},
	
	{
		"id": "combat_knife",
		"name": "Survival Knife",
		"description": "A sharp tactical knife. Good for emergencies.",
		"type": "weapon",
		"quantity": 1,
		"icon": "res://Assets/place.png", 
		"actions": ["Equip", "Examine", "Drop"]
	},
	
	{
		"id": "bat",
		"name": "Baseball Bat",
		"description": "I hate baseball",
		"type": "weapon",
		"quantity": 1,
		"icon": "res://Assets/place.png", 
		"actions": ["Equip", "Examine"]
	},
	
	{
		"id": "shotgun_ammo",
		"name": "Shotgun Ammo",
		"description": "12 Gauge buckshot, used for hunting",
		"type": "weapon",
		"quantity": 0,
		"icon": "res://Assets/ShotgunAmmo.png", 
		"actions": ["Examine", "Combine", "Drop"]
	},
	
	{
		"id": "energy_drink",
		"name": "Energy Drink",
		"description": "200mg of caffine, runs most blue collar workers",
		"type": "heal",
		"quantity": 2,
		"icon": "res://Assets/EnergyDrink.png", 
		"actions": ["Use", "Examine", "Drop"]
	},
	
	{
		"id": "green_herb",
		"name": "Green Herb",
		"description": "A simple biological remedy to pain",
		"type": "heal",
		"quantity": 3,
		"icon": "res://Assets/GreenHerb.png", 
		"actions": ["Use", "Examine", "Combine", "Drop"]
	},
	
	{
		"id": "red_herb",
		"name": "Red Herb",
		"description": "Disgusting on its own",
		"type": "heal",
		"quantity": 5,
		"icon": "res://Assets/RedHerb.png", 
		"actions": ["Use","Examine", "Combine", "Drop"]
	},
	
	{
		"id": "library_key",
		"name": "Library Key",
		"description": "The key to the library, feels heavy",
		"type": "key",
		"quantity": 1,
		"icon": "res://Assets/place.png", 
		"actions": ["Use", "Examine"]
	},
	
	{
		"id": "pistol_ammo",
		"name": "Pistol Ammo",
		"description": "Standard 9mm parabellum rounds.",
		"type": "ammo",
		"quantity": 21,
		"icon": "res://Assets/PistolAmmo.png", 
		"actions": ["Examine", "Combine", "Drop"]
	}
]

func add_item(target_id: String, amount: int):
	for item in items:
		if item["id"] == target_id:
			item["quantity"] += amount
			return 
	print("ERROR: Item ID " + target_id + " not found in database")

func remove_item(target_id: String, amount: int):
	for item in items:
		if item["id"] == target_id:
			item["quantity"] -= amount
			if item["quantity"] < 0:
				item["quantity"] = 0
			return
	
	print("ERROR: Item ID " + target_id + " not found in database")

func has_item(target_id: String) -> bool:
	for item in items:
		if item["id"] == target_id and item["quantity"] > 0:
			return true
	return false
