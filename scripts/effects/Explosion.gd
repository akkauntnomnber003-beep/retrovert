# Explosion.gd
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.play("boom")
	sprite.animation_finished.connect(queue_free)
