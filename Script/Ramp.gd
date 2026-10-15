class_name Ramp
extends Area2D
## ONE Ramp node per ramp, with exactly ONE 4-point CollisionPolygon2D child.

## Must match the angle of the ramp's long sides. Your 45 degree art needs 45.
@export_range(1.0, 80.0) var angle_degrees := 45.0
@export var rises_to_right := true
## 0 = compute the rise from the polygon. If the camera ends a few px off a floor,
## set this to the exact pixel difference between the two floor bands
## (centre of the lower floor's walkable strip minus centre of the upper one).
@export var rise_override := 0.0
## The two floor numbers this ramp joins (match your Floor0, Floor1... containers).
@export var low_floor := 0
@export var high_floor := 1

## Screen-Y shift from walking fully across, left to right (negative = goes up the screen).
var rise := 0.0

var _footprints: Array[Dictionary] = []


func get_slope() -> float:
	var s := tan(deg_to_rad(angle_degrees))
	return -s if rises_to_right else s


func _ready() -> void:
	add_to_group("ramps")
	body_entered.connect(func(b): if b.has_method("enter_ramp"): b.enter_ramp(self))
	body_exited.connect(func(b): if b.has_method("exit_ramp"): b.exit_ramp(self))
	_build_footprints()
	if _footprints.size() > 1:
		push_warning("%s has %d polygons. Use one Ramp node per polygon so each can have its own floors." % [name, _footprints.size()])
	if not _footprints.is_empty():
		rise = _footprints[0].rise


# --- floors -----------------------------------------------------------------

func floor_left() -> int:
	return low_floor if rises_to_right else high_floor


func floor_right() -> int:
	return high_floor if rises_to_right else low_floor


func connects(f: int) -> bool:
	return f == low_floor or f == high_floor


## 0.0 if floor f is at the left end of this ramp, 1.0 if at the right end, -1.0 if not joined.
func end_progress_for(f: int) -> float:
	if f == floor_left():
		return 0.0
	if f == floor_right():
		return 1.0
	return -1.0


## 0 at the left end edge, 1 at the right end edge (not clamped).
func progress_at(p: Vector2) -> float:
	if _footprints.is_empty():
		return 0.0
	var sp := _split(_footprints[0], p)
	var run := sp.x + sp.y
	return sp.x / run if run > 0.0 else 0.0


func floor_at(progress: float) -> int:
	return floor_left() if progress < 0.5 else floor_right()


# --- geometry ---------------------------------------------------------------

func _build_footprints() -> void:
	var d := Vector2(1.0, get_slope())   # moving right by 1 changes y by slope
	for child in get_children():
		if not (child is CollisionPolygon2D):
			continue
		var pts: Array = []
		for p in child.polygon:
			pts.append(child.to_global(p))
		if pts.size() != 4:
			push_warning("Ramp footprint needs exactly 4 points: " + str(child.name))
			continue
		# The walker enters and leaves through the two edges that are NOT parallel to the climb direction.
		# (Picking them by x position breaks on 45 degree art, where the top corner can sit left of the bottom one.)
		var dn := d.normalized()
		var edges: Array = []
		for i in 4:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 4]
			edges.append({
				"a": a,
				"e": b - a,
				"mid": (a + b) * 0.5,
				"cross": absf(dn.cross((b - a).normalized())),
			})
		edges.sort_custom(func(x, y): return x["cross"] > y["cross"])
		var pair: Array = [edges[0], edges[1]]
		pair.sort_custom(func(x, y): return x["mid"].dot(dn) < y["mid"].dot(dn))   # start edge first
		var f := {
			"lo": pair[0]["a"], "le": pair[0]["e"],
			"ro": pair[1]["a"], "re": pair[1]["e"],
		}
		f["ld"] = d.cross(f.le)
		f["rd"] = d.cross(f.re)
		var center: Vector2 = (pts[0] + pts[1] + pts[2] + pts[3]) / 4.0
		var sp := _split(f, center)
		f["rise"] = signf(get_slope()) * rise_override if rise_override > 0.0 else get_slope() * (sp.x + sp.y)
		_footprints.append(f)


# Distance (in x) from p back to the left edge and forward to the right edge, along the ramp direction
func _split(f: Dictionary, p: Vector2) -> Vector2:
	var s_left: float = (p - f.lo).cross(f.le) / f.ld
	var s_right: float = (f.ro - p).cross(f.re) / f.rd
	return Vector2(s_left, s_right)
