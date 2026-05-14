# ChatLog.gd
# Global, append-only ring buffer of chat / log messages shown at the top
# of the screen. Mods, internal systems and the player (in the future) can
# push messages here. Each message has the shape:
#
#     {
#         "sender": "DarkRift",
#         "sender_id": "darkrift",   ← optional ID for mods / mobs / items
#         "text": "Dungeon awakens",
#         "kind": "mod",             ← "info" | "log" | "error" | "mod" |
#                                       "system" | "enemy" | "item"
#         "time": 12.345,            ← engine seconds since boot
#     }
#
# ChatHUD listens on `chat_message` and shows the last `max_visible` lines.
extends Node

const MAX_HISTORY := 200
const MAX_TEXT_LEN := 240
const KINDS := ["info", "log", "error", "mod", "system", "enemy", "item"]

var messages: Array = []
var visible: bool = true


func _ready() -> void:
	visible = bool(GameState.settings.get("chat_visible", true))
	send_system("RatRovert загружен. Чат активен — сюда падают логи, ошибки и сообщения модов.")
	# Wire common gameplay/mod events automatically so the chat is alive
	# even when no mod is talking.
	EventBus.mod_loaded.connect(_on_mod_loaded)
	EventBus.mod_unloaded.connect(_on_mod_unloaded)
	EventBus.mod_error.connect(_on_mod_error)
	EventBus.mods_reloaded.connect(_on_mods_reloaded)
	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.boss_died.connect(_on_boss_died)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.floor_entered.connect(_on_floor_entered)
	EventBus.player_died.connect(_on_player_died)


# ──────────────────────────────────────────────────────────────────────────
# Auto-bridges
# ──────────────────────────────────────────────────────────────────────────
func _on_mod_loaded(uuid: String) -> void:
	var info = ModLoader.get_info(uuid) if ModLoader else null
	var nm: String = info.name if info else uuid
	send("Моды", "Загружен %s" % nm, "system", uuid)


func _on_mod_unloaded(uuid: String) -> void:
	var info = ModLoader.get_info(uuid) if ModLoader else null
	var nm: String = info.name if info else uuid
	send("Моды", "Выгружен %s" % nm, "system", uuid)


func _on_mod_error(uuid: String, message: String) -> void:
	var info = ModLoader.get_info(uuid) if ModLoader else null
	var nm: String = info.name if info else uuid
	send(nm, message, "error", uuid)


func _on_mods_reloaded() -> void:
	send_system("Моды перезагружены")


func _on_room_cleared(_pos: Vector2i) -> void:
	send("Комната", "Зачищено", "system", "room")


func _on_boss_died() -> void:
	send("Босс", "Поражён", "system", "boss")


func _on_item_picked_up(item_id: String) -> void:
	var def = ItemDatabase.get_def(item_id) if ItemDatabase else null
	var nm: String = def.name if def else item_id
	send(nm, "взят", "item", item_id)


func _on_floor_entered(floor_num: int) -> void:
	send("Этаж", "Вход на этаж %d" % floor_num, "system", "floor")


func _on_player_died() -> void:
	send_error("Игрок погиб", "Игра")


# ──────────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────────
func send(sender: String, text: String, kind: String = "info",
		sender_id: String = "") -> void:
	var entry := _make_entry(sender, text, kind, sender_id)
	messages.append(entry)
	while messages.size() > MAX_HISTORY:
		messages.pop_front()
	EventBus.chat_message.emit(entry["sender"], entry["text"],
		entry["kind"], entry["sender_id"])


func send_system(text: String) -> void:
	send("Система", text, "system", "system")


func send_error(text: String, sender: String = "Ошибка") -> void:
	send(sender, text, "error", "error")


func send_mod(mod_id: String, mod_name: String, text: String) -> void:
	send(mod_name, text, "mod", mod_id)


func send_enemy(name: String, text: String, enemy_id: String = "") -> void:
	send(name, text, "enemy", enemy_id)


func send_item(name: String, text: String, item_id: String = "") -> void:
	send(name, text, "item", item_id)


func clear() -> void:
	messages.clear()
	EventBus.chat_cleared.emit()


func toggle_visible() -> void:
	set_visible(not visible)


func set_visible(v: bool) -> void:
	visible = v
	GameState.settings["chat_visible"] = v
	EventBus.chat_visibility_changed.emit(v)


func recent(count: int = 5) -> Array:
	var n: int = min(count, messages.size())
	return messages.slice(messages.size() - n, messages.size())


func find_by_sender_id(sender_id: String) -> Array:
	var out: Array = []
	for m in messages:
		if m["sender_id"] == sender_id:
			out.append(m)
	return out


# ──────────────────────────────────────────────────────────────────────────
# Internal
# ──────────────────────────────────────────────────────────────────────────
func _make_entry(sender: String, text: String, kind: String,
		sender_id: String) -> Dictionary:
	if kind not in KINDS:
		kind = "info"
	var clean_text: String = text
	if clean_text.length() > MAX_TEXT_LEN:
		clean_text = clean_text.substr(0, MAX_TEXT_LEN - 1) + "…"
	clean_text = clean_text.replace("\n", " ")
	var clean_sender: String = sender if sender != "" else "?"
	if clean_sender.length() > 24:
		clean_sender = clean_sender.substr(0, 23) + "…"
	return {
		"sender": clean_sender,
		"sender_id": sender_id,
		"text": clean_text,
		"kind": kind,
		"time": Time.get_ticks_msec() / 1000.0,
	}
