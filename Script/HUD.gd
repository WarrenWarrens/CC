extends CanvasLayer

func bind(player_stats: Node) -> void:
	for bar in $VBoxContainer.get_children():
		if bar is StatBar:
			bar.bind(player_stats)
