# HitFlash.gd
# Quick white flash over an arbitrary Sprite2D / AnimatedSprite2D.
extends Node2D

@export var duration: float = 0.12


func flash(target: CanvasItem) -> void:
	if target == null:
		return
	target.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var t := create_tween()
	t.tween_property(target, "modulate", Color.WHITE, duration)
