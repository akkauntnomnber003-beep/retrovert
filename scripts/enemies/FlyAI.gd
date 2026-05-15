# FlyAI.gd — wandering flyer that turns to chase the player.
extends EnemyBase

enum State { WANDER, CHASE }
var state: int = State.WANDER
var wander_dir: Vector2 = Vector2.RIGHT
var wander_timer: float = 0.0
const WANDER_CHANGE_TIME := 1.5
const CHASE_RADIUS := 320.0
const WANDER_SPEED_MULT := 0.55


func _on_ready_override() -> void:
	max_hp = 1.0
	current_hp = 1.0
	move_speed = 120.0
	contact_damage = 1.0
	enemy_type = "fly"
	drop_chance = 0.12
	if sprite:
		sprite.play("fly")


func _ai_process(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	var dist: float = global_position.distance_to(player_ref.global_position)
	match state:
		State.WANDER:
			wander_timer -= delta
			if wander_timer <= 0.0:
				wander_dir = Vector2(randf_range(-1, 1),
					randf_range(-1, 1)).normalized()
				wander_timer = WANDER_CHANGE_TIME
			velocity = wander_dir * move_speed * WANDER_SPEED_MULT
			if dist < CHASE_RADIUS:
				state = State.CHASE
		State.CHASE:
			var dir: Vector2 = (player_ref.global_position - global_position)\
				.normalized()
			velocity = velocity.move_toward(
				dir * move_speed, move_speed * 8.0 * delta)
			if dist > CHASE_RADIUS * 1.6:
				state = State.WANDER
