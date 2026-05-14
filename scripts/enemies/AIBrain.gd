# AIBrain.gd
# Helper functions any enemy AI can call without inheriting from it. Keeps
# EnemyBase small while giving subclasses access to higher-level helpers:
# separation between peers, line-of-sight checks, lead-prediction for
# projectiles, simple coordinated targeting (pick a unique offset per group).
class_name AIBrain
extends RefCounted

const WALL_LAYER := 1 << 0  # 2D physics layer "world"


# Avoid stacking — push away from other enemies in the same group.
static func separation(me: Node2D, radius: float = 56.0) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var tree: SceneTree = me.get_tree()
	if tree == null:
		return push
	for n in tree.get_nodes_in_group("enemy"):
		if n == me or not (n is Node2D):
			continue
		var d: Vector2 = me.global_position - n.global_position
		var dl: float = d.length()
		if dl > 0.001 and dl < radius:
			push += d.normalized() * (1.0 - dl / radius)
	return push


# Stagger position around the player — each enemy claims a slot so they
# don't bunch up at the player. Returns an offset in world space.
static func ring_slot(me: Node2D, target: Node2D, radius: float = 90.0) -> Vector2:
	if target == null:
		return Vector2.ZERO
	var idx: int = abs(me.get_instance_id()) % 360
	var ang: float = deg_to_rad(idx)
	return target.global_position + Vector2(cos(ang), sin(ang)) * radius


# Returns true if there's no wall between me and target.
static func line_of_sight(me: Node2D, target: Node2D) -> bool:
	if target == null:
		return false
	var space: PhysicsDirectSpaceState2D = me.get_world_2d().direct_space_state
	if space == null:
		return false
	var params := PhysicsRayQueryParameters2D.create(
		me.global_position, target.global_position, WALL_LAYER)
	params.collide_with_areas = false
	params.exclude = [me.get_rid()]
	var result := space.intersect_ray(params)
	return result.is_empty()


# Lead the shot — predict where target will be after `travel_time` seconds.
static func predict(target: Node2D, travel_time: float) -> Vector2:
	if target == null:
		return Vector2.ZERO
	var tv: Vector2 = Vector2.ZERO
	if "velocity" in target:
		tv = target.velocity
	return target.global_position + tv * travel_time


# Steer towards a point while respecting separation and easing.
static func steer(current: Vector2, target_pos: Vector2, speed: float,
		accel: float, delta: float, me: Node2D = null) -> Vector2:
	var to: Vector2 = (target_pos - (me.global_position if me else current))
	var dir: Vector2 = to.normalized() if to.length() > 0.001 else Vector2.ZERO
	var want: Vector2 = dir * speed
	if me != null:
		want += separation(me, 56.0) * speed
	return current.move_toward(want, accel * delta)


# Returns the closest player position with a fallback to (0,0).
static func find_player(me: Node) -> Node2D:
	var tree: SceneTree = me.get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as Node2D


# Wall-aware wander — pick a direction that doesn't immediately hit a wall.
static func sample_wander(me: Node2D, current: Vector2, look_ahead: float = 64.0) -> Vector2:
	var space: PhysicsDirectSpaceState2D = me.get_world_2d().direct_space_state
	if space == null:
		return current
	for _i in 4:
		var ang: float = randf() * TAU
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var to: Vector2 = me.global_position + dir * look_ahead
		var params := PhysicsRayQueryParameters2D.create(
			me.global_position, to, WALL_LAYER)
		params.exclude = [me.get_rid()]
		var hit := space.intersect_ray(params)
		if hit.is_empty():
			return dir
	return current
