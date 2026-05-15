# Tear.gd
# Both player tears and enemy tears use this script. is_player_tear flips
# collision masks and groups.
extends Area2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _velocity: Vector2 = Vector2.ZERO
var damage: float = 3.5
var speed: float = 400.0
var lifetime: float = 1.25
var _age: float = 0.0
var is_player_tear: bool = true
var _active: bool = false


func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	visible = false


func launch(dir: Vector2, dmg: float, spd: float, life: float,
		from_player: bool = true) -> void:
	_velocity = dir.normalized() * spd
	damage = dmg
	speed = spd
	lifetime = max(0.1, life)
	_age = 0.0
	is_player_tear = from_player
	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	modulate = Color(1, 1, 1, 1)

	# Visual scale grows with damage (Isaac-style).
	var sc: float = clampf(0.5 + dmg * 0.12, 0.5, 2.2)
	scale = Vector2(sc, sc)
	# Layer masks. Layer 4 = player_bullet, 5 = enemy_bullet, 3 = enemy,
	# 2 = player.
	if from_player:
		collision_layer = 1 << 3   # bit 4
		collision_mask = (1 << 2) | (1 << 6)   # enemy + wall
		add_to_group("player_bullet")
		remove_from_group("enemy_bullet")
		set_meta("damage", damage)
		modulate = Color(0.9, 0.95, 1.0)
		if sprite and ResourceLoader.exists("res://assets/sprites/player/tear_blue.png"):
			sprite.texture = load("res://assets/sprites/player/tear_blue.png")
	else:
		collision_layer = 1 << 4   # bit 5
		collision_mask = (1 << 1) | (1 << 6)
		add_to_group("enemy_bullet")
		remove_from_group("player_bullet")
		set_meta("damage", damage)
		modulate = Color(1.0, 0.6, 0.6)
		if sprite and ResourceLoader.exists("res://assets/sprites/player/tear_red.png"):
			sprite.texture = load("res://assets/sprites/player/tear_red.png")


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += _velocity * delta
	_age += delta
	# Fade out as the tear ages.
	var pct: float = 1.0 - (_age / lifetime)
	modulate.a = clampf(pct * 3.0, 0.0, 1.0)
	if _age >= lifetime:
		_impact(false)


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if is_player_tear:
		if area.is_in_group("enemy_hurtbox"):
			var enemy := area.get_parent()
			if enemy and enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			_impact(true)
	else:
		if area.is_in_group("player_hurtbox"):
			_impact(true)


func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	# Wall / static collision.
	_impact(false)


func _impact(hit: bool) -> void:
	if not _active:
		return
	_active = false
	EventBus.impact_effect.emit(global_position)
	if hit:
		AudioManager.play_sfx("tear_hit_enemy")
	else:
		AudioManager.play_sfx("tear_hit_wall")
	_recycle()


func _recycle() -> void:
	_active = false
	visible = false
	set_physics_process(false)
	remove_from_group("player_bullet")
	remove_from_group("enemy_bullet")
	BulletPool.return_tear(self)
