# Game.gd
# Top-level controller: builds a floor, swaps rooms on door transitions,
# wires HUD, touch controls, and the pause menu. Owns the **room
# camera** — a single Camera2D that snaps to the centre of whatever
# room is currently loaded. This is what makes the world feel like
# Isaac (entire room visible, no chase-cam jitter).
extends Node2D

const ROOM_W := 1280
const ROOM_H := 720

@onready var room_holder: Node2D = $RoomHolder
@onready var room_camera: Camera2D = $RoomCamera
@onready var fade: ColorRect = $UI/Fade
@onready var hud_layer: CanvasLayer = $HUDLayer
@onready var touch_layer: CanvasLayer = $TouchLayer

var current_room: Node = null
var player: Node = null
var _cam_base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	RoomGen.generate_floor(GameState.run_floor)
	_spawn_hud()
	_spawn_touch()
	_spawn_player()
	room_camera.make_current()
	_load_room(Vector2i.ZERO, "south")
	EventBus.door_transition.connect(_on_door_transition)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_died.connect(_on_boss_died)
	EventBus.camera_shake.connect(_on_camera_shake)
	EventBus.impact_effect.connect(_on_impact_effect)
	EventBus.blood_splatter.connect(_on_blood_splatter)
	fade.color = Color(0, 0, 0, 0)


func _spawn_hud() -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	if hud_scene == null:
		return
	var hud := hud_scene.instantiate()
	hud_layer.add_child(hud)
	var minimap_scene: PackedScene = load("res://scenes/ui/MiniMap.tscn")
	if minimap_scene:
		var mm := minimap_scene.instantiate()
		hud_layer.add_child(mm)


func _spawn_touch() -> void:
	var tc_scene: PackedScene = load("res://scenes/ui/TouchControls.tscn")
	if tc_scene == null:
		return
	var tc := tc_scene.instantiate()
	touch_layer.add_child(tc)


func _spawn_player() -> void:
	var p_scene: PackedScene = load("res://scenes/player/Player.tscn")
	if p_scene == null:
		return
	player = p_scene.instantiate()
	add_child(player)


func _load_room(pos: Vector2i, from_dir: String) -> void:
	var rd = RoomGen.get_room(pos)
	if rd == null:
		return
	if current_room != null:
		current_room.queue_free()
	var scene: PackedScene = load("res://scenes/rooms/RoomBase.tscn")
	if scene == null:
		return
	current_room = scene.instantiate()
	room_holder.add_child(current_room)
	current_room.setup(pos, rd.type, rd.exits)
	rd.visited = true
	GameState.current_room_pos = pos
	if not GameState.visited_rooms.has(pos):
		GameState.visited_rooms.append(pos)
	# Camera snaps to the centre of the room (Isaac style — fixed view).
	_cam_base_offset = Vector2.ZERO
	room_camera.position = Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
	if player and is_instance_valid(player):
		player.global_position = current_room.get_entry_point(from_dir)
	EventBus.room_entered.emit(pos, rd.type)
	EventBus.room_loaded.emit(current_room)


func _on_door_transition(next_pos: Vector2i, from_dir: String) -> void:
	var rd = RoomGen.get_room(next_pos)
	if rd == null:
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.18)
	tw.tween_callback(func(): _load_room(next_pos, from_dir))
	tw.tween_property(fade, "color:a", 0.0, 0.18)


func _on_player_died() -> void:
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/GameOver.tscn")


func _on_boss_died(_pos: Vector2i) -> void:
	GameState.floors_cleared += 1
	GameState.run_floor += 1
	await get_tree().create_timer(2.0).timeout
	if GameState.run_floor > 3:
		get_tree().change_scene_to_file("res://scenes/ui/WinScreen.tscn")
	else:
		EventBus.floor_entered.emit(GameState.run_floor)
		get_tree().reload_current_scene()


func _on_camera_shake(strength: float, duration: float) -> void:
	# Add an offset to the room camera and decay back to zero. We use a
	# tween so multiple shakes overlap nicely.
	var s: float = clampf(strength, 0.5, 16.0)
	var dur: float = clampf(duration, 0.05, 1.5)
	var dst := Vector2(randf_range(-s, s), randf_range(-s, s))
	var t := create_tween()
	t.tween_property(room_camera, "offset", dst, 0.06)
	t.tween_property(room_camera, "offset", Vector2.ZERO, dur)


func _on_impact_effect(pos: Vector2) -> void:
	var p: PackedScene = load("res://scenes/effects/TearImpact.tscn")
	if p == null:
		return
	var n := p.instantiate()
	add_child(n)
	if n is Node2D:
		n.global_position = pos


func _on_blood_splatter(pos: Vector2, _count: int) -> void:
	var p: PackedScene = load("res://scenes/effects/BloodSplatter.tscn")
	if p == null:
		return
	var n := p.instantiate()
	add_child(n)
	if n is Node2D:
		n.global_position = pos


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		if get_tree().paused:
			var pause: PackedScene = load("res://scenes/ui/PauseMenu.tscn")
			if pause:
				var n := pause.instantiate()
				add_child(n)
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_T:
			ChatOverlay.toggle()
