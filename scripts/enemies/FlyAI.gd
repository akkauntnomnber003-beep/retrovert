# FlyAI.gd — wandering flyer that turns to chase the player.
extends EnemyBase

enum State { WANDER, CHASE, REGROUP }
var state: int = State.WANDER
var wander_dir: Vector2 = Vector2.RIGHT
var wander_timer: float = 0.0
const WANDER_CHANGE_TIME := 1.5
const CHASE_RADIUS := 360.0
const WANDER_SPEED_MULT := 0.55
const REGROUP_TIME := 0.6
var regroup_timer: float = 0.0


func _on_ready_override() -> void:
	max_hp = 1.0
	current_hp = 1.0
	move_speed = 140.0
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
				wander_dir = AIBrain.sample_wander(self, wander_dir)
				wander_timer = WANDER_CHANGE_TIME
			velocity = (wander_dir * move_speed * WANDER_SPEED_MULT
				+ AIBrain.separation(self) * move_speed * 0.5)
			if dist < CHASE_RADIUS and AIBrain.line_of_sight(self, player_ref):
				state = State.CHASE
		State.CHASE:
			# Aim for a ring slot around the player to spread out.
			var target_pos: Vector2 = AIBrain.ring_slot(self, player_ref, 100.0)
			velocity = AIBrain.steer(velocity, target_pos,
				move_speed, move_speed * 8.0, delta, self)
			if dist > CHASE_RADIUS * 1.8:
				state = State.WANDER
			elif dist < 40.0:
				# Brief regroup after a hit attempt so flies don't grind on
				# the player.
				state = State.REGROUP
				regroup_timer = REGROUP_TIME
		State.REGROUP:
			regroup_timer -= delta
			var away: Vector2 = (global_position
				- player_ref.global_position).normalized()
			velocity = velocity.move_toward(
				away * move_speed, move_speed * 6.0 * delta)
			if regroup_timer <= 0.0:
				state = State.CHASE
