# ShopStall.gd
# A single buyable stall in a SHOP room. Owns a pickup PackedScene and a
# coin price; once the player walks onto the stall and presses the
# "interact" / "shoot" key (or pays once for a consumable on contact),
# the stall debits the coins, plays a sound, and replaces itself with
# the wrapped pickup. Brawl-Stars style: every stall has a price tag,
# a glow, and reacts when the player can afford it.
extends Node2D
class_name ShopStall

const COIN_ICON_PATH := "res://assets/sprites/ui/coin_icon.png"

@export var item_scene: PackedScene
@export var price: int = 5
@export var label_text: String = ""

var _consumed: bool = false
var _player_inside: bool = false
var _player_ref: Node = null

@onready var area: Area2D = $InteractArea
@onready var sprite_root: Node2D = $SpriteRoot
@onready var price_label: Label = $PriceLabel
@onready var icon_rect: TextureRect = $IconRect
@onready var glow: ColorRect = $Glow


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_refresh_label()
	_pulse()
	if item_scene:
		# Preview: spawn a *visual* copy of the wrapped pickup so the
		# shopper sees what they're buying.
		var preview = item_scene.instantiate()
		if preview is Node2D:
			# Strip away any logic so the preview is purely visual.
			if preview.has_node("Area2D"):
				preview.get_node("Area2D").queue_free()
			sprite_root.add_child(preview)
			preview.position = Vector2.ZERO
			# Make sure it doesn't try to magnet — leave the Pickup
			# script in place but disable its process.
			if preview.has_method("set_process"):
				preview.set_process(false)
			if preview.has_method("set_physics_process"):
				preview.set_physics_process(false)


func _process(_delta: float) -> void:
	if _consumed:
		return
	var can_afford: bool = GameState.player_coins >= price
	glow.modulate.a = 0.45 if can_afford else 0.12
	# Buy on "use_item" (E on desktop) or on any shoot direction button.
	if _player_inside and can_afford and (
			Input.is_action_just_pressed("use_item") or
			Input.is_action_just_pressed("shoot_up") or
			Input.is_action_just_pressed("shoot_down") or
			Input.is_action_just_pressed("shoot_left") or
			Input.is_action_just_pressed("shoot_right")):
		_buy()


func _refresh_label() -> void:
	price_label.text = "%d¢" % price


func _on_body_entered(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	_player_inside = true
	_player_ref = b
	if label_text != "":
		ChatOverlay.event("%s — %d монет" % [label_text, price], "Shop")


func _on_body_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside = false
		_player_ref = null


func _buy() -> void:
	if _consumed or item_scene == null:
		return
	if GameState.player_coins < price:
		AudioManager.play_sfx("ui_error")
		ChatOverlay.error("Не хватает монет.", "Shop")
		return
	GameState.add_coins(-price)
	_consumed = true
	AudioManager.play_sfx("shop_buy")
	EventBus.camera_shake.emit(2.0, 0.15)
	# Hand the buyer the goods.
	var inst = item_scene.instantiate()
	get_parent().add_child(inst)
	if inst is Node2D:
		inst.global_position = global_position
		if "scatter_impulse" in inst:
			inst.scatter_impulse = Vector2(0, -180)
	# Pop & remove the stall.
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ZERO, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func _pulse() -> void:
	# Subtle vertical bob — Brawl-Stars style.
	var t := create_tween().set_loops()
	t.tween_property(sprite_root, "position:y", -4.0, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sprite_root, "position:y", 4.0, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
