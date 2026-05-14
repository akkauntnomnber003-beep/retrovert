# PauseMenu.gd
extends Control

@onready var resume_btn: Button = $Panel/VBox/ResumeButton
@onready var menu_btn: Button = $Panel/VBox/MenuButton
@onready var quit_btn: Button = $Panel/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(_on_resume)
	menu_btn.pressed.connect(_on_menu)
	quit_btn.pressed.connect(_on_quit)


func _on_resume() -> void:
	get_tree().paused = false
	queue_free()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_quit() -> void:
	get_tree().quit()
