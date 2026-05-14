# Pickup.gd
# Base script used by Coin / Heart / Bomb / Key. Subclasses set kind and
# amount in _init / _ready.
extends Area2D
class_name Pickup

@export var kind: String = "coin"
@export var amount: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 1 << 5
	collision_mask = 1 << 1   # player
	body_entered.connect(_on_body_entered)
	_apply_visual()


func _apply_visual() -> void:
	var tex: String = ""
	match kind:
		"coin": tex = "res://assets/sprites/pickups/coin.png"
		"coin_double": tex = "res://assets/sprites/pickups/coin_double.png"
		"heart_red": tex = "res://assets/sprites/pickups/heart_red.png"
		"heart_half": tex = "res://assets/sprites/pickups/heart_half.png"
		"heart_soul": tex = "res://assets/sprites/pickups/heart_soul.png"
		"bomb": tex = "res://assets/sprites/pickups/bomb.png"
		"key": tex = "res://assets/sprites/pickups/key.png"
	if tex != "" and ResourceLoader.exists(tex):
		sprite.texture = load(tex)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_apply_effect()
	EventBus.pickup_collected.emit(kind, amount)
	AudioManager.play_sfx("pickup_" + kind)
	queue_free()


func _apply_effect() -> void:
	match kind:
		"coin": GameState.add_coins(1)
		"coin_double": GameState.add_coins(2)
		"heart_red": GameState.heal_red(2.0)
		"heart_half": GameState.heal_red(1.0)
		"heart_soul": GameState.heal_soul(2.0)
		"bomb": GameState.add_bombs(1)
		"key": GameState.add_keys(1)
