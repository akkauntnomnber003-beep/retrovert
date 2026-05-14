# GaperAI.gd — slow walker that mostly heads toward the player.
extends EnemyBase

var move_dir: Vector2 = Vector2.ZERO
var state_timer: float = 0.0


func _on_ready_override() -> void:
	max_hp = 2.0
	current_hp = 2.0
	move_speed = 70.0
	contact_damage = 1.0
	enemy_type = "gaper"
	drop_chance = 0.18
	if sprite:
		sprite.play("walk_down")
	_pick_new_dir()


func _ai_process(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		if player_ref and is_instance_valid(player_ref) and randf() < 0.7:
			move_dir = (player_ref.global_position - global_position)\
				.normalized()
		else:
			_pick_new_dir()
		state_timer = randf_range(0.5, 1.5)
	velocity = velocity.move_toward(
		move_dir * move_speed, move_speed * 5.0 * delta)
	_update_sprite()


func _pick_new_dir() -> void:
	move_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	state_timer = randf_range(0.8, 2.0)


func _update_sprite() -> void:
	if velocity.length() < 5.0 or sprite == null:
		return
	var d: Vector2 = velocity.normalized()
	if abs(d.x) > abs(d.y):
		sprite.play("walk_down")  # placeholder 2-row sheet — we only have 1 dir anim
		sprite.flip_h = d.x < 0
	else:
		sprite.play("walk_down" if d.y > 0 else "walk_up")
		sprite.flip_h = false
