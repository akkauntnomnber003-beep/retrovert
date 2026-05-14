# LeaperAI.gd — pauses, then leaps toward the player.
extends EnemyBase

enum State { CROUCH, LEAP, COOLDOWN }
var state: int = State.CROUCH
var timer: float = 0.6
var leap_target: Vector2 = Vector2.ZERO


func _on_ready_override() -> void:
	max_hp = 3.0
	current_hp = max_hp
	move_speed = 0.0
	contact_damage = 1.0
	enemy_type = "leaper"
	drop_chance = 0.25
	if sprite:
		sprite.play("idle")


func _ai_process(delta: float) -> void:
	timer -= delta
	match state:
		State.CROUCH:
			velocity = Vector2.ZERO
			if timer <= 0.0:
				if player_ref and is_instance_valid(player_ref):
					leap_target = player_ref.global_position
				state = State.LEAP
				timer = 0.45
		State.LEAP:
			var dir: Vector2 = (leap_target - global_position)
			velocity = dir.normalized() * 380.0
			if timer <= 0.0 or dir.length() < 16.0:
				state = State.COOLDOWN
				timer = 0.6
				EventBus.camera_shake.emit(4.0, 0.15)
		State.COOLDOWN:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if timer <= 0.0:
				state = State.CROUCH
				timer = randf_range(0.5, 1.4)
