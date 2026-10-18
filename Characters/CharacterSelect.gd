#extends Control
### Dummy character-select screen. Make a new scene with a Control root, attach this script, and save it as
### the scene GameSession.SELECT_SCENE points to. The whole UI is built in code, so there is nothing else to set up.
### Each row: join checkbox, character dropdown, colour picker (the skin tint). Player 1 is always in.
#
#var _rows: Array[Dictionary] = []
#
#
#func _ready() -> void:
	#set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # a root Control would otherwise be 0x0
	#var margin := MarginContainer.new()
	#margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#for side in ["left", "right", "top", "bottom"]:
		#margin.add_theme_constant_override("margin_" + side, 24)
	#add_child(margin)
#
	#var box := VBoxContainer.new()
	#box.add_theme_constant_override("separation", 10)
	#margin.add_child(box)
#
	#var title := Label.new()
	#title.text = "Choose your fighters"
	#box.add_child(title)
#
	#for i in GameSession.MAX_PLAYERS:
		#box.add_child(_make_row(i))
#
	#var start := Button.new()
	#start.text = "Start"
	#start.pressed.connect(_on_start)
	#box.add_child(start)
	#start.grab_focus()
#
	#var back := Button.new()
	#back.text = "Back"
	#back.pressed.connect(GameSession.back_to_menu)
	#box.add_child(back)
#
#
#func _make_row(i: int) -> HBoxContainer:
	#var row := HBoxContainer.new()
	#row.add_theme_constant_override("separation", 12)
#
	#var join := CheckBox.new()
	#join.text = "Player %d" % (i + 1)
	#join.button_pressed = (i == 0)
	#join.disabled = (i == 0)
	#row.add_child(join)
#
	#var pick := OptionButton.new()
	#for d in GameSession.roster:
		#pick.add_item(d.display_name)
	#row.add_child(pick)
#
	#var color := ColorPickerButton.new()
	#color.custom_minimum_size = Vector2(56, 0)
	#color.color = GameSession.roster[0].main_color
	#row.add_child(color)
#
	## choosing a character resets the colour to that character's default
	#pick.item_selected.connect(func(idx: int): color.color = GameSession.roster[idx].main_color)
#
	#_rows.append({"join": join, "pick": pick, "color": color})
	#return row
#
#
#func _on_start() -> void:
	#GameSession.slots.clear()
	#for r in _rows:
		#if r["join"].button_pressed:
			#var def: CharacterDef = GameSession.roster[r["pick"].selected]
			#GameSession.slots.append({"def": def, "tint": r["color"].color})
	#GameSession.start_level()
extends Control
## Dummy character-select screen. Make a new scene with a Control root, attach this script, and save it as
## the scene GameSession.SELECT_SCENE points to. The whole UI is built in code, so there is nothing else to set up.
## Each row: join checkbox, character dropdown, colour picker (the skin tint). Player 1 is always in.

var _rows: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # a root Control would otherwise be 0x0
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Choose your fighters"
	box.add_child(title)

	for i in GameSession.MAX_PLAYERS:
		box.add_child(_make_row(i))

	var start := Button.new()
	start.text = "Start"
	start.pressed.connect(_on_start)
	box.add_child(start)
	start.grab_focus()

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(GameSession.back_to_menu)
	box.add_child(back)


func _make_row(i: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var join := CheckBox.new()
	join.text = "Player %d" % (i + 1)
	join.button_pressed = (i == 0)
	join.disabled = (i == 0)
	row.add_child(join)

	var pick := OptionButton.new()
	for d in GameSession.roster:
		pick.add_item(d.display_name)
	row.add_child(pick)

	var color := ColorPickerButton.new()
	color.custom_minimum_size = Vector2(56, 0)
	color.color = GameSession.roster[0].main_color
	row.add_child(color)

	# choosing a character resets the colour to that character's default
	pick.item_selected.connect(func(idx: int): color.color = GameSession.roster[idx].main_color)

	_rows.append({"join": join, "pick": pick, "color": color})
	return row


func _on_start() -> void:
	GameSession.slots.clear()
	for r in _rows:
		if r["join"].button_pressed:
			var def: CharacterDef = GameSession.roster[r["pick"].selected]
			GameSession.slots.append({"def": def, "tint": r["color"].color})
	GameSession.start_level()
