# Player.gd
# Twin-stick top-down protagonist.
# Handles movement (accel + friction), aim/look (radius/FOV/min/max),
# shooting with Isaac-style formula, knockback, i-frames, recoil.
extends CharacterBody2D

const FRICTION := 1200.0
const ACCEL_MULT := 18.0
const AUTO_AIM_RANGE := 420.0
const AUTO_AIM_LERP := 0.35

@onready var head_sprite: Sprite2D = $HeadSprite
@onready var body_sprite: AnimatedSprite2D = $YSortRoot/BodySprite
@onready var hurt_box: Area2D = $HurtBox
@onready var tear_timer: Timer = $TearTimer
@onready var inv_timer: Timer = $InvincibilityTimer
@onready var tear_spawn: Marker2D = $TearSpawnPoint
@onready var camera: Camera2D = $Camera2D

var is_invincible: bool = false
var facing_dir: Vector2 = Vector2.DOWN
var move_input: Vector2 = Vector2.ZERO
var shoot_input: Vector2 = Vector2.ZERO
var is_shooting: bool = false
var is_alive: bool = true
var head_textures: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	hurt_box.add_to_group("player_hurtbox")
	_load_head_textures()
	tear_timer.wait_time = GameState.compute_fire_interval()
	tear_timer.timeout.connect(_shoot_tear)
	inv_timer.timeout.connect(func(): is_invincible = false)
	hurt_box.area_entered.connect(_on_hurt_area_entered)
	hurt_box.body_entered.connect(_on_hurt_body_entered)
	GameState.stats_recomputed.connect(_recompute_timers)
	body_sprite.play("idle_down")
	EventBus.player_spawned.emit(self)


func _load_head_textures() -> void:
	for dir in ["down", "up", "left", "right"]:
		var path: String = "res://assets/sprites/player/head_%s.png" % dir
		if ResourceLoader.exists(path):
			head_textures[dir] = load(path)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	_read_keyboard_input()
	_apply_auto_aim()
	_apply_movement(delta)
	_update_facing()
	_update_animations()
	_update_tear_spawn_pos()
	move_and_slide()
	# Y-sort within the room: a low coefficient so the head doesn't flip
	# above/below the body when at the screen edge.
	z_index = clampi(int(global_position.y * 0.05), 0, 4096)


func _read_keyboard_input() -> void:
	# Keyboard fallback for desktop testing — does not override touch.
	var kbd_move := Vector2(
		Input.get_action_strength("move_right") -
			Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") -
			Input.get_action_strength("move_up")
	)
	if kbd_move.length() > 0.05 and move_input.length() < 0.05:
		move_input = kbd_move.normalized() * min(1.0, kbd_move.length())
	var kbd_shoot := Vector2(
		Input.get_action_strength("shoot_right") -
			Input.get_action_strength("shoot_left"),
		Input.get_action_strength("shoot_down") -
			Input.get_action_strength("shoot_up")
	)
	if kbd_shoot.length() > 0.05:
		set_shoot_input(kbd_shoot.normalized())
	elif shoot_input.length() > 0.05 and \
			abs(shoot_input.x) <= 0.05 and \
			abs(shoot_input.y) <= 0.05:
		set_shoot_input(Vector2.ZERO)


func _apply_movement(delta: float) -> void:
	if move_input.length() > 0.05:
		var mag: float = min(move_input.length(), 1.0)
		var target := move_input.normalized() * GameState.player_speed * mag
		velocity = velocity.move_toward(
			target, GameState.player_speed * ACCEL_MULT * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)


func _apply_auto_aim() -> void:
	# If the player is moving but not aiming, look at the nearest enemy.
	if shoot_input.length() > 0.1:
		return
	var nearest: Node = null
	var best_d2: float = AUTO_AIM_RANGE * AUTO_AIM_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if "is_dead" in e and e.is_dead:
			continue
		var d2: float = global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			nearest = e
	if nearest == null:
		return
	var dir: Vector2 = (nearest.global_position - global_position).normalized()
	set_shoot_input(dir)


func _update_facing() -> void:
	# Priority: shooting > movement.
	var dir := shoot_input if shoot_input.length() > 0.1 else move_input
	if dir.length() > 0.1:
		_set_facing(dir)


func _set_facing(dir: Vector2) -> void:
	if abs(dir.x) >= abs(dir.y):
		facing_dir = Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	else:
		facing_dir = Vector2.DOWN if dir.y > 0 else Vector2.UP
	_apply_head_texture()


func _dir_name() -> String:
	if facing_dir == Vector2.RIGHT: return "right"
	if facing_dir == Vector2.LEFT: return "left"
	if facing_dir == Vector2.UP: return "up"
	return "down"


func _apply_head_texture() -> void:
	var d := _dir_name()
	if head_textures.has(d):
		head_sprite.texture = head_textures[d]
		head_sprite.flip_h = false
	elif head_textures.has("right"):
		head_sprite.texture = head_textures["right"]
		head_sprite.flip_h = (facing_dir == Vector2.LEFT)


func _update_animations() -> void:
	var anim_dir := _dir_name()
	if move_input.length() > 0.05:
		body_sprite.play("walk_" + anim_dir)
	else:
		body_sprite.play("idle_" + anim_dir)


func _update_tear_spawn_pos() -> void:
	tear_spawn.position = facing_dir * 20.0


# ── Aim / view bookkeeping ────────────────────────────────────────────────
func aim_within_radius() -> bool:
	return shoot_input.length() > 0.1 and \
		shoot_input.length() <= GameState.view_radius


# ── Shooting ──────────────────────────────────────────────────────────────
func set_shoot_input(dir: Vector2) -> void:
	shoot_input = dir
	if GameState.aim_block:
		return
	if dir.length() > 0.1 and not is_shooting:
		is_shooting = true
		tear_timer.start()
		_shoot_tear()
	elif dir.length() <= 0.1 and is_shooting:
		is_shooting = false
		tear_timer.stop()


func _shoot_tear() -> void:
	if shoot_input.length() <= 0.1 or not is_alive or GameState.aim_block:
		return
	var t = BulletPool.get_tear()
	if t == null:
		return
	t.global_position = tear_spawn.global_position
	var dir := shoot_input.normalized()
	var spd: float = GameState.player_tear_speed * GameState.player_shot_speed
	var lifetime: float = GameState.compute_tear_lifetime()
	if t.has_method("launch"):
		t.launch(dir, GameState.player_damage, spd, lifetime, true)
	# Recoil — slight backward push, mimics weapon kick.
	velocity -= dir * GameState.recoil_strength * 0.5
	AudioManager.play_sfx("tear_shoot")
	GameState.charge_active_item()
	EventBus.player_shot.emit(dir)


func _recompute_timers() -> void:
	tear_timer.wait_time = GameState.compute_fire_interval()


# ── Active item / bomb ────────────────────────────────────────────────────
func use_active_item() -> void:
	ItemDatabase.try_use_active(self)


func place_bomb() -> void:
	if GameState.player_bombs <= 0:
		return
	GameState.add_bombs(-1)
	var scene := load("res://scenes/items/Bomb.tscn")
	if scene:
		var b: Node2D = scene.instantiate()
		b.global_position = global_position
		get_parent().add_child(b)
	EventBus.player_placed_bomb.emit(global_position)


# ── Damage ────────────────────────────────────────────────────────────────
func _on_hurt_area_entered(area: Area2D) -> void:
	if is_invincible or not is_alive:
		return
	if area.is_in_group("enemy_bullet") or area.is_in_group("enemy_contact"):
		var dmg: float = 1.0
		if area.has_meta("damage"):
			dmg = float(area.get_meta("damage"))
		take_damage(dmg)


func _on_hurt_body_entered(body: Node) -> void:
	if is_invincible or not is_alive:
		return
	if body.is_in_group("enemy"):
		take_damage(1.0)


func take_damage(amount: float) -> void:
	if is_invincible or not is_alive:
		return
	is_invincible = true
	inv_timer.start()
	GameState.take_damage(amount)
	EventBus.player_damaged.emit(amount)
	_hit_flash()
	AudioManager.play_sfx("player_hurt")
	EventBus.camera_shake.emit(6.0, 0.3)
	if GameState.is_dead():
		_die()


func _hit_flash() -> void:
	var tw := create_tween().set_loops(4)
	tw.tween_property(self, "modulate:a", 0.2, 0.08)
	tw.tween_property(self, "modulate:a", 1.0, 0.08)


func _die() -> void:
	is_alive = false
	set_physics_process(false)
	AudioManager.play_sfx("player_die")
	GameState.deaths_total += 1
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): EventBus.player_died.emit())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item"):
		use_active_item()
	elif event.is_action_pressed("place_bomb"):
		place_bomb()
