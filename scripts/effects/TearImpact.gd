# TearImpact.gd
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.play("hit")
	sprite.animation_finished.connect(queue_free)
