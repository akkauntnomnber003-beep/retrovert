# ItemPickup.gd
# Floor pedestal for passive / active items. Applies effect on touch.
extends Area2D

@export var item_id: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("pickup")
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	body_entered.connect(_on_body_entered)
	_refresh_visual()


func set_item(id: String) -> void:
	item_id = id
	_refresh_visual()


func _refresh_visual() -> void:
	if item_id == "":
		return
	var def := ItemDatabase.get_def(item_id)
	if def == null:
		return
	if def.icon_path != "" and ResourceLoader.exists(def.icon_path):
		sprite.texture = load(def.icon_path)
	if label:
		label.text = def.name


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or item_id == "":
		return
	ItemDatabase.apply_pickup(item_id, body)
	AudioManager.play_sfx("item_pickup")
	queue_free()
