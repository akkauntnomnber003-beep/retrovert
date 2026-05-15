# EnemyBullet.gd
# Thin wrapper around Tear that defaults to enemy-side semantics.
extends "res://scripts/projectiles/Tear.gd"


func launch(dir: Vector2, dmg: float, spd: float, life: float,
		_from_player: bool = false) -> void:
	super.launch(dir, dmg, spd, life, false)


func _recycle() -> void:
	_active = false
	visible = false
	set_physics_process(false)
	remove_from_group("player_bullet")
	remove_from_group("enemy_bullet")
	BulletPool.return_enemy_bullet(self)
