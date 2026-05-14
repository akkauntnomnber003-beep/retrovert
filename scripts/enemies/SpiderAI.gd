# SpiderAI.gd — fast skitterer.
extends EnemyBase

var dash_dir: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0


func _on_ready_override() -> void:
	max_hp = 1.5
	current_hp = max_hp
	move_speed = 200.0
	contact_damage = 1.0
	enemy_type = "spider"
	drop_chance = 0.18
	if sprite:
		sprite.play("walk")


func _ai_process(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0.0:
		if player_ref and is_instance_valid(player_ref):
			dash_dir = (player_ref.global_position - global_position)\
				.normalized()
		else:
			dash_dir = Vector2(randf_range(-1, 1),
				randf_range(-1, 1)).normalized()
		dash_timer = randf_range(0.25, 0.6)
	velocity = velocity.move_toward(
		dash_dir * move_speed, move_speed * 8.0 * delta)
