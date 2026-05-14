# WinScreen.gd
extends Control

@onready var menu_btn: Button = $Center/VBox/MenuButton
@onready var stats_label: Label = $Center/VBox/StatsLabel


func _ready() -> void:
	menu_btn.pressed.connect(_on_menu)
	stats_label.text = "Победа!\nУбийств: %d\nЭтажей: %d" % [
		GameState.kills_this_run, GameState.floors_cleared
	]


func _on_menu() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
