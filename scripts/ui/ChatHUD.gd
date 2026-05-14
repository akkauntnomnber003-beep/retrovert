# ChatHUD.gd
# Top-of-screen chat / log overlay. Listens on ChatLog and draws the most
# recent messages with sender:text formatting. Toggleable with the chat
# button on the HUD (or via mods calling ChatLog.set_visible).
extends Control

const VISIBLE_LINES := 5
const FADE_DURATION := 0.25

const KIND_COLORS := {
	"info":   Color(0.95, 0.95, 0.95, 1.0),
	"log":    Color(0.78, 0.84, 0.95, 1.0),
	"system": Color(0.85, 0.95, 0.85, 1.0),
	"mod":    Color(0.95, 0.85, 0.55, 1.0),
	"error":  Color(1.00, 0.45, 0.45, 1.0),
	"enemy":  Color(1.00, 0.65, 0.55, 1.0),
	"item":   Color(0.85, 0.70, 1.00, 1.0),
}

const SENDER_COLORS := {
	"info":   Color(0.65, 0.85, 1.00, 1.0),
	"log":    Color(0.55, 0.65, 0.85, 1.0),
	"system": Color(0.60, 0.95, 0.75, 1.0),
	"mod":    Color(1.00, 0.78, 0.30, 1.0),
	"error":  Color(1.00, 0.30, 0.30, 1.0),
	"enemy":  Color(1.00, 0.45, 0.40, 1.0),
	"item":   Color(0.85, 0.55, 1.00, 1.0),
}

var _panel: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _toggle_btn: Button
var _clear_btn: Button
var _auto_scroll: bool = true
var _scroll_pending: bool = false


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = 8
	offset_right = -8
	offset_top = 8
	offset_bottom = 188
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	v.add_child(header)

	var title := Label.new()
	title.text = "Чат"
	title.add_theme_color_override("font_color", Color(0.95, 0.93, 0.78))
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	_clear_btn = Button.new()
	_clear_btn.text = "очистить"
	_clear_btn.flat = true
	_clear_btn.add_theme_font_size_override("font_size", 11)
	_clear_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(_clear_btn)
	_clear_btn.pressed.connect(func(): ChatLog.clear())

	_toggle_btn = Button.new()
	_toggle_btn.text = "▾"
	_toggle_btn.flat = true
	_toggle_btn.add_theme_font_size_override("font_size", 14)
	_toggle_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	header.add_child(_toggle_btn)
	_toggle_btn.pressed.connect(func(): ChatLog.toggle_visible())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 130)
	v.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)

	EventBus.chat_message.connect(_on_chat_message)
	EventBus.chat_cleared.connect(_on_chat_cleared)
	EventBus.chat_visibility_changed.connect(_apply_visibility)

	# Replay existing buffer.
	for m in ChatLog.messages:
		_append_line(m["sender"], m["text"], m["kind"], m["sender_id"])
	_apply_visibility(ChatLog.visible)
	_scroll_to_bottom()


func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.05, 0.78)
	s.border_color = Color(0.35, 0.25, 0.18, 0.85)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _on_chat_message(sender: String, text: String, kind: String,
		sender_id: String) -> void:
	_append_line(sender, text, kind, sender_id)
	_trim_old_lines()
	_scroll_to_bottom()


func _on_chat_cleared() -> void:
	for c in _list.get_children():
		c.queue_free()


func _append_line(sender: String, text: String, kind: String,
		sender_id: String) -> void:
	var line := RichTextLabel.new()
	line.fit_content = true
	line.bbcode_enabled = true
	line.scroll_active = false
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_font_size_override("normal_font_size", 13)
	var sender_col: Color = SENDER_COLORS.get(kind, Color.WHITE)
	var text_col: Color = KIND_COLORS.get(kind, Color.WHITE)
	var sender_hex: String = sender_col.to_html(false)
	var text_hex: String = text_col.to_html(false)
	var sender_disp: String = sender
	if sender_id != "" and sender_id != sender:
		sender_disp = "%s" % sender
	line.text = "[color=#%s]%s:[/color] [color=#%s]%s[/color]" % \
		[sender_hex, sender_disp, text_hex, text]
	_list.add_child(line)


func _trim_old_lines() -> void:
	# Keep the list small so the scrollbar always fits the recent messages.
	var max_in_dom := 60
	while _list.get_child_count() > max_in_dom:
		_list.get_child(0).queue_free()


func _scroll_to_bottom() -> void:
	if _scroll_pending:
		return
	_scroll_pending = true
	call_deferred("_do_scroll")


func _do_scroll() -> void:
	_scroll_pending = false
	if _scroll == null:
		return
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	if bar:
		_scroll.scroll_vertical = int(bar.max_value)


func _apply_visibility(v: bool) -> void:
	visible = true  # Control always visible — panel collapses instead.
	if _scroll:
		_scroll.visible = v
	if _toggle_btn:
		_toggle_btn.text = "▾" if v else "▴"
