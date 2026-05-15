# ChatOverlay.gd
# In-game rolling chat overlay (like Minecraft chat). Mods, events and
# the engine itself can push messages here. Stays at the top of the
# screen, can be hidden, scrolled, and persists messages to disk.
#
# API used by other scripts and mods:
#   ChatOverlay.log(text, sender="System", kind="info")
#   ChatOverlay.error(text, sender="System")
#   ChatOverlay.event(text, sender="System")
#   ChatOverlay.toggle()
#   ChatOverlay.clear()
extends Node

const MAX_MESSAGES := 200
const VISIBLE_MESSAGES := 6
const LOG_PATH := "user://chat.log"
const MAX_MSG_LEN := 320

class Msg:
	var sender: String
	var text: String
	var kind: String           # info | error | event | mod | system | net | ai
	var time_unix: int
	var color: Color

	func _init(s: String, t: String, k: String, c: Color) -> void:
		sender = s
		text = t
		kind = k
		time_unix = int(Time.get_unix_time_from_system())
		color = c

var messages: Array = []          # Array[Msg]
var scroll_offset: int = 0
var visible_on_screen: bool = true

signal messages_changed
signal visibility_changed(visible: bool)


func _ready() -> void:
	# Mount a CanvasLayer that owns the UI scene so we sit above the
	# game world and below the mobile virtual keyboard / pause overlay.
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	canvas.name = "ChatCanvas"
	add_child(canvas)
	var scene_path := "res://scenes/ui/ChatOverlay.tscn"
	if ResourceLoader.exists(scene_path):
		var packed: PackedScene = load(scene_path)
		if packed:
			var ui: Node = packed.instantiate()
			canvas.add_child(ui)
	_listen_engine_events()
	self.log("RatRovert загружен. Удачной охоты!", "System", "system")


func _listen_engine_events() -> void:
	# Surface a few interesting game events to chat without spamming.
	# We dispatch through self.* so the `log` builtin (natural log) does
	# not shadow our method when called from inside a lambda body.
	EventBus.mod_loaded.connect(func(uuid):
		var info = ModLoader.registered_mods.get(uuid)
		var nm = info.name if info else uuid
		self.log("Мод загружен: %s" % nm, "ModLoader", "mod"))
	EventBus.mod_unloaded.connect(func(uuid):
		self.log("Мод выгружен: %s" % uuid, "ModLoader", "mod"))
	EventBus.mod_error.connect(func(uuid, msg):
		self.error("Мод %s: %s" % [uuid, msg], "ModLoader"))
	EventBus.boss_fight_started.connect(func(_boss):
		self.event("Босс пробудился — берегись!", "Arena"))
	EventBus.boss_died.connect(func(_pos):
		self.event("Босс повержен.", "Arena"))
	EventBus.floor_entered.connect(func(n):
		self.event("Этаж %d начался." % n, "Arena"))
	EventBus.player_died.connect(func():
		self.error("Ты пал. Тьма забрала тебя.", "Arena"))


# ── Public API ────────────────────────────────────────────────────────────
func log(text: String, sender: String = "System", kind: String = "info") -> void:
	_push(sender, text, kind, _color_for_kind(kind))


func error(text: String, sender: String = "System") -> void:
	_push(sender, text, "error", Color(1.0, 0.45, 0.45))


func event(text: String, sender: String = "Arena") -> void:
	_push(sender, text, "event", Color(1.0, 0.83, 0.4))


func mod(text: String, sender: String) -> void:
	_push(sender, text, "mod", Color(0.65, 0.85, 1.0))


func ai(text: String, sender: String = "AI") -> void:
	_push(sender, text, "ai", Color(0.7, 1.0, 0.85))


func clear() -> void:
	messages.clear()
	scroll_offset = 0
	messages_changed.emit()


func toggle() -> void:
	visible_on_screen = not visible_on_screen
	visibility_changed.emit(visible_on_screen)


func scroll_up() -> void:
	scroll_offset = clampi(scroll_offset + 1,
		0, max(0, messages.size() - VISIBLE_MESSAGES))
	messages_changed.emit()


func scroll_down() -> void:
	scroll_offset = clampi(scroll_offset - 1,
		0, max(0, messages.size() - VISIBLE_MESSAGES))
	messages_changed.emit()


func get_visible_window() -> Array:
	# Returns the slice of messages currently shown (oldest at top).
	var end_idx: int = messages.size() - scroll_offset
	var start_idx: int = max(0, end_idx - VISIBLE_MESSAGES)
	if end_idx <= start_idx:
		return []
	return messages.slice(start_idx, end_idx)


# ── Internal ──────────────────────────────────────────────────────────────
func _push(sender: String, text: String, kind: String, color: Color) -> void:
	if sender == "":
		sender = "System"
	if text == "":
		return
	if text.length() > MAX_MSG_LEN:
		text = text.substr(0, MAX_MSG_LEN - 1) + "…"
	var msg := Msg.new(sender, text, kind, color)
	messages.append(msg)
	while messages.size() > MAX_MESSAGES:
		messages.pop_front()
	scroll_offset = 0
	messages_changed.emit()
	_append_to_log(msg)


func _color_for_kind(kind: String) -> Color:
	match kind:
		"info":    return Color(0.85, 0.9, 1.0)
		"system":  return Color(0.75, 0.85, 1.0)
		"event":   return Color(1.0, 0.83, 0.4)
		"error":   return Color(1.0, 0.45, 0.45)
		"mod":     return Color(0.65, 0.85, 1.0)
		"net":     return Color(0.7, 0.95, 1.0)
		"ai":      return Color(0.7, 1.0, 0.85)
	return Color(0.85, 0.9, 1.0)


func _append_to_log(msg: Msg) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var stamp := Time.get_datetime_string_from_unix_time(msg.time_unix)
	f.store_line("[%s] [%s] %s: %s" % [stamp, msg.kind, msg.sender, msg.text])
	f.close()
