# ChatOverlayUI.gd
# Visual frontend for ChatOverlay. Rebuilds the on-screen list when the
# autoload says messages changed. Always laid out at the top of the
# screen and supports hide/show + scroll buttons.
extends Control

@onready var chat_panel: PanelContainer = $ChatPanel
@onready var messages: VBoxContainer = $ChatPanel/VBox/Messages
@onready var show_btn: Button = $ShowBtn
@onready var hide_btn: Button = $ChatPanel/VBox/Header/Hide
@onready var up_btn: Button = $ChatPanel/VBox/Header/ScrollUp
@onready var down_btn: Button = $ChatPanel/VBox/Header/ScrollDown

const KIND_PREFIX := {
	"info":   "",
	"event":  "[event] ",
	"error":  "[err]   ",
	"mod":    "[mod]   ",
	"system": "[sys]   ",
	"net":    "[net]   ",
	"ai":     "[ai]    ",
}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	chat_panel.modulate = Color(1, 1, 1, 0.95)
	ChatOverlay.messages_changed.connect(_refresh)
	ChatOverlay.visibility_changed.connect(_on_visibility)
	hide_btn.pressed.connect(ChatOverlay.toggle)
	show_btn.pressed.connect(ChatOverlay.toggle)
	up_btn.pressed.connect(ChatOverlay.scroll_up)
	down_btn.pressed.connect(ChatOverlay.scroll_down)
	_refresh()


func _on_visibility(visible_state: bool) -> void:
	chat_panel.visible = visible_state
	show_btn.visible = not visible_state


func _refresh() -> void:
	for child in messages.get_children():
		child.queue_free()
	for raw in ChatOverlay.get_visible_window():
		if raw == null:
			continue
		var msg: ChatOverlay.Msg = raw
		var lbl := Label.new()
		var prefix: String = KIND_PREFIX.get(msg.kind, "")
		lbl.text = "%s%s: %s" % [prefix, msg.sender, msg.text]
		lbl.modulate = msg.color
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.clip_text = false
		lbl.add_theme_font_size_override("font_size", 14)
		messages.add_child(lbl)
