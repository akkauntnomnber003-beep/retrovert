# HUD.gd
# Heads-up display: hearts, coins, bombs, keys, active-item charge.
extends CanvasLayer

@onready var hearts_box: HBoxContainer = $TopLeft/HeartsBox
@onready var coin_label: Label = $TopLeft/Counters/CoinRow/Label
@onready var bomb_label: Label = $TopLeft/Counters/BombRow/Label
@onready var key_label: Label = $TopLeft/Counters/KeyRow/Label
@onready var active_icon: TextureRect = $BottomLeft/ActiveItemSlot/Icon
@onready var active_charge: ProgressBar = $BottomLeft/ActiveItemSlot/Charge
@onready var floor_label: Label = $TopRight/FloorLabel

var HEART_FULL: Texture2D
var HEART_HALF: Texture2D
var HEART_EMPTY: Texture2D
var HEART_SOUL: Texture2D


func _ready() -> void:
	HEART_FULL = _load("res://assets/sprites/ui/hud_heart_full.png")
	HEART_HALF = _load("res://assets/sprites/ui/hud_heart_half.png")
	HEART_EMPTY = _load("res://assets/sprites/ui/hud_heart_empty.png")
	HEART_SOUL = _load("res://assets/sprites/ui/hud_soul_full.png")
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.coins_changed.connect(func(n): coin_label.text = str(n))
	GameState.bombs_changed.connect(func(n): bomb_label.text = str(n))
	GameState.keys_changed.connect(func(n): key_label.text = str(n))
	GameState.active_item_changed.connect(_on_active_item_changed)
	GameState.active_charge_changed.connect(_on_active_charge_changed)
	_refresh_all()


func _load(p: String):
	return load(p) if ResourceLoader.exists(p) else null


func _refresh_all() -> void:
	_on_hp_changed(GameState.player_hp, GameState.player_hp_max,
		GameState.player_soul_hp)
	coin_label.text = str(GameState.player_coins)
	bomb_label.text = str(GameState.player_bombs)
	key_label.text = str(GameState.player_keys)
	floor_label.text = "Floor %d" % GameState.run_floor
	_on_active_item_changed(GameState.active_item)
	_on_active_charge_changed(GameState.active_item_charge,
		GameState.active_item_charge_max)


func _on_hp_changed(current: float, maximum: float, soul: float) -> void:
	for c in hearts_box.get_children():
		c.queue_free()
	var hp_int := int(current)
	var max_int := int(maximum)
	var i := 0
	while i < max_int:
		var tex: Texture2D = HEART_EMPTY
		if i + 2 <= hp_int:
			tex = HEART_FULL
		elif i + 1 <= hp_int:
			tex = HEART_HALF
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(34, 34)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_box.add_child(r)
		i += 2
	var soul_int := int(soul)
	var j := 0
	while j < soul_int:
		var r := TextureRect.new()
		r.texture = HEART_SOUL
		r.custom_minimum_size = Vector2(34, 34)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_box.add_child(r)
		j += 2


func _on_active_item_changed(id: String) -> void:
	if id == "":
		active_icon.texture = null
		return
	var def := ItemDatabase.get_def(id)
	if def == null:
		return
	if def.icon_path != "" and ResourceLoader.exists(def.icon_path):
		active_icon.texture = load(def.icon_path)


func _on_active_charge_changed(charge: int, charge_max: int) -> void:
	active_charge.max_value = max(1, charge_max)
	active_charge.value = charge
