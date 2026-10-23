extends Node
## Autoload (Project Settings > Autoload, name it exactly "Audio"). One place for all sound.
##
##   Audio.play(&"hit")                      a sound effect, looked up by name
##   Audio.play(&"step", -8.0)               quieter (volume in dB: 0 = normal, -6 = about half)
##   Audio.play_music(my_stream)             background music, loops until stopped
##
## Sound effects are plain files named after the sound, in res://Audio/sfx/ (.wav, .ogg or .mp3):
## Audio/sfx/hit.wav  ->  Audio.play(&"hit"). To change a sound, replace its file. A missing file is skipped silently.
## The "Music" and "SFX" buses are created here, so you can mute or fade either one: Audio.set_volume(&"Music", 0.5).

const SFX_DIR := "res://Audio/sfx/"
const EXTENSIONS := ["wav", "ogg", "mp3"]
const POOL_SIZE := 8     # how many sound effects can play at the same moment

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _cache := {}         # sound name -> AudioStream (or null if there is no file)


func _ready() -> void:
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


## Volume of a bus as 0.0 (silent) to 1.0 (full): a slider in an options menu can call this directly.
func set_volume(bus: StringName, linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(linear))


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
