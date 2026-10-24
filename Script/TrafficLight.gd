class_name TrafficLight
extends SoftLight
## A light that cycles green, yellow, red. Add it where the lamp is. Other scripts can react to it:
##   traffic_light.changed.connect(func(state): ...)    or check   traffic_light.state == &"red"

signal changed(state: StringName)

@export var green_time := 4.0
@export var yellow_time := 1.2
@export var red_time := 4.0
@export var green := Color(0.3, 1.0, 0.4)
@export var yellow := Color(1.0, 0.85, 0.2)
@export var red := Color(1.0, 0.25, 0.2)
@export var start_offset := 0.0          # seconds into the cycle at the start; different values keep a row of lights out of sync

var state: StringName = &""
var _clock := 0.0


func _ready() -> void:
	super()
	_clock = start_offset
	_update_state()


func _process(delta: float) -> void:
	_clock += delta
	_update_state()


func _update_state() -> void:
	var t := fmod(_clock, green_time + yellow_time + red_time)
	var now: StringName = &"green"
	if t >= green_time + yellow_time:
		now = &"red"
	elif t >= green_time:
		now = &"yellow"
	if now == state:
		return
	state = now
	color = {&"green": green, &"yellow": yellow, &"red": red}[now]
	changed.emit(now)
