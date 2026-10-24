class_name SoftLight
extends PointLight2D
## A round, soft light that makes its own glow texture: add the node, pick a colour, energy and radius. Nothing else to set up.
## Use it for street lamps, torches, windows, a fire... Give it `flicker` for anything that burns.
## For shadows, set shadow_enabled and put a LightOccluder2D on the things that should block it.

@export var radius := 96.0               # how far the light reaches, in pixels
@export_range(0.0, 1.0) var flicker := 0.0   # 0 = steady, 0.15 = a gentle candle

var _base_energy := 1.0
var _time := randf() * 100.0             # so lamps next to each other don't flicker in sync


func _ready() -> void:
	if texture == null:
		texture = _make_glow()
	texture_scale = radius / (texture.get_width() * 0.5)
	_base_energy = energy


func _process(delta: float) -> void:
	if flicker <= 0.0:
		return
	_time += delta
	energy = _base_energy * (1.0 + flicker * sin(_time * 13.0) * sin(_time * 7.3))


## A one-shot light that fades out and removes itself (a muzzle flash, an explosion, a spark).
## Add it to the LEVEL (e.g. the player's parent), not to the player, so it doesn't turn or flip with it.
static func flash(parent: Node, at: Vector2, color := Color(1.0, 0.8, 0.4), peak_energy := 2.0, glow_radius := 70.0, duration := 0.08) -> void:
	var light := SoftLight.new()
	light.color = color
	light.energy = peak_energy
	light.radius = glow_radius
	parent.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "energy", 0.0, duration)
	tween.tween_callback(light.queue_free)


func _make_glow() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])   # bright centre, soft edge
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t
