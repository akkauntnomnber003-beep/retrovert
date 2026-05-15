# Pickup.gd
# Base script used by Coin / Heart / Bomb / Key. Subclasses set kind and
# amount in _init / _ready.
#
# In addition to the original behaviour we add two things the rest of the
# game expects:
#   * scatter_impulse — initial velocity applied when an enemy drops the
#                       pickup, so loot tumbles out instead of plopping.
#   * magnet — once the player is within MAGNET_RADIUS the pickup
#              accelerates towards them. Avoids the "stand on the loot
#              spot exactly" problem from the C3 prototype.
extends Area2D
class_name Pickup

const MAGNET_RADIUS := 110.0
const MAGNET_SPEED  := 520.0
const SCATTER_DRAG  := 5.0

@export var kind: String = "coin"
@export var amount: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D

var scatter_impulse: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _life: float = 0.0


func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 1 << 5
	collision_mask = 1 << 1   # player
	body_entered.connect(_on_body_entered)
	_apply_visual()
	if scatter_impulse.length() > 1.0:
		_velocity = scatter_impulse
	_player = get_tree().get_first_node_in_group("player")
	set_process(true)
	# Tiny pop animation so the pickup feels alive.
	scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1, 1), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_life += delta
	# Drag scatter velocity to zero.
	if _velocity.length() > 1.0:
		_velocity = _velocity.move_toward(Vector2.ZERO, SCATTER_DRAG * delta * 100.0)
		position += _velocity * delta
	# Magnet — only after a tiny grace period so dropped loot doesn't
	# get sucked in before the player has reacted.
	if _life < 0.25:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var d: Vector2 = _player.global_position - global_position
	if d.length() < MAGNET_RADIUS:
		var pull: Vector2 = d.normalized() * MAGNET_SPEED * delta
		global_position += pull
		# Idle bob — gentle vertical wobble.
	sprite.position.y = sin(_life * 6.0) * 1.5


func _apply_visual() -> void:
	var tex: String = ""
	match kind:
		"coin":         tex = "res://assets/sprites/pickups/coin.png"
		"coin_double":  tex = "res://assets/sprites/pickups/coin_double.png"
		"heart_red":    tex = "res://assets/sprites/pickups/heart_red.png"
		"heart_half":   tex = "res://assets/sprites/pickups/heart_half.png"
		"heart_soul":   tex = "res://assets/sprites/pickups/heart_soul.png"
		"bomb":         tex = "res://assets/sprites/pickups/bomb.png"
		"key":          tex = "res://assets/sprites/pickups/key.png"
	if tex != "" and ResourceLoader.exists(tex):
		sprite.texture = load(tex)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_apply_effect()
	EventBus.pickup_collected.emit(kind, amount)
	AudioManager.play_sfx("pickup_" + kind)
	# Snap-grab feedback.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _apply_effect() -> void:
	match kind:
		"coin":         GameState.add_coins(1)
		"coin_double":  GameState.add_coins(2)
		"heart_red":    GameState.heal_red(2.0)
		"heart_half":   GameState.heal_red(1.0)
		"heart_soul":   GameState.heal_soul(2.0)
		"bomb":         GameState.add_bombs(1)
		"key":          GameState.add_keys(1)
