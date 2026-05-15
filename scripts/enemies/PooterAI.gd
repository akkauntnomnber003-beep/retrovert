# PooterAI.gd — hovers at mid-range and shoots periodic bullets.
extends EnemyBase


func _on_ready_override() -> void:
	max_hp = 2.5
	current_hp = max_hp
	move_speed = 55.0
	contact_damage = 1.0
	enemy_type = "pooter"
	drop_chance = 0.22
	if shoot_timer:
		shoot_timer.wait_time = randf_range(1.4, 2.4)
		shoot_timer.timeout.connect(_shoot)
		shoot_timer.start()
	if sprite:
		sprite.play("fly")


func _ai_process(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var dist: float = global_position.distance_to(player_ref.global_position)
	var dir: Vector2 = (player_ref.global_position - global_position)\
		.normalized()
	if dist > 280.0:
		velocity = velocity.move_toward(
			dir * move_speed, move_speed * 4.0 * delta)
	elif dist < 160.0:
		velocity = velocity.move_toward(
			-dir * move_speed, move_speed * 4.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 6.0 * delta)


func _shoot() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref):
		return
	var dir: Vector2 = (player_ref.global_position - global_position)\
		.normalized()
	var b = BulletPool.get_enemy_bullet()
	if b == null:
		return
	b.global_position = global_position
	if b.has_method("launch"):
		b.launch(dir, 1.0 * floor_scale, 220.0, 1.6, false)
