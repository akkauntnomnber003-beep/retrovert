# GameState.gd
# Centralised mutable run state and player stats.
# Modders can read/write any of these fields through ModAPI.state.*
extends Node

# ── RUN STATE ─────────────────────────────────────────────────────────────
var run_floor: int = 1
var run_room_count: int = 0
var run_seed: int = 0

# ── PLAYER STATS (Isaac-style, in half-hearts) ────────────────────────────
var player_hp: float = 6.0
var player_hp_max: float = 6.0
var player_soul_hp: float = 0.0
var player_eternal_hp: float = 0.0
var player_coins: int = 0
var player_bombs: int = 1
var player_keys: int = 1

# Combat-related stats
var player_damage: float = 3.5
var player_speed: float = 200.0          # px/s
var player_tear_rate: float = 2.5        # shots / second (formula: 1.0/rate)
var player_tear_speed: float = 400.0     # px/s
var player_tear_range: float = 500.0     # raw px
var player_shot_speed: float = 1.0       # multiplier applied to tear_speed
var player_luck: float = 0.0
var player_range: float = 6.5            # Isaac-style range index
# View / aim related (used by Player look code)
var view_radius: float = 300.0           # base aim radius
var view_max: float = 600.0              # max look distance
var view_min: float = 50.0               # min look distance
var aim_block: bool = false              # if true, shooting is disabled
var recoil_strength: float = 80.0        # backwards impulse on shoot
var fov_degrees: float = 360.0           # 360 = omni-directional twin-stick

# ── ITEMS ─────────────────────────────────────────────────────────────────
var collected_items: Array = []
var trinket: String = ""
var active_item: String = ""
var active_item_charge: int = 0
var active_item_charge_max: int = 6

# ── MAP ───────────────────────────────────────────────────────────────────
var current_map: Dictionary = {}
var visited_rooms: Array = []
var cleared_rooms: Array = []
var current_room_pos: Vector2i = Vector2i.ZERO

# ── PROGRESS ──────────────────────────────────────────────────────────────
var kills_this_run: int = 0
var floors_cleared: int = 0
var coins_collected_total: int = 0
var deaths_total: int = 0

# ── SETTINGS (persisted via SaveManager) ──────────────────────────────────
var settings: Dictionary = {
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"touch_controls": true,
	"show_fps": false,
	"vibrate": true,
	"language": "ru",
}

# ── SIGNALS ───────────────────────────────────────────────────────────────
signal hp_changed(current: float, maximum: float, soul: float)
signal coins_changed(amount: int)
signal bombs_changed(amount: int)
signal keys_changed(amount: int)
signal item_added(item_id: String)
signal active_item_changed(item_id: String)
signal active_charge_changed(charge: int, charge_max: int)
signal run_reset
signal stats_recomputed


func _ready() -> void:
	# Force landscape on mobile devices, full-screen on desktop builds.
	if DisplayServer.is_touchscreen_available():
		DisplayServer.screen_set_orientation(
			DisplayServer.SCREEN_LANDSCAPE
		)
	# Window mode 3 from project.godot already requests fullscreen; on
	# Linux dev runs we leave it as the editor decided.
	run_seed = int(Time.get_unix_time_from_system())
	seed(run_seed)


# ── COINS / BOMBS / KEYS ───────────────────────────────────────────────────
func add_coins(n: int) -> void:
	player_coins = max(0, player_coins + n)
	if n > 0:
		coins_collected_total += n
	coins_changed.emit(player_coins)


func spend_coins(n: int) -> bool:
	if player_coins < n:
		return false
	player_coins -= n
	coins_changed.emit(player_coins)
	return true


func add_bombs(n: int) -> void:
	player_bombs = max(0, player_bombs + n)
	bombs_changed.emit(player_bombs)


func add_keys(n: int) -> void:
	player_keys = max(0, player_keys + n)
	keys_changed.emit(player_keys)


# ── HEALTH ────────────────────────────────────────────────────────────────
func heal_red(amount: float) -> void:
	player_hp = min(player_hp_max, player_hp + amount)
	hp_changed.emit(player_hp, player_hp_max, player_soul_hp)


func heal_soul(amount: float) -> void:
	player_soul_hp += amount
	hp_changed.emit(player_hp, player_hp_max, player_soul_hp)


func take_damage(amount: float) -> void:
	if player_soul_hp > 0.0:
		var dealt: float = min(amount, player_soul_hp)
		player_soul_hp -= dealt
		amount -= dealt
	if amount > 0.0:
		player_hp = max(0.0, player_hp - amount)
	hp_changed.emit(player_hp, player_hp_max, player_soul_hp)


func is_dead() -> bool:
	return player_hp <= 0.0 and player_soul_hp <= 0.0


# ── ACTIVE ITEM ───────────────────────────────────────────────────────────
func charge_active_item(amount: int = 1) -> void:
	active_item_charge = clampi(active_item_charge + amount,
		0, active_item_charge_max)
	active_charge_changed.emit(active_item_charge, active_item_charge_max)


func set_active_item(id: String, charge_max: int = 6) -> void:
	active_item = id
	active_item_charge_max = charge_max
	active_item_charge = 0
	active_item_changed.emit(id)
	active_charge_changed.emit(active_item_charge, active_item_charge_max)


func try_use_active_item() -> bool:
	if active_item == "":
		return false
	if active_item_charge < active_item_charge_max:
		return false
	active_item_charge = 0
	active_charge_changed.emit(active_item_charge, active_item_charge_max)
	return true


# ── RUN LIFECYCLE ─────────────────────────────────────────────────────────
func reset_run() -> void:
	run_floor = 1
	run_room_count = 0
	player_hp = 6.0
	player_hp_max = 6.0
	player_soul_hp = 0.0
	player_eternal_hp = 0.0
	player_coins = 0
	player_bombs = 1
	player_keys = 1
	player_damage = 3.5
	player_speed = 200.0
	player_tear_rate = 2.5
	player_tear_speed = 400.0
	player_tear_range = 500.0
	player_shot_speed = 1.0
	player_luck = 0.0
	player_range = 6.5
	view_radius = 300.0
	view_max = 600.0
	view_min = 50.0
	aim_block = false
	recoil_strength = 80.0
	collected_items.clear()
	active_item = ""
	active_item_charge = 0
	active_item_charge_max = 6
	current_map.clear()
	visited_rooms.clear()
	cleared_rooms.clear()
	current_room_pos = Vector2i.ZERO
	kills_this_run = 0
	floors_cleared = 0
	run_seed = int(Time.get_unix_time_from_system())
	seed(run_seed)
	run_reset.emit()
	hp_changed.emit(player_hp, player_hp_max, player_soul_hp)
	coins_changed.emit(player_coins)
	bombs_changed.emit(player_bombs)
	keys_changed.emit(player_keys)
	active_charge_changed.emit(active_item_charge, active_item_charge_max)
	active_item_changed.emit(active_item)


# ── COMBAT FORMULAS (Isaac-style) ─────────────────────────────────────────
func compute_tear_lifetime() -> float:
	var spd: float = max(1.0, player_tear_speed * player_shot_speed)
	return (player_range * 2.5) / spd * (1.0 + clamp(player_luck, -1.0, 2.0) * 0.05)


func compute_tear_scale() -> float:
	return clampf(0.5 + player_damage * 0.12, 0.5, 2.2)


func compute_fire_interval() -> float:
	# Isaac formula adapted: interval (s) = 1.0 / tear_rate clamped to safety.
	return clampf(1.0 / max(0.1, player_tear_rate), 0.08, 2.5)


func compute_dps() -> float:
	return player_damage * player_tear_rate


# ── DEBUG ─────────────────────────────────────────────────────────────────
func snapshot() -> Dictionary:
	return {
		"run_floor": run_floor,
		"hp": player_hp,
		"hp_max": player_hp_max,
		"soul": player_soul_hp,
		"coins": player_coins,
		"bombs": player_bombs,
		"keys": player_keys,
		"damage": player_damage,
		"speed": player_speed,
		"tear_rate": player_tear_rate,
		"tear_speed": player_tear_speed,
		"range": player_range,
		"items": collected_items.duplicate(),
		"active": active_item,
	}
