class_name ItemDef
extends Resource
## One kind of item: a drink, a key, a power-up, a weapon... Make one .tres per item
## (FileSystem > right-click > Create New > Resource > ItemDef). Nothing here is tied to a crate or a level.

enum Kind { HEAL, STAMINA, PSY, KEY, POWERUP, WEAPON }

@export var id: StringName = &"item"               # e.g. &"red_key": what a door or weapon slot asks for
@export var display_name := "Item"                 # shown above the item when the player is near
@export var texture: Texture2D
@export var kind := Kind.HEAL
@export var amount := 20.0                         # heal / stamina / psy amount (ignored by keys)
@export var duration := 0.0                        # power-ups: seconds the effect lasts (0 = permanent)
@export var name_color := Color.WHITE              # label colour, handy for rarity (green, blue, gold...)


## False = leave it on the ground (a drink when you're already at full health).
func can_use(body: Node) -> bool:
	var s := body.get("stats") as Stats
	if s == null:
		return false
	match kind:
		Kind.HEAL:
			return s.health < s.max_health
		Kind.STAMINA:
			return s.stamina < s.max_stamina
	return true


## Applies the item to whoever picked it up (a Player). Add a new Kind and a new case here to add a new item type.
func apply(body: Node) -> void:
	var s := body.get("stats") as Stats
	match kind:
		Kind.HEAL:
			s.change_health(int(amount))
		Kind.STAMINA:
			s.stamina = minf(s.stamina + amount, s.max_stamina)
		Kind.PSY:
			s.add_psy(amount)
		Kind.KEY, Kind.POWERUP, Kind.WEAPON:
			# dummy for now: the Player stores it (see give_item in the notes). Doors, buffs and weapons read it later.
			if body.has_method("give_item"):
				body.give_item(self)
			else:
				print("%s picked up %s (no give_item on the player yet)" % [body.name, display_name])
