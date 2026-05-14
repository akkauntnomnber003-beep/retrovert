# MainMenu.gd
extends Control

@onready var play_btn: Button = $Center/VBox/PlayButton
@onready var mods_btn: Button = $Center/VBox/ModsButton
@onready var docs_btn: Button = $Center/VBox/DocsButton
@onready var settings_btn: Button = $Center/VBox/SettingsButton
@onready var quit_btn: Button = $Center/VBox/QuitButton


func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	mods_btn.pressed.connect(_on_mods)
	docs_btn.pressed.connect(_on_docs)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)


func _on_play() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/ui/Game.tscn")


func _on_mods() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModManager.tscn")


func _on_docs() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModDocs.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")


func _on_quit() -> void:
	get_tree().quit()
