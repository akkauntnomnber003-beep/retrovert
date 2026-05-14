# DoorController.gd
# A 2D door that locks while enemies are alive, opens on clear, and
# transitions the player to the neighbour room on overlap.
extends Area2D

@export var direction: String = "north"
@export var room_pos: Vector2i = Vector2i.ZERO

@onready var sprite: Sprite2D = $Sprite2D

const RoomGenCls := preload("res://scripts/autoloads/RoomGen.gd")

var is_open: bool = false
var is_locked: bool = false
var requires_key: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visual()
	_face_direction()


func _face_direction() -> void:
	match direction:
		"north": rotation_degrees = 0
		"south": rotation_degrees = 180
		"east": rotation_degrees = 90
		"west": rotation_degrees = -90


func _apply_visual() -> void:
	var tex_path := "res://assets/sprites/rooms/door_closed.png"
	if is_open:
		tex_path = "res://assets/sprites/rooms/door_open.png"
	elif is_locked:
		tex_path = "res://assets/sprites/rooms/door_locked.png"
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)


func lock() -> void:
	is_open = false
	is_locked = true
	_apply_visual()


func unlock() -> void:
	is_locked = false
	is_open = true
	_apply_visual()


func require_key(req: bool) -> void:
	requires_key = req
	if req:
		is_locked = true
		_apply_visual()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if is_locked and not requires_key:
		return
	if is_locked and requires_key:
		if GameState.player_keys <= 0:
			return
		GameState.add_keys(-1)
		requires_key = false
		unlock()
		AudioManager.play_sfx("door_unlock")
	var next_pos: Vector2i = room_pos + RoomGenCls.DIRS[direction]
	EventBus.door_transition.emit(next_pos, RoomGenCls.DIR_OPPOSITE[direction])
