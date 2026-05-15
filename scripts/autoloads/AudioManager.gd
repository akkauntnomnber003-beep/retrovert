# AudioManager.gd
# Plays SFX/music with safe fall-backs when assets are absent (placeholders).
extends Node

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const SFX_POOL_SIZE := 16

var _sfx_players: Array = []
var _music_player: AudioStreamPlayer
var _sfx_cache: Dictionary = {}
var _current_music_path: String = ""


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		add_child(p)
		_sfx_players.append(p)


func _free_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]  # steal if all busy


func play_sfx(id: String, volume_db: float = 0.0,
		pitch_scale: float = 1.0) -> void:
	if not GameState.settings.get("sfx_volume", 1.0) > 0.0:
		return
	var stream := _load_sfx(id)
	if stream == null:
		return
	var p := _free_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()


func play_music(path: String, volume_db: float = -6.0) -> void:
	if _current_music_path == path and _music_player.playing:
		return
	_current_music_path = path
	if not ResourceLoader.exists(path):
		_music_player.stop()
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_current_music_path = ""


func _load_sfx(id: String) -> AudioStream:
	if _sfx_cache.has(id):
		return _sfx_cache[id]
	var path: String = "res://assets/audio/sfx/%s.wav" % id
	if not ResourceLoader.exists(path):
		_sfx_cache[id] = null
		return null
	var stream := load(path) as AudioStream
	_sfx_cache[id] = stream
	return stream
