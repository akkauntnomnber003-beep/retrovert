# GaperAI.gd — slow walker that mostly heads toward the player, but uses
# AIBrain to spread out and detour around walls.
extends EnemyBase

var move_dir: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var detour_dir: Vector2 = Vector2.ZERO
var detour_timer: float = 0.0


func _on_ready_override() -> void:
	max_hp = 2.5
	current_hp = max_hp
	move_speed = 80.0
	contact_damage = 1.0
	enemy_type = "gaper"
	drop_chance = 0.18
	if sprite:
		sprite.play("walk_down")
	_pick_new_dir()


func _ai_process(delta: float) -> void:
	state_timer -= delta
	detour_timer -= delta
	if state_timer <= 0.0:
		if player_ref and is_instance_valid(player_ref) and randf() < 0.85:
			move_dir = (player_ref.global_position - global_position)\
				.normalized()
		else:
			_pick_new_dir()
		state_timer = randf_range(0.5, 1.2)

	var target_dir: Vector2 = move_dir
	if player_ref and is_instance_valid(player_ref):
		if not AIBrain.line_of_sight(self, player_ref):
			if detour_timer <= 0.0:
				detour_dir = AIBrain.sample_wander(self, move_dir, 96.0)
				detour_timer = randf_range(0.4, 0.9)
			target_dir = detour_dir
	target_dir += AIBrain.separation(self, 48.0) * 0.6
	velocity = velocity.move_toward(target_dir.normalized() * move_speed,
		move_speed * 5.0 * delta)
	_update_sprite()


func _pick_new_dir() -> void:
	move_dir = AIBrain.sample_wander(self, move_dir)
	state_timer = randf_range(0.8, 2.0)


func _update_sprite() -> void:
	if velocity.length() < 5.0 or sprite == null:
		return
	var d: Vector2 = velocity.normalized()
	if abs(d.x) > abs(d.y):
		sprite.play("walk_down")
		sprite.flip_h = d.x < 0
	else:
		sprite.play("walk_down" if d.y > 0 else "walk_up")
		sprite.flip_h = false
