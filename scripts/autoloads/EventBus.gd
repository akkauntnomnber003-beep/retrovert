# EventBus.gd
# Global signal hub. Scripts can connect to/emit signals without holding
# direct references to one another. Modders can subscribe via ModAPI.bus.
extends Node

# ── Player ────────────────────────────────────────────────────────────────
signal player_spawned(player: Node)
signal player_died
signal player_damaged(amount: float)
signal player_healed(amount: float)
signal player_shot(direction: Vector2)
signal player_used_item(id: String)
signal player_placed_bomb(pos: Vector2)

# ── Rooms / Map ───────────────────────────────────────────────────────────
signal room_cleared(room_pos: Vector2i)
signal room_entered(room_pos: Vector2i, room_type: int)
signal room_loaded(room: Node)
signal door_opened(direction: String)
signal door_locked(direction: String)
signal door_transition(next_pos: Vector2i, from_dir: String)

# ── Enemies ───────────────────────────────────────────────────────────────
signal enemy_spawned(enemy: Node)
signal enemy_died(pos: Vector2, enemy_type: String)
signal enemy_hurt(pos: Vector2, enemy: Node, amount: float)
signal boss_fight_started(boss: Node)
signal boss_died(room_pos: Vector2i)

# ── Pickups / Items ───────────────────────────────────────────────────────
signal item_picked_up(item_id: String)
signal pickup_collected(type: String, amount: float)

# ── Effects ───────────────────────────────────────────────────────────────
signal camera_shake(strength: float, duration: float)
signal blood_splatter(pos: Vector2, count: int)
signal impact_effect(pos: Vector2)

# ── Game ──────────────────────────────────────────────────────────────────
signal game_over
signal floor_cleared
signal floor_entered(floor_num: int)
signal game_won

# ── Modding ───────────────────────────────────────────────────────────────
signal mod_loaded(mod_id: String)
signal mod_unloaded(mod_id: String)
signal mod_error(mod_id: String, message: String)
signal mods_reloaded

# ── Chat / log overlay ────────────────────────────────────────────────────
# kind ∈ "info", "log", "error", "mod", "system", "enemy", "item"
signal chat_message(sender: String, text: String, kind: String, sender_id: String)
signal chat_cleared
signal chat_visibility_changed(visible: bool)
