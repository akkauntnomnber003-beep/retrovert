# DoorController.gd
# An Area2D + StaticBody2D door. The Area2D detects the player walking
# in; the StaticBody2D actually blocks them while the door is locked.
# When the room is cleared, every door unlocks at once (signal). When
# the player enters an unlocked door, we emit `door_transition` which
# the Game scene listens to.
extends Area2D

@export var direction: String = "north"
@export var room_pos: Vector2i = Vector2i.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var blocker: StaticBody2D = $Blocker
@onready var blocker_shape: CollisionShape2D = $Blocker/BlockerShape

const RoomGenCls := preload("res://scripts/autoloads/RoomGen.gd")

var is_open: bool = false
var is_locked: bool = false
var requires_key: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_face_direction()
	_apply_visual()
	_apply_blocker()


func _face_direction() -> void:
	# Door art faces "into" the room; rotate so the sprite points outwards.
	match direction:
		"north":
			rotation_degrees = 0
		"south":
			rotation_degrees = 180
		"east":
			rotation_degrees = 90
		"west":
			rotation_degrees = -90
	# Match the blocker orientation: when door is on a horizontal wall
	# (north/south) it should be a wide thin slab.
	if direction == "east" or direction == "west":
		blocker_shape.shape = blocker_shape.shape.duplicate()
		if blocker_shape.shape is RectangleShape2D:
			(blocker_shape.shape as RectangleShape2D).size = Vector2(16, 64)


func _apply_visual() -> void:
	var tex_path := "res://assets/sprites/rooms/door_closed.png"
	if is_open:
		tex_path = "res://assets/sprites/rooms/door_open.png"
	elif is_locked:
		tex_path = "res://assets/sprites/rooms/door_locked.png"
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	# Visual feedback for "passable" state.
	modulate = Color(1, 1, 1, 1) if is_open else Color(0.95, 0.85, 0.85, 1)


func _apply_blocker() -> void:
	blocker.collision_layer = 1 if not is_open else 0


func lock() -> void:
	is_open = false
	is_locked = true
	_apply_visual()
	_apply_blocker()


func unlock() -> void:
	is_locked = false
	is_open = true
	_apply_visual()
	_apply_blocker()


func require_key(req: bool) -> void:
	requires_key = req
	if req:
		is_locked = true
		_apply_visual()
		_apply_blocker()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if is_locked and requires_key:
		if GameState.player_keys <= 0:
			ChatOverlay.event("Заперто. Нужен ключ.", "Door")
			return
		GameState.add_keys(-1)
		requires_key = false
		unlock()
		AudioManager.play_sfx("door_unlock")
	if is_locked:
		return
	var next_pos: Vector2i = room_pos + RoomGenCls.DIRS[direction]
	EventBus.door_transition.emit(next_pos, RoomGenCls.DIR_OPPOSITE[direction])
