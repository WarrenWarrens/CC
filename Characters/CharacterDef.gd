class_name CharacterDef
extends Resource
## One selectable character. Make real ones in the editor: right-click in FileSystem > New Resource > CharacterDef,
## save them as .tres files in res://Characters/ and GameSession picks them up automatically.

const SKIN_SHADER := preload("res://PaletteSwapSimple.gdshader")

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

@export_group("Moves")
## First move of the light and heavy attack chains. Empty = a plain default move.
@export var light_attack: AttackDef
@export var heavy_attack: AttackDef

@export_group("Special Moves")
## Used instead of the normal combo when the light / heavy button is pressed while SPRINTING.
@export var sprint_light_attack: AttackDef
@export var sprint_heavy_attack: AttackDef
## Used when the light / heavy button is pressed while JUMPING. Empty = no attack in the air.
@export var jump_light_attack: AttackDef
@export var jump_heavy_attack: AttackDef

@export_group("Colours")
## The colour of the sprite's red clothing. The default is the colour painted in the art, so it looks unchanged.
@export var main_color := Color("881830")


## Recolours the sprite's red ramp (dark, base and light) with PaletteSwapSimple.
## The sprite doesn't need a material: one is created the first time.
func apply_skin(body: CanvasItem, tint: Color) -> void:
	var mat := body.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SKIN_SHADER
	else:
		mat = mat.duplicate() as ShaderMaterial   # never edit a shared material
	body.material = mat
	mat.set_shader_parameter("dark_dst", tint.darkened(0.35))
	mat.set_shader_parameter("base_dst", tint)
	mat.set_shader_parameter("light_dst", tint.lightened(0.3))
