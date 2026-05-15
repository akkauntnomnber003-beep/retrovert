# BloodSplatter.gd
# Plays a 4-frame splat animation, then frees itself.
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.play("splat")
	sprite.animation_finished.connect(queue_free)
