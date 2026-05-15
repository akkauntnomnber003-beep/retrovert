# EnemyBase.gd
# Base class for all enemies. Subclasses override _on_ready_override
# and _ai_process(delta) to add behaviour.
extends CharacterBody2D
class_name EnemyBase

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurt_box: Area2D = $HurtBox
@onready var contact_box: Area2D = $ContactBox
@onready var hp_bar: ProgressBar = $HPBar
@onready var knockback_timer: Timer = $KnockbackTimer
@onready var shoot_timer: Timer = $ShootTimer if has_node("ShootTimer") else null

var max_hp: float = 2.0
var current_hp: float = 2.0
var move_speed: float = 80.0
var contact_damage: float = 1.0
var enemy_type: String = "base"
var drop_chance: float = 0.2
var floor_scale: float = 1.0
var is_dead: bool = false
var is_stunned: bool = false
var knockback_vel: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION := 700.0
var player_ref: Node = null

signal died(pos: Vector2, type: String)


func _ready() -> void:
	add_to_group("enemy")
	hurt_box.add_to_group("enemy_hurtbox")
	contact_box.add_to_group("enemy_contact")
	contact_box.set_meta("damage", contact_damage)
	hurt_box.area_entered.connect(_on_hurt)
	contact_box.area_entered.connect(_on_contact)
	# Scale up with current floor.
	floor_scale = 1.0 + (GameState.run_floor - 1) * 0.35
	max_hp *= floor_scale
	current_hp = max_hp
	contact_damage = max(0.5, contact_damage * (1.0 + (GameState.run_floor - 1) * 0.2))
	contact_box.set_meta("damage", contact_damage)
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.visible = false
	player_ref = get_tree().get_first_node_in_group("player")
	_on_ready_override()
	EventBus.enemy_spawned.emit(self)


func _on_ready_override() -> void:
	pass


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if knockback_vel.length() > 5.0:
		knockback_vel = knockback_vel.move_toward(
			Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		velocity = knockback_vel
		is_stunned = true
	else:
		knockback_vel = Vector2.ZERO
		is_stunned = false
		_ai_process(delta)
	move_and_slide()
	z_index = int(global_position.y * 0.1)


func _ai_process(_delta: float) -> void:
	pass


func _on_hurt(area: Area2D) -> void:
	if not area.is_in_group("player_bullet"):
		return
	var dmg: float = 3.5
	if area.has_meta("damage"):
		dmg = float(area.get_meta("damage"))
	take_damage(dmg)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp -= amount
	_show_hp_bar()
	_hit_flash()
	_apply_knockback_from_player()
	AudioManager.play_sfx("enemy_hurt")
	EventBus.blood_splatter.emit(global_position, 4)
	EventBus.enemy_hurt.emit(global_position, self, amount)
	EventBus.camera_shake.emit(2.0, 0.1)
	if current_hp <= 0.0:
		_die()


func _show_hp_bar() -> void:
	hp_bar.visible = true
	hp_bar.value = current_hp
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func():
		if is_instance_valid(self):
			hp_bar.visible = false)


func _apply_knockback_from_player() -> void:
	if player_ref and is_instance_valid(player_ref):
		var dir: Vector2 = (global_position - player_ref.global_position)\
			.normalized()
		knockback_vel = dir * 350.0


func _hit_flash() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.modulate = Color(1.5, 0.6, 0.6)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _on_contact(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox") and player_ref \
			and is_instance_valid(player_ref):
		if player_ref.has_method("take_damage"):
			player_ref.take_damage(contact_damage)


func _die() -> void:
	is_dead = true
	set_physics_process(false)
	AudioManager.play_sfx("enemy_die")
	GameState.kills_this_run += 1
	_spawn_drop()
	died.emit(global_position, enemy_type)
	EventBus.enemy_died.emit(global_position, enemy_type)
	EventBus.blood_splatter.emit(global_position, 8)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ZERO, 0.25)
	t.tween_callback(queue_free)


func _spawn_drop() -> void:
	if randf() > drop_chance:
		return
	var pick: float = randf()
	var scene_path: String
	if pick < 0.55:
		scene_path = "res://scenes/items/Coin.tscn"
	elif pick < 0.78:
		scene_path = "res://scenes/items/Heart.tscn"
	elif pick < 0.92:
		scene_path = "res://scenes/items/Bomb.tscn"
	else:
		scene_path = "res://scenes/items/Key.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	var pickup := load(scene_path).instantiate() as Node2D
	if pickup == null:
		return
	get_parent().add_child(pickup)
	pickup.global_position = global_position
	# Give the dropped pickup a little scatter so it doesn't pile up
	# under the enemy corpse — Pickup.gd reads this var on _ready.
	if "scatter_impulse" in pickup:
		pickup.scatter_impulse = Vector2(
			randf_range(-220, 220), randf_range(-220, 220))
