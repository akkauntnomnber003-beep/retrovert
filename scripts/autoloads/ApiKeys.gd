# ApiKeys.gd
# Loads user-supplied API keys (OpenRouter, Telegram, etc.) from
# user://settings/api_keys.cfg. Never commit real keys; mods read from
# here at runtime through ModAPI.keys.
extends Node

const FILE_PATH := "user://settings/api_keys.cfg"

var _keys: Dictionary = {}


func _ready() -> void:
	_ensure_dir()
	load_keys()


func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://settings"))


func load_keys() -> void:
	_keys.clear()
	if not FileAccess.file_exists(FILE_PATH):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(FILE_PATH)
	if err != OK:
		push_warning("ApiKeys: failed to load %s" % FILE_PATH)
		return
	for sec in cfg.get_sections():
		var d: Dictionary = {}
		for k in cfg.get_section_keys(sec):
			d[k] = cfg.get_value(sec, k, "")
		_keys[sec] = d


func save_keys() -> void:
	_ensure_dir()
	var cfg := ConfigFile.new()
	for sec in _keys.keys():
		for k in _keys[sec].keys():
			cfg.set_value(sec, k, _keys[sec][k])
	cfg.save(FILE_PATH)


func get_key(service: String, name: String = "default") -> String:
	var sec: Dictionary = _keys.get(service, {})
	return String(sec.get(name, ""))


func set_key(service: String, name: String, value: String) -> void:
	if not _keys.has(service):
		_keys[service] = {}
	_keys[service][name] = value
	save_keys()


func remove_key(service: String, name: String) -> void:
	if _keys.has(service) and _keys[service].has(name):
		_keys[service].erase(name)
		save_keys()


func list_services() -> Array:
	return _keys.keys()


func list_keys_in(service: String) -> Array:
	if not _keys.has(service):
		return []
	return _keys[service].keys()


func has(service: String, name: String = "default") -> bool:
	return get_key(service, name) != ""
