# LarryAI.gd — segmented snake boss. Simple version: tracks player while
# bobbing in a sinusoid pattern.
extends EnemyBase

var bob_time: float = 0.0
var base_speed: float = 90.0


func _on_ready_override() -> void:
	# EnemyBase scales by floor_scale after this returns, so set base stats.
	max_hp = 40.0
	current_hp = max_hp
	move_speed = base_speed
	contact_damage = 1.5
	enemy_type = "larry"
	drop_chance = 1.0
	if sprite:
		sprite.play("idle")
	EventBus.boss_fight_started.emit(self)


func _ai_process(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	bob_time += delta
	var to_p: Vector2 = (player_ref.global_position - global_position)\
		.normalized()
	# Perpendicular bob: snake-like motion.
	var perp := Vector2(-to_p.y, to_p.x)
	var dir := (to_p + perp * sin(bob_time * 4.0) * 0.6).normalized()
	velocity = velocity.move_toward(
		dir * move_speed, move_speed * 5.0 * delta)


func _die() -> void:
	super._die()
	EventBus.boss_died.emit(GameState.current_room_pos)
