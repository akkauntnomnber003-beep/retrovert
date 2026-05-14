# Settings.gd
# Player-facing settings page: display toggles, volume, API keys. Keys go to
# user://settings/api_keys.cfg via the ApiKeys autoload, never to git.
extends Control

@onready var back_btn: Button = $TopBar/HBox/BackButton

@onready var auto_aim_toggle: CheckButton = $Scroll/VBox/AutoAimRow/AutoAimToggle
@onready var show_aim_toggle: CheckButton = $Scroll/VBox/ShowAimRow/ShowAimToggle
@onready var chat_toggle: CheckButton = $Scroll/VBox/ChatRow/ChatToggle
@onready var lighting_toggle: CheckButton = $Scroll/VBox/LightingRow/LightingToggle
@onready var ysort_toggle: CheckButton = $Scroll/VBox/YSortRow/YSortToggle
@onready var volume_slider: HSlider = $Scroll/VBox/VolumeRow/VolumeSlider

@onready var or_edit: LineEdit = $Scroll/VBox/OpenRouterRow/OpenRouterEdit
@onready var model_edit: LineEdit = $Scroll/VBox/OpenRouterModelRow/ModelEdit
@onready var tg_edit: LineEdit = $Scroll/VBox/TelegramRow/TelegramEdit
@onready var tg_chat_edit: LineEdit = $Scroll/VBox/TelegramChatRow/TelegramChatEdit

@onready var save_btn: Button = $Scroll/VBox/TestRow/SaveButton
@onready var test_ai_btn: Button = $Scroll/VBox/TestRow/TestAiButton
@onready var result_label: Label = $Scroll/VBox/ResultLabel


func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	save_btn.pressed.connect(_on_save)
	test_ai_btn.pressed.connect(_on_test_ai)

	auto_aim_toggle.toggled.connect(func(v: bool): GameState.auto_aim = v; _persist_settings())
	show_aim_toggle.toggled.connect(func(v: bool): GameState.set_setting("show_aim", v))
	chat_toggle.toggled.connect(func(v: bool):
		GameState.set_setting("chat_visible", v)
		ChatLog.set_visible(v))
	lighting_toggle.toggled.connect(func(v: bool): GameState.set_setting("lighting", v))
	ysort_toggle.toggled.connect(func(v: bool): GameState.set_setting("ysort", v))
	volume_slider.value_changed.connect(func(v: float):
		GameState.set_setting("volume", v)
		if AudioServer.bus_count > 0:
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001))))

	NetAPI.net_response.connect(_on_net_response)
	_load_settings()


func _load_settings() -> void:
	auto_aim_toggle.button_pressed = GameState.auto_aim
	show_aim_toggle.button_pressed = bool(GameState.get_setting("show_aim", true))
	chat_toggle.button_pressed = bool(GameState.get_setting("chat_visible", true))
	lighting_toggle.button_pressed = bool(GameState.get_setting("lighting", true))
	ysort_toggle.button_pressed = bool(GameState.get_setting("ysort", true))
	volume_slider.value = float(GameState.get_setting("volume", 0.8))

	or_edit.text = ApiKeys.get_key("openrouter", "default")
	model_edit.text = ApiKeys.get_key("openrouter", "model")
	tg_edit.text = ApiKeys.get_key("telegram", "bot_token")
	tg_chat_edit.text = ApiKeys.get_key("telegram", "chat_id")


func _persist_settings() -> void:
	GameState.set_setting("auto_aim", GameState.auto_aim)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_save() -> void:
	ApiKeys.set_key("openrouter", "default", or_edit.text.strip_edges())
	ApiKeys.set_key("openrouter", "model", model_edit.text.strip_edges())
	ApiKeys.set_key("telegram", "bot_token", tg_edit.text.strip_edges())
	ApiKeys.set_key("telegram", "chat_id", tg_chat_edit.text.strip_edges())
	_persist_settings()
	result_label.text = "Сохранено в user://settings/api_keys.cfg"
	ChatLog.send_system("Настройки сохранены")


func _on_test_ai() -> void:
	if not ApiKeys.has("openrouter", "default"):
		result_label.text = "OpenRouter ключ не задан"
		return
	result_label.text = "Запрос к OpenRouter..."
	NetAPI.ai_chat_text("Скажи коротко 'привет, рейтроверт'")


func _on_net_response(_rid: int, code: int, body: String) -> void:
	if not is_visible_in_tree():
		return
	if code == 200:
		var snippet: String = body.substr(0, 200)
		result_label.text = "OK: " + snippet
	else:
		result_label.text = "HTTP %d: %s" % [code, body.substr(0, 200)]
