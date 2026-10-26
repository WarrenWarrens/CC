class_name LevelLighting
extends Node
## The level's overall light: add ONE of these to a level and set the colours in the Inspector.
##
##   ambient  = the light everything gets, even far from any lamp. Darker + bluer = night, white = no change.
##   sun      = an extra directional light on top (warm colour, lower energy for evening).
##
## Octopath-style look: warm sun, cool blue-ish ambient, then small SoftLights (lamps) on top.
## The HUD sits on its own layer, so it is NOT darkened.

@export var ambient := Color(0.55, 0.6, 0.8)
@export var sun_color := Color(1.0, 0.88, 0.65)
@export_range(0.0, 2.0) var sun_energy := 0.55
@export_range(-180.0, 180.0) var sun_angle := -30.0     # direction the light comes from (only matters with shadows or normal maps)
@export var sun_shadows := false


func _ready() -> void:
	var canvas := CanvasModulate.new()
	canvas.color = ambient
	add_child(canvas)

	var sun := DirectionalLight2D.new()
	sun.color = sun_color
	sun.energy = sun_energy
	sun.rotation_degrees = sun_angle
	sun.shadow_enabled = sun_shadows
	add_child(sun)
