extends Node
## Autoload (Project Settings > Autoload, name it exactly "Audio"). One place for all sound.
##
##   Audio.play(&"hit")                      a sound effect, looked up by name
##   Audio.play(&"step", -8.0)               quieter (volume in dB: 0 = normal, -6 = about half)
##   Audio.play_music(my_stream)             background music, loops until stopped
##
## Sound effects are plain files named after the sound, in res://Audio/sfx/ (.wav, .ogg or .mp3):
## Audio/sfx/hit.wav  ->  Audio.play(&"hit"). To change a sound, replace its file. A missing file is skipped silently.
## The "Music" and "SFX" buses are created here. Volume sliders (main menu, pause menu) use
##   Audio.get_volume(&"Music")  and  Audio.set_volume(&"Music", 0.5)   (0.0 = silent, 1.0 = full)
## and Audio.save_settings() writes the choice to disk; it is loaded again at the next start.

const SFX_DIR := "res://Audio/sfx/"
const EXTENSIONS := ["wav", "ogg", "mp3"]
const POOL_SIZE := 8     # how many sound effects can play at the same moment
const SETTINGS_PATH := "user://settings.cfg"

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _cache := {}         # sound name -> AudioStream (or null if there is no file)
var _volumes := {&"Music": 0.8, &"SFX": 1.0}    # bus name -> 0.0 to 1.0 (the defaults)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # keep playing (and previewing sounds) while the game is paused
	_make_bus(&"Music")
	_make_bus(&"SFX")
	_music.bus = &"Music"
	_music.finished.connect(_music.play)      # loop, whatever the file's import settings are
	add_child(_music)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_load_settings()


## Plays a sound effect. `pitch_variation` randomises the pitch a little so repeated hits don't sound identical.
func play(sound: StringName, volume_db := 0.0, pitch_variation := 0.08) -> void:
	var stream := _find(sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()


## Starts a music track. Calling it again with the track that is already playing does nothing.
func play_music(stream: AudioStream, volume_db := -6.0) -> void:
	if stream == null or (_music.playing and _music.stream == stream):
		return
	_music.stream = stream
	_music.volume_db = volume_db
	_music.play()


func stop_music() -> void:
	_music.stop()


## Volume of a bus as 0.0 (silent) to 1.0 (full): a slider can call this directly.
func set_volume(bus: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_volumes[bus] = linear
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in _volumes:
		cfg.set_value("audio", String(bus), _volumes[bus])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)      # no file yet = the defaults are used
	for bus in _volumes.keys():
		set_volume(bus, cfg.get_value("audio", String(bus), _volumes[bus]))


func _find(sound: StringName) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [SFX_DIR, sound, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[sound] = stream
	return stream


func _make_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
