# ItemDatabase.gd
# Registry of every item (passive + active). Mods can register new items
# through ModAPI.items.register(...).
extends Node


class ItemDef:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon_path: String = ""
	var is_active: bool = false
	var charge_needed: int = 0
	var quality: int = 1  # 0..4
	var on_pickup: Callable = Callable()
	var on_use: Callable = Callable()
	var source_mod: String = ""  # blank = core
	var tags: Array = []

	func describe() -> String:
		return "[%s] %s — %s" % [id, name, description]


var items: Dictionary = {}                # id → ItemDef
var passive_pool: Array = []              # cached
var active_pool: Array = []
var by_mod: Dictionary = {}               # mod_id → Array[id]


func _ready() -> void:
	_register_core_items()
	_rebuild_pools()


# ── REGISTRATION ──────────────────────────────────────────────────────────
func register_item(def: ItemDef) -> bool:
	if def == null or def.id == "":
		push_warning("ItemDatabase: invalid def")
		return false
	if items.has(def.id):
		push_warning("ItemDatabase: id collision %s" % def.id)
		return false
	items[def.id] = def
	if def.source_mod != "":
		if not by_mod.has(def.source_mod):
			by_mod[def.source_mod] = []
		by_mod[def.source_mod].append(def.id)
	_rebuild_pools()
	return true


func unregister_mod_items(mod_id: String) -> void:
	if not by_mod.has(mod_id):
		return
	for id in by_mod[mod_id]:
		items.erase(id)
	by_mod.erase(mod_id)
	_rebuild_pools()


func _rebuild_pools() -> void:
	passive_pool.clear()
	active_pool.clear()
	for id in items:
		var def: ItemDef = items[id]
		if def.is_active:
			active_pool.append(id)
		else:
			passive_pool.append(id)


# ── QUERIES ───────────────────────────────────────────────────────────────
func get_def(id: String) -> ItemDef:
	return items.get(id, null)


func get_random_passive() -> String:
	if passive_pool.is_empty():
		return ""
	return passive_pool[randi() % passive_pool.size()]


func get_random_active() -> String:
	if active_pool.is_empty():
		return ""
	return active_pool[randi() % active_pool.size()]


# ── APPLY ─────────────────────────────────────────────────────────────────
func apply_pickup(id: String, player: Node = null) -> void:
	var def: ItemDef = items.get(id)
	if def == null:
		return
	if def.is_active:
		GameState.set_active_item(id, def.charge_needed)
	else:
		GameState.collected_items.append(id)
		if def.on_pickup.is_valid():
			def.on_pickup.call(player)
	EventBus.item_picked_up.emit(id)


func try_use_active(player: Node = null) -> bool:
	var id := GameState.active_item
	if id == "":
		return false
	var def: ItemDef = items.get(id)
	if def == null:
		return false
	if not GameState.try_use_active_item():
		return false
	if def.on_use.is_valid():
		def.on_use.call(player)
	EventBus.player_used_item.emit(id)
	return true


# ── CORE ITEMS ────────────────────────────────────────────────────────────
func _add(id: String, name: String, desc: String, active: bool,
		on_pickup: Callable, on_use: Callable = Callable(),
		charge: int = 6, quality: int = 1) -> void:
	var def := ItemDef.new()
	def.id = id
	def.name = name
	def.description = desc
	def.icon_path = "res://assets/sprites/items/%s.png" % id
	def.is_active = active
	def.charge_needed = charge if active else 0
	def.on_pickup = on_pickup
	def.on_use = on_use
	def.quality = quality
	register_item(def)


func _register_core_items() -> void:
	# Passive
	_add("rat_speed", "Rat Speed", "+0.3 скорости", false,
		func(_p): GameState.player_speed += 60.0)
	_add("blood_tear", "Blood Tear", "+1.5 урона", false,
		func(_p): GameState.player_damage += 1.5)
	_add("double_shot", "Double Shot", "Скорострельность +50%", false,
		func(_p): GameState.player_tear_rate *= 1.5)
	_add("hard_aim", "Hard Aim", "Дальность +100", false,
		func(_p): GameState.player_range += 2.5)
	_add("rat_nose", "Rat Nose", "Скорость слёз +20%", false,
		func(_p): GameState.player_tear_speed *= 1.2)
	_add("rusty_heart", "Rusty Heart", "+1 макс. сердце", false,
		func(_p):
			GameState.player_hp_max += 2.0
			GameState.heal_red(2.0))
	_add("abyss_shadow", "Abyss Shadow", "+0.5 удача", false,
		func(_p): GameState.player_luck += 0.5)
	_add("flex_aim", "Flex Aim", "Слёзы крупнее", false,
		func(_p):
			GameState.player_damage += 0.5
			GameState.player_tear_rate *= 0.85)
	_add("sinner_barrier", "Sinner Barrier", "+1 душевное сердце", false,
		func(_p): GameState.heal_soul(2.0))
	_add("rotten_milk", "Rotten Milk", "Слёзы +30% скорость, -20% урон",
		false, func(_p):
			GameState.player_tear_rate *= 1.3
			GameState.player_damage = max(0.5,
				GameState.player_damage - 0.7))

	# Active
	_add("hellish_charge", "Hellish Charge", "Взрыв вокруг игрока", true,
		Callable(), func(p): _explode_around_player(p), 6, 3)
	_add("abyss_fan", "Abyss Fan", "12 слёз по кругу", true,
		Callable(), func(p): _circle_shot(p), 4, 2)


# ── ACTIVE ITEM EFFECTS ───────────────────────────────────────────────────
func _explode_around_player(player) -> void:
	if player == null:
		return
	for enemy in player.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(player.global_position) < 220.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(GameState.player_damage * 3.0)
	EventBus.camera_shake.emit(10.0, 0.45)


func _circle_shot(player) -> void:
	if player == null:
		return
	for i in 12:
		var ang := i * TAU / 12.0
		var dir := Vector2(cos(ang), sin(ang))
		var t = BulletPool.get_tear()
		if t == null:
			continue
		t.global_position = player.global_position
		if t.has_method("launch"):
			t.launch(dir, GameState.player_damage,
				GameState.player_tear_speed,
				GameState.compute_tear_lifetime(), true)
