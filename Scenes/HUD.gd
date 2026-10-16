extends CanvasLayer

# This receives the stats node from World.gd and passes it to every bar
func bind(player_stats: Node) -> void:
	# Loop through all the UI elements inside the VBoxContainer
	for bar in $VBoxContainer.get_children():
		# If the UI element is a StatBar, tell it to bind to the player
		if bar is StatBar:
			bar.bind(player_stats)
