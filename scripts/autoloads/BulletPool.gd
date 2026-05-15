# BulletPool.gd
# Object pool for player tears and enemy bullets.
# Avoids the cost of instantiating Area2D nodes during gameplay.
extends Node

const POOL_TEARS := 64
const POOL_ENEMY := 32

var _tear_scene: PackedScene
var _enemy_scene: PackedScene
var _tears: Array = []
var _enemy: Array = []


func _ready() -> void:
	_tear_scene = load("res://scenes/projectiles/Tear.tscn")
	_enemy_scene = load("res://scenes/projectiles/EnemyBullet.tscn")
	if _tear_scene == null or _enemy_scene == null:
		push_warning("BulletPool: scenes not loaded yet — running in lazy mode.")
		return
	for i in POOL_TEARS:
		var t = _tear_scene.instantiate()
		_prepare(t)
		add_child(t)
		_tears.append(t)
	for i in POOL_ENEMY:
		var b = _enemy_scene.instantiate()
		_prepare(b)
		add_child(b)
		_enemy.append(b)


func _prepare(node: Node) -> void:
	node.visible = false
	node.set_process(false)
	node.set_physics_process(false)
	if node is Node2D:
		node.global_position = Vector2(-9999, -9999)


# ── Player tears ──────────────────────────────────────────────────────────
func get_tear() -> Node:
	for t in _tears:
		if is_instance_valid(t) and not t.visible:
			return t
	# Expand pool if everything is busy.
	if _tear_scene == null:
		_tear_scene = load("res://scenes/projectiles/Tear.tscn")
	var t = _tear_scene.instantiate()
	add_child(t)
	_tears.append(t)
	return t


func return_tear(t: Node) -> void:
	if not is_instance_valid(t):
		return
	t.visible = false
	t.set_process(false)
	t.set_physics_process(false)
	if t is Node2D:
		t.global_position = Vector2(-9999, -9999)


# ── Enemy bullets ─────────────────────────────────────────────────────────
func get_enemy_bullet() -> Node:
	for b in _enemy:
		if is_instance_valid(b) and not b.visible:
			return b
	if _enemy_scene == null:
		_enemy_scene = load("res://scenes/projectiles/EnemyBullet.tscn")
	var b = _enemy_scene.instantiate()
	add_child(b)
	_enemy.append(b)
	return b


func return_enemy_bullet(b: Node) -> void:
	if not is_instance_valid(b):
		return
	b.visible = false
	b.set_process(false)
	b.set_physics_process(false)
	if b is Node2D:
		b.global_position = Vector2(-9999, -9999)
