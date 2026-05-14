# BombItem.gd
# A live bomb dropped by the player. Detonates after a fuse, dealing
# splash damage to enemies and spawning an explosion effect.
extends Node2D

const FUSE_TIME := 2.0
const RADIUS := 90.0
const DAMAGE := 30.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	var t := get_tree().create_timer(FUSE_TIME)
	t.timeout.connect(_explode)
	# Visual fuse animation: blink red.
	var tw := create_tween().set_loops(int(FUSE_TIME / 0.2))
	tw.tween_property(self, "modulate", Color(1.5, 0.6, 0.6), 0.1)
	tw.tween_property(self, "modulate", Color.WHITE, 0.1)


func _explode() -> void:
	EventBus.camera_shake.emit(14.0, 0.45)
	AudioManager.play_sfx("explosion")
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) <= RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(DAMAGE)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.global_position.distance_to(global_position) <= RADIUS * 0.7:
		if player.has_method("take_damage"):
			player.take_damage(1.0)
	# Visual explosion
	if ResourceLoader.exists("res://scenes/effects/Explosion.tscn"):
		var scene: PackedScene = load("res://scenes/effects/Explosion.tscn")
		var explosion: Node2D = scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
	queue_free()
