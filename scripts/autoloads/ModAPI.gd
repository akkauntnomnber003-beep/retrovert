# ModAPI.gd
# Stable, documented surface that mods (RatScript or external GDScript)
# call into. Everything mods can do is funnelled through here so we have
# a single audit point.
extends Node

# Sub-API references
var state: Object
var bus: Object
var items: Object
var rooms: Object
var entities: Object
var math: Object


func _ready() -> void:
	state = StateAPI.new(self)
	bus = BusAPI.new(self)
	items = ItemsAPI.new(self)
	rooms = RoomsAPI.new(self)
	entities = EntitiesAPI.new(self)
	math = MathAPI.new(self)


# ──────────────────────────────────────────────────────────────────────────
# Convenience helpers callable from mods
# ──────────────────────────────────────────────────────────────────────────
func log(msg: String, mod_id: String = "") -> void:
	print("[mod:%s] %s" % [mod_id, msg])


func player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")


func enemies() -> Array:
	var tree := get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group("enemy")


func play_sfx(id: String) -> void:
	AudioManager.play_sfx(id)


func camera_shake(strength: float, duration: float = 0.3) -> void:
	EventBus.camera_shake.emit(strength, duration)


# ──────────────────────────────────────────────────────────────────────────
# Sub-APIs
# ──────────────────────────────────────────────────────────────────────────
class StateAPI:
	var _api: Node
	func _init(api: Node) -> void: _api = api

	func get_stat(name: String) -> Variant:
		return GameState.get(name)

	func set_stat(name: String, value: Variant) -> void:
		GameState.set(name, value)
		GameState.stats_recomputed.emit()

	func add_stat(name: String, delta: Variant) -> void:
		var cur = GameState.get(name)
		GameState.set(name, cur + delta)
		GameState.stats_recomputed.emit()

	func add_coins(n: int) -> void: GameState.add_coins(n)
	func add_bombs(n: int) -> void: GameState.add_bombs(n)
	func add_keys(n: int) -> void: GameState.add_keys(n)
	func heal_red(n: float) -> void: GameState.heal_red(n)
	func heal_soul(n: float) -> void: GameState.heal_soul(n)


class BusAPI:
	var _api: Node
	var _conns: Array = []
	func _init(api: Node) -> void: _api = api

	func on(signal_name: String, fn: Callable) -> void:
		if EventBus.has_signal(signal_name):
			EventBus.connect(signal_name, fn)
			_conns.append([signal_name, fn])
		else:
			push_warning("ModAPI.bus.on: unknown signal '%s'" % signal_name)

	func emit(signal_name: String, args: Array = []) -> void:
		if EventBus.has_signal(signal_name):
			EventBus.callv("emit_signal", [signal_name] + args)

	func unhook_all() -> void:
		for c in _conns:
			if EventBus.is_connected(c[0], c[1]):
				EventBus.disconnect(c[0], c[1])
		_conns.clear()


class ItemsAPI:
	var _api: Node
	func _init(api: Node) -> void: _api = api

	func register_from_dict(d: Dictionary, mod_uuid: String = "") -> bool:
		var def := ItemDatabase.ItemDef.new()
		def.id = d.get("id", "")
		def.name = d.get("name", def.id)
		def.description = d.get("description", "")
		def.icon_path = d.get("icon_path", "")
		def.is_active = bool(d.get("active", false))
		def.charge_needed = int(d.get("charge", 0))
		def.quality = int(d.get("quality", 1))
		def.source_mod = mod_uuid
		def.tags = d.get("tags", [])
		var stats: Dictionary = d.get("stats", {})
		if not stats.is_empty():
			def.on_pickup = func(_player):
				for k in stats:
					var cur = GameState.get(k)
					if cur == null:
						continue
					GameState.set(k, cur + stats[k])
				GameState.stats_recomputed.emit()
		return ItemDatabase.register_item(def)

	func grant(id: String) -> void:
		ItemDatabase.apply_pickup(id, _api.player())

	func list() -> Array:
		return ItemDatabase.items.keys()


class RoomsAPI:
	var _api: Node
	func _init(api: Node) -> void: _api = api

	func current_type() -> int:
		var rd = RoomGen.get_room(GameState.current_room_pos)
		return rd.type if rd != null else -1

	func current_pos() -> Vector2i:
		return GameState.current_room_pos


class EntitiesAPI:
	var _api: Node
	func _init(api: Node) -> void: _api = api

	func spawn_enemy(scene_path: String, pos: Vector2) -> Node:
		if not ResourceLoader.exists(scene_path):
			return null
		var s: PackedScene = load(scene_path)
		var n: Node = s.instantiate()
		var tree := _api.get_tree()
		if tree.current_scene:
			tree.current_scene.add_child(n)
		if n is Node2D:
			n.global_position = pos
		return n

	func damage_enemies_in_radius(center: Vector2, radius: float,
			amount: float) -> int:
		var n := 0
		for e in _api.enemies():
			if not is_instance_valid(e):
				continue
			if e.global_position.distance_to(center) <= radius and \
					e.has_method("take_damage"):
				e.take_damage(amount)
				n += 1
		return n


class MathAPI:
	var _api: Node
	func _init(api: Node) -> void: _api = api

	func deg2rad(d: float) -> float: return deg_to_rad(d)
	func rad2deg(r: float) -> float: return rad_to_deg(r)
	func vec(x: float, y: float) -> Vector2: return Vector2(x, y)
	func clamp(v: float, lo: float, hi: float) -> float: return clampf(v, lo, hi)
	func lerp(a: float, b: float, t: float) -> float: return lerpf(a, b, t)
	func randf(): return randf()
	func randi_range(a: int, b: int) -> int: return randi_range(a, b)
