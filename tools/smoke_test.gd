# Smoke test: boots Game scene briefly to surface runtime errors.
extends SceneTree


func _initialize() -> void:
	var s: PackedScene = load("res://scenes/ui/Game.tscn")
	if s == null:
		push_error("Game.tscn failed to load")
		quit(1)
		return
	change_scene_to_packed(s)
	# Give the scene some time to initialise.
	await create_timer(2.0).timeout
	print("Smoke test OK — Game.tscn ran for 2 s without crashing.")
	quit(0)
