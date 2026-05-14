# PooterAI.gd — hovers at mid-range, shoots predictive bullets, kites away
# when the player gets too close.
extends EnemyBase

const SHOOT_SPEED := 240.0
const SHOOT_RANGE := 360.0
var kite_dir: Vector2 = Vector2.RIGHT
var strafe_timer: float = 0.0


func _on_ready_override() -> void:
	max_hp = 2.5
	current_hp = max_hp
	move_speed = 70.0
	contact_damage = 1.0
	enemy_type = "pooter"
	drop_chance = 0.22
	if shoot_timer:
		shoot_timer.wait_time = randf_range(1.2, 2.0)
		shoot_timer.timeout.connect(_shoot)
		shoot_timer.start()
	if sprite:
		sprite.play("fly")


func _ai_process(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var dist: float = global_position.distance_to(player_ref.global_position)
	var to_player: Vector2 = (player_ref.global_position
		- global_position).normalized()
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(0.8, 1.6)
		kite_dir = Vector2(-to_player.y, to_player.x)
		if randi() & 1:
			kite_dir = -kite_dir
	var want: Vector2 = Vector2.ZERO
	if dist > 300.0:
		want = to_player
	elif dist < 180.0:
		want = -to_player
	else:
		want = kite_dir
	want += AIBrain.separation(self) * 0.5
	velocity = velocity.move_toward(want.normalized() * move_speed,
		move_speed * 4.0 * delta)


func _shoot() -> void:
	if is_dead or not player_ref or not is_instance_valid(player_ref):
		return
	if not AIBrain.line_of_sight(self, player_ref):
		return  # don't waste shots through walls
	if global_position.distance_to(player_ref.global_position) > SHOOT_RANGE:
		return
	var b = BulletPool.get_enemy_bullet()
	if b == null:
		return
	# Predict the player's position by the bullet flight time.
	var travel_time: float = global_position.distance_to(
		player_ref.global_position) / SHOOT_SPEED
	var lead: Vector2 = AIBrain.predict(player_ref, travel_time)
	var dir: Vector2 = (lead - global_position).normalized()
	b.global_position = global_position
	if b.has_method("launch"):
		b.launch(dir, 1.0 * floor_scale, SHOOT_SPEED, 1.6, false)
