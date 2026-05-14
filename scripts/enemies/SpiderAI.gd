# SpiderAI.gd — fast skitterer that ambushes from range.
extends EnemyBase

enum State { IDLE, CHARGE }
var state: int = State.IDLE
var dash_dir: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0


func _on_ready_override() -> void:
	max_hp = 1.5
	current_hp = max_hp
	move_speed = 210.0
	contact_damage = 1.0
	enemy_type = "spider"
	drop_chance = 0.18
	if sprite:
		sprite.play("walk")


func _ai_process(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0.0:
		if player_ref and is_instance_valid(player_ref):
			# Ambush: charge once, then idle briefly.
			if state == State.IDLE:
				dash_dir = (player_ref.global_position
					- global_position).normalized()
				state = State.CHARGE
				dash_timer = randf_range(0.35, 0.6)
			else:
				state = State.IDLE
				dash_timer = randf_range(0.4, 0.8)
		else:
			dash_dir = Vector2(randf_range(-1, 1),
				randf_range(-1, 1)).normalized()
			dash_timer = 0.4
	var goal: Vector2 = dash_dir if state == State.CHARGE else Vector2.ZERO
	goal += AIBrain.separation(self, 40.0) * 0.5
	velocity = velocity.move_toward(goal * move_speed,
		move_speed * 10.0 * delta)
