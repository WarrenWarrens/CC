class_name CharacterDef
extends Resource
## One selectable character. Make real ones in the editor: right-click in FileSystem > New Resource > CharacterDef,
## save them as .tres files in res://Characters/ and GameSession picks them up automatically.

@export var id: StringName = &"brawler"
@export var display_name := "Brawler"
@export var portrait: Texture2D

## Optional: a different SpriteFrames for this character. It must use the same animation names
## (Idle, Walk, Attack, Jump, Guard, Dodge, Stun...). Leave empty to keep the Player scene's sprite.
@export var sprite_frames: SpriteFrames

@export_group("Stats")
@export var max_health := 200
@export var start_health := 100
@export var max_stamina := 20.0
@export var stamina_regen := 6.0
@export var speed_mult := 1.0
@export_enum("Red", "Blue", "Yellow", "Purple") var starting_style := 0

@export_group("Colours")
@export var main_color := Color(0.75, 0.15, 0.15)
@export var accent_color := Color(0.15, 0.35, 0.75)


## Recolours a sprite. Uses the PaletteSwap5 shader if the sprite has it as its material;
## otherwise falls back to a plain tint (which also tints the outline).
func apply_skin(body: CanvasItem, tint: Color) -> void:
	var mat := body.material as ShaderMaterial
	if mat == null:
		body.self_modulate = tint
		return
	mat = mat.duplicate() as ShaderMaterial   # never edit the shared material
	body.material = mat
	_set_ramp(mat, "main", tint)
	_set_ramp(mat, "accent", accent_color)


func _set_ramp(mat: ShaderMaterial, prefix: String, base: Color) -> void:
	mat.set_shader_parameter(prefix + "_1_dst", base.darkened(0.45))
	mat.set_shader_parameter(prefix + "_2_dst", base.darkened(0.25))
	mat.set_shader_parameter(prefix + "_3_dst", base)
	mat.set_shader_parameter(prefix + "_4_dst", base.lightened(0.25))
	mat.set_shader_parameter(prefix + "_5_dst", base.lightened(0.45))
