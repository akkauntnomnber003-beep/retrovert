# TouchControls.gd
# Two dynamic virtual joysticks (left = move, right = shoot) plus a couple
# of round buttons (bomb + active item). Fully multi-touch (event.index
# tracking). Joystick "bg" appears under the finger that touched.
extends CanvasLayer

const DEADZONE := 0.15
const MAX_RADIUS := 110.0

@onready var left_zone: Control = $LeftZone
@onready var right_zone: Control = $RightZone
@onready var left_bg: TextureRect = $LeftZone/JoystickBg
@onready var left_knob: TextureRect = $LeftZone/JoystickKnob
@onready var right_bg: TextureRect = $RightZone/JoystickBg
@onready var right_knob: TextureRect = $RightZone/JoystickKnob
@onready var bomb_btn: TextureButton = $Buttons/BombButton
@onready var item_btn: TextureButton = $Buttons/ItemButton

var _left_touch: int = -1
var _right_touch: int = -1
var _left_origin: Vector2 = Vector2.ZERO
var _right_origin: Vector2 = Vector2.ZERO
var player: Node = null


func _ready() -> void:
	left_bg.visible = false
	left_knob.visible = false
	right_bg.visible = false
	right_knob.visible = false
	bomb_btn.pressed.connect(_on_bomb_pressed)
	item_btn.pressed.connect(_on_item_pressed)
	EventBus.player_spawned.connect(_on_player_spawned)


func _on_player_spawned(p: Node) -> void:
	player = p


func set_player(p: Node) -> void:
	player = p


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos: Vector2 = event.position
	if event.pressed:
		if _is_in_zone(pos, left_zone) and _left_touch < 0:
			_left_touch = event.index
			_left_origin = pos
			left_bg.global_position = pos - left_bg.size * 0.5
			left_knob.global_position = pos - left_knob.size * 0.5
			left_bg.visible = true
			left_knob.visible = true
		elif _is_in_zone(pos, right_zone) and _right_touch < 0:
			_right_touch = event.index
			_right_origin = pos
			right_bg.global_position = pos - right_bg.size * 0.5
			right_knob.global_position = pos - right_knob.size * 0.5
			right_bg.visible = true
			right_knob.visible = true
	else:
		if event.index == _left_touch:
			_left_touch = -1
			left_bg.visible = false
			left_knob.visible = false
			_apply_left(Vector2.ZERO)
		elif event.index == _right_touch:
			_right_touch = -1
			right_bg.visible = false
			right_knob.visible = false
			_apply_right(Vector2.ZERO)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _left_touch:
		_update_joystick(event.position, _left_origin, left_knob, true)
	elif event.index == _right_touch:
		_update_joystick(event.position, _right_origin, right_knob, false)


func _is_in_zone(pos: Vector2, zone: Control) -> bool:
	return zone.get_global_rect().has_point(pos)


func _update_joystick(pos: Vector2, origin: Vector2, knob: TextureRect,
		is_left: bool) -> void:
	var delta: Vector2 = pos - origin
	var len: float = delta.length()
	if len > MAX_RADIUS:
		delta = delta.normalized() * MAX_RADIUS
		len = MAX_RADIUS
	knob.global_position = (origin + delta) - knob.size * 0.5
	var input_vec: Vector2 = delta / MAX_RADIUS
	if input_vec.length() < DEADZONE:
		input_vec = Vector2.ZERO
	if is_left:
		_apply_left(input_vec)
	else:
		_apply_right(input_vec)


func _apply_left(v: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.move_input = v


func _apply_right(v: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("set_shoot_input"):
		player.set_shoot_input(v)


func _on_bomb_pressed() -> void:
	if player and player.has_method("place_bomb"):
		player.place_bomb()


func _on_item_pressed() -> void:
	if player and player.has_method("use_active_item"):
		player.use_active_item()
