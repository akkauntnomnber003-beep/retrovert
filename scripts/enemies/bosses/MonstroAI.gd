# MonstroAI.gd — Monstro-inspired boss with 2 phases.
extends EnemyBase

enum Phase { PHASE1, PHASE2 }
enum BossState { ENTER, IDLE, JUMP, SHOOT }

var phase: int = Phase.PHASE1
var boss_state: int = BossState.ENTER
var action_timer: float = 2.0
var jump_target: Vector2 = Vector2.ZERO
var jump_start: Vector2 = Vector2.ZERO
var jump_progress: float = 0.0
var jump_duration: float = 0.8


func _on_ready_override() -> void:
	max_hp = 60.0 * floor_scale
	current_hp = max_hp
	move_speed = 0.0
	contact_damage = 2.0
	enemy_type = "monstro"
	drop_chance = 1.0
	if sprite:
		sprite.play("idle")
	EventBus.boss_fight_started.emit(self)
	AudioManager.play_music("res://assets/audio/music/boss_theme.ogg")


func _ai_process(delta: float) -> void:
	if current_hp <= max_hp * 0.5 and phase == Phase.PHASE1:
		phase = Phase.PHASE2
		_enter_phase2()
	match boss_state:
		BossState.ENTER:
			action_timer -= delta
			if action_timer <= 0.0:
				boss_state = BossState.IDLE
				action_timer = 1.0
		BossState.IDLE:
			action_timer -= delta
			if action_timer <= 0.0:
				_choose_action()
		BossState.JUMP:
			_process_jump(delta)
		BossState.SHOOT:
			action_timer -= delta
			if action_timer <= 0.0:
				_do_shoot()
				boss_state = BossState.IDLE
				action_timer = randf_range(1.0, 2.0)


func _choose_action() -> void:
	if randf() < 0.5:
		_start_jump()
	else:
		boss_state = BossState.SHOOT
		action_timer = 0.3


func _start_jump() -> void:
	boss_state = BossState.JUMP
	jump_start = global_position
	if player_ref and is_instance_valid(player_ref):
		jump_target = player_ref.global_position
	else:
		jump_target = Vector2(640, 360)
	jump_progress = 0.0
	if sprite:
		var t := create_tween()
		t.tween_property(sprite, "position:y", -60.0, jump_duration * 0.5)
		t.tween_property(sprite, "position:y", 0.0, jump_duration * 0.5)


func _process_jump(delta: float) -> void:
	jump_progress += delta / jump_duration
	global_position = jump_start.lerp(jump_target, jump_progress)
	if jump_progress >= 1.0:
		_land()


func _land() -> void:
	boss_state = BossState.IDLE
	action_timer = randf_range(0.8, 1.5)
	EventBus.camera_shake.emit(12.0, 0.4)
	if phase == Phase.PHASE2:
		_spread_shot(8)


func _do_shoot() -> void:
	if phase == Phase.PHASE1:
		_spread_shot(4)
	else:
		_spread_shot(8)


func _spread_shot(count: int) -> void:
	var angle_step: float = TAU / float(count)
	for i in count:
		var ang: float = i * angle_step
		var dir := Vector2(cos(ang), sin(ang))
		var b = BulletPool.get_enemy_bullet()
		if b == null:
			continue
		b.global_position = global_position
		if b.has_method("launch"):
			b.launch(dir, 1.5 * floor_scale, 200.0, 2.2, false)


func _enter_phase2() -> void:
	move_speed = 50.0
	if sprite:
		var t := create_tween()
		t.tween_property(sprite, "modulate", Color.RED, 0.3)
		t.tween_property(sprite, "modulate", Color.WHITE, 0.3)
		t.set_loops(3)
	EventBus.camera_shake.emit(10.0, 0.5)


func _die() -> void:
	super._die()
	EventBus.boss_died.emit(GameState.current_room_pos)
