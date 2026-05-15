# GameOver.gd
extends Control

@onready var retry_btn: Button = $Center/VBox/RetryButton
@onready var menu_btn: Button = $Center/VBox/MenuButton
@onready var stats_label: Label = $Center/VBox/StatsLabel


func _ready() -> void:
	retry_btn.pressed.connect(_on_retry)
	menu_btn.pressed.connect(_on_menu)
	stats_label.text = "Этаж: %d\nУбийств: %d\nМонет собрано: %d" % [
		GameState.run_floor, GameState.kills_this_run,
		GameState.coins_collected_total
	]


func _on_retry() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/ui/Game.tscn")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
