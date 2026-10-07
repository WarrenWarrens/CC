class_name Ramp
extends Area2D

@export_range(1.0, 80.0) var angle_degrees := 40.0
@export var rises_to_right := true
@export var rise_override := 0.0

var _footprints: Array[Dictionary] = []

func get_slope() -> float:
	var s := tan(deg_to_rad(angle_degrees))
	return -s if rises_to_right else s

func _ready() -> void:
	add_to_group("ramps")
	body_entered.connect(func(b): if b.has_method("enter_ramp"): b.enter_ramp(self))
	body_exited.connect(func(b): if b.has_method("exit_ramp"): b.exit_ramp(self))
	_build_footprints()

func _build_footprints() -> void:
	var d := Vector2(1.0, get_slope())   
	for child in get_children():
		if not (child is CollisionPolygon2D):
			continue
		var pts: Array = []
		for p in child.polygon:
			pts.append(child.to_global(p))
		if pts.size() != 4:
			push_warning("Ramp footprint needs exactly 4 points: " + str(child.name))
			continue
		pts.sort_custom(func(a, b): return a.x < b.x)   
		var f := {
			"lo": pts[0], "le": pts[1] - pts[0],
			"ro": pts[2], "re": pts[3] - pts[2],
		}
		f["ld"] = d.cross(f.le)
		f["rd"] = d.cross(f.re)
		var center: Vector2 = (pts[0] + pts[1] + pts[2] + pts[3]) / 4.0
		var sp := _split(f, center)
		f["rise"] = signf(get_slope()) * rise_override if rise_override > 0.0 else get_slope() * (sp.x + sp.y)
		_footprints.append(f)

func _split(f: Dictionary, p: Vector2) -> Vector2:
	var s_left: float = (p - f.lo).cross(f.le) / f.ld
	var s_right: float = (f.ro - p).cross(f.re) / f.rd
	return Vector2(s_left, s_right)

func get_elevation_shift(p: Vector2) -> float:
	var total := 0.0
	for f in _footprints:
		var sp := _split(f, p)
		var run := sp.x + sp.y
		if run <= 0.0:
			continue
		total += f.rise * clampf(sp.x / run, 0.0, 1.0)
	return total
