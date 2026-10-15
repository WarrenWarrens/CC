extends Node
## Autoload (Project Settings > Autoload, name it exactly "GameSession").
## Remembers who is playing as whom between the character-select screen and the level,
## and decides when the run is over.

const MAX_PLAYERS := 4
const CHARACTER_DIR := "res://Characters"
const SELECT_SCENE := "res://Scenes/CharacterSelect.tscn"   # change to your paths
const FIRST_LEVEL := "res://Scenes/WorldOne.tscn"

var roster: Array[CharacterDef] = []

## One entry per joined player: { "def": CharacterDef, "tint": Color }
var slots: Array[Dictionary] = []

var _alive := 0


func _ready() -> void:
	roster = _load_roster()
	if roster.is_empty():
		roster = _dummy_roster()   # so everything works before you've made any .tres files


## Slots to use when a level is run directly from the editor (nothing was selected).
func get_slots() -> Array[Dictionary]:
	if slots.is_empty():
		return [{"def": roster[0], "tint": roster[0].main_color}]
	return slots


func start_level(path := FIRST_LEVEL) -> void:
	_alive = 0
	get_tree().change_scene_to_file(path)


func open_select() -> void:
	get_tree().change_scene_to_file(SELECT_SCENE)


## Each Player calls this once it has its Stats.
func register_player(stats: Stats) -> void:
	_alive += 1
	stats.died.connect(_on_player_died)


func _on_player_died() -> void:
	_alive -= 1
	if _alive <= 0:
		_alive = 0
		get_tree().call_deferred("reload_current_scene")   # everyone down: restart the level


func _load_roster() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	var dir := DirAccess.open(CHARACTER_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		var file := f.trim_suffix(".remap")   # exported builds list resources with a .remap suffix
		if file.ends_with(".tres") or file.ends_with(".res"):
			var def := load("%s/%s" % [CHARACTER_DIR, file]) as CharacterDef
			if def:
				out.append(def)
	return out


func _dummy_roster() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	out.append(_make(&"brawler", "Brawler", 200, 20.0, 6.0, 1.0, Color(0.8, 0.2, 0.2), 0))
	out.append(_make(&"rusher", "Rusher", 150, 30.0, 8.0, 1.15, Color(0.2, 0.4, 0.9), 1))
	out.append(_make(&"tank", "Tank", 300, 15.0, 4.0, 0.85, Color(0.9, 0.8, 0.2), 2))
	return out


func _make(id: StringName, label: String, hp: int, stam: float, regen: float, speed: float, color: Color, style: int) -> CharacterDef:
	var d := CharacterDef.new()
	d.id = id
	d.display_name = label
	d.max_health = hp
	d.start_health = hp
	d.max_stamina = stam
	d.stamina_regen = regen
	d.speed_mult = speed
	d.main_color = color
	d.starting_style = style
	return d
