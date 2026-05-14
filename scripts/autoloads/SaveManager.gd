# SaveManager.gd
# Persists settings and high-scores to user://save.cfg
extends Node

const SAVE_PATH := "user://save.cfg"


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in GameState.settings:
		cfg.set_value("settings", key, GameState.settings[key])
	cfg.set_value("progress", "deaths_total", GameState.deaths_total)
	cfg.set_value("progress", "coins_collected_total",
		GameState.coins_collected_total)
	cfg.set_value("progress", "kills_total", GameState.kills_this_run)
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in cfg.get_section_keys("settings") if cfg.has_section("settings") else []:
		GameState.settings[key] = cfg.get_value("settings", key)
	if cfg.has_section("progress"):
		GameState.deaths_total = int(
			cfg.get_value("progress", "deaths_total", 0))
		GameState.coins_collected_total = int(
			cfg.get_value("progress", "coins_collected_total", 0))


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
