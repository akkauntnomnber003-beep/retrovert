# RoomBase.gd
# Generic room: walls, doors, optional obstacles, enemy spawn points,
# pickup placement, win condition.
extends Node2D
class_name RoomBase

const ROOM_W := 1280
const ROOM_H := 720
const TILE_SIZE := 40
const PLAYFIELD_LEFT := 80
const PLAYFIELD_TOP := 80
const PLAYFIELD_RIGHT := ROOM_W - 80
const PLAYFIELD_BOTTOM := ROOM_H - 80

@onready var floor_tiles: Node2D = $FloorTiles
@onready var wall_tiles: Node2D = $WallTiles
@onready var doors_node: Node2D = $Doors
@onready var spawn_root: Node2D = $SpawnRoot
@onready var pickup_root: Node2D = $PickupRoot

var room_pos: Vector2i = Vector2i.ZERO
var room_type: int = 1
var exits: Array = []
var doors: Dictionary = {}
var enemies_alive: int = 0
var cleared: bool = false
var floor_texture: Texture2D
var wall_top_texture: Texture2D
var wall_side_texture: Texture2D

var enemy_pool: Array = [
	"res://scenes/enemies/Fly.tscn",
	"res://scenes/enemies/Gaper.tscn",
	"res://scenes/enemies/Pooter.tscn",
	"res://scenes/enemies/Leaper.tscn",
	"res://scenes/enemies/Spider.tscn",
]


func setup(pos: Vector2i, type_: int, available_exits: Array) -> void:
	room_pos = pos
	room_type = type_
	exits = available_exits
	_load_textures()
	_build_floor()
	_build_walls()
	_setup_doors()
	_populate_room()


func _load_textures() -> void:
	if ResourceLoader.exists("res://assets/sprites/rooms/floor_basement.png"):
		floor_texture = load("res://assets/sprites/rooms/floor_basement.png")
	if ResourceLoader.exists("res://assets/sprites/rooms/wall_top.png"):
		wall_top_texture = load("res://assets/sprites/rooms/wall_top.png")
	if ResourceLoader.exists("res://assets/sprites/rooms/wall_side.png"):
		wall_side_texture = load("res://assets/sprites/rooms/wall_side.png")


func _build_floor() -> void:
	if floor_texture == null:
		return
	var cell: int = floor_texture.get_width()
	if cell <= 0:
		cell = 16
	# Scale tiles to TILE_SIZE so the floor is filled.
	var step: int = TILE_SIZE
	for y in range(PLAYFIELD_TOP, PLAYFIELD_BOTTOM, step):
		for x in range(PLAYFIELD_LEFT, PLAYFIELD_RIGHT, step):
			var s := Sprite2D.new()
			s.texture = floor_texture
			s.centered = false
			s.scale = Vector2(step / float(cell), step / float(cell))
			s.position = Vector2(x, y)
			floor_tiles.add_child(s)


func _build_walls() -> void:
	# Top wall band — uses two sprite layers:
	#   * normal layer (drawn behind player so player's feet pass *over* the
	#     wall base when y > wall.bottom)
	#   * overhang layer (z_index = 100) which always draws on top so the
	#     top half of the player's body can slide behind the wall visually.
	if wall_top_texture:
		var w: int = wall_top_texture.get_width()
		var ratio: float = TILE_SIZE / float(w)
		for x in range(0, ROOM_W, TILE_SIZE):
			var s := Sprite2D.new()
			s.texture = wall_top_texture
			s.centered = false
			s.scale = Vector2(ratio, ratio)
			s.position = Vector2(x, 0)
			s.z_index = 100  # Top wall draws above the player while
			s.z_as_relative = false  # the player overlaps its lower half.
			wall_tiles.add_child(s)
			var s2 := Sprite2D.new()
			s2.texture = wall_top_texture
			s2.centered = false
			s2.flip_v = true
			s2.scale = Vector2(ratio, ratio)
			s2.position = Vector2(x, ROOM_H - TILE_SIZE)
			wall_tiles.add_child(s2)
	if wall_side_texture:
		var w2: int = wall_side_texture.get_width()
		var r2: float = TILE_SIZE / float(w2)
		for y in range(0, ROOM_H, TILE_SIZE):
			var l := Sprite2D.new()
			l.texture = wall_side_texture
			l.centered = false
			l.scale = Vector2(r2, r2)
			l.position = Vector2(0, y)
			wall_tiles.add_child(l)
			var r := Sprite2D.new()
			r.texture = wall_side_texture
			r.centered = false
			r.flip_h = true
			r.scale = Vector2(r2, r2)
			r.position = Vector2(ROOM_W - TILE_SIZE, y)
			wall_tiles.add_child(r)
	# Outer wall collider
	_create_wall_collider()


func _create_wall_collider() -> void:
	# Colliders are intentionally smaller than the visual wall band so the
	# player can overlap the bottom half of the top wall (Isaac-style: head
	# slides behind the wall). The overhang sprites have z_index=100 so
	# they always draw above the player.
	const OVERHANG_PX := 24
	var sb := StaticBody2D.new()
	sb.name = "WallCollider"
	sb.collision_layer = (1 << 0) | (1 << 6)
	sb.collision_mask = 0
	var top_h: float = max(8.0, PLAYFIELD_TOP - OVERHANG_PX)
	var bot_h: float = PLAYFIELD_TOP
	# Top wall — shorter so the player can poke their head behind it.
	_add_rect(sb, Vector2(ROOM_W * 0.5, top_h * 0.5), Vector2(ROOM_W, top_h))
	# Bottom wall — full height.
	_add_rect(sb, Vector2(ROOM_W * 0.5, ROOM_H - bot_h * 0.5),
		Vector2(ROOM_W, bot_h))
	# Sides — full height.
	_add_rect(sb, Vector2(PLAYFIELD_LEFT * 0.5, ROOM_H * 0.5),
		Vector2(PLAYFIELD_LEFT, ROOM_H))
	_add_rect(sb, Vector2(ROOM_W - PLAYFIELD_LEFT * 0.5, ROOM_H * 0.5),
		Vector2(PLAYFIELD_LEFT, ROOM_H))
	add_child(sb)


func _add_rect(parent: Node, pos: Vector2, size: Vector2) -> void:
	var c := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	c.shape = rect
	c.position = pos
	parent.add_child(c)


func _setup_doors() -> void:
	const door_pos := {
		"north": Vector2(ROOM_W * 0.5, 40),
		"south": Vector2(ROOM_W * 0.5, ROOM_H - 40),
		"east": Vector2(ROOM_W - 40, ROOM_H * 0.5),
		"west": Vector2(40, ROOM_H * 0.5),
	}
	for dir in exits:
		var door_scene: PackedScene = load("res://scenes/rooms/Door.tscn")
		if door_scene == null:
			continue
		var d: Node2D = door_scene.instantiate()
		d.position = door_pos[dir]
		d.set("direction", dir)
		d.set("room_pos", room_pos)
		doors[dir] = d
		doors_node.add_child(d)


func _populate_room() -> void:
	if room_type == RoomGen.RoomType.START:
		return
	# Already-cleared rooms stay empty when re-entered — no enemy respawn,
	# no locked doors. This is the standard Isaac behaviour.
	if room_pos in GameState.cleared_rooms:
		cleared = true
		return
	if room_type == RoomGen.RoomType.BOSS:
		_spawn_boss()
		_lock_all_doors()
		return
	if room_type == RoomGen.RoomType.TREASURE:
		_place_treasure()
		return
	if room_type == RoomGen.RoomType.SHOP:
		_place_shop()
		return
	# Normal / secret
	_spawn_enemies()
	if enemies_alive > 0:
		_lock_all_doors()


func _spawn_enemies() -> void:
	var count: int = clampi(2 + GameState.run_floor + (randi() % 4),
		2, 8)
	for i in count:
		var path: String = enemy_pool[randi() % enemy_pool.size()]
		if not ResourceLoader.exists(path):
			continue
		var n: Node2D = load(path).instantiate()
		var x := randi_range(PLAYFIELD_LEFT + 60, PLAYFIELD_RIGHT - 60)
		var y := randi_range(PLAYFIELD_TOP + 60, PLAYFIELD_BOTTOM - 60)
		n.position = Vector2(x, y)
		if n.has_signal("died"):
			n.died.connect(_on_enemy_died)
		spawn_root.add_child(n)
		enemies_alive += 1


func _spawn_boss() -> void:
	var boss_path: String = "res://scenes/enemies/bosses/Monstro.tscn"
	if GameState.run_floor >= 2 and randf() < 0.5:
		boss_path = "res://scenes/enemies/bosses/LarryJr.tscn"
	if not ResourceLoader.exists(boss_path):
		return
	var n: Node2D = load(boss_path).instantiate()
	n.position = Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
	if n.has_signal("died"):
		n.died.connect(_on_boss_died)
	spawn_root.add_child(n)
	enemies_alive = 1


func _place_treasure() -> void:
	var scene: PackedScene = load("res://scenes/items/ItemPickup.tscn")
	if scene == null:
		return
	var n: Node2D = scene.instantiate()
	n.position = Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
	var id: String = ItemDatabase.get_random_passive()
	if "item_id" in n:
		n.set("item_id", id)
	pickup_root.add_child(n)


func _place_shop() -> void:
	for i in 3:
		var coin_scene: PackedScene = load("res://scenes/items/Coin.tscn")
		if coin_scene == null:
			continue
		var c: Node2D = coin_scene.instantiate()
		c.position = Vector2(ROOM_W * 0.5 - 120 + i * 120, ROOM_H * 0.5)
		pickup_root.add_child(c)


func _lock_all_doors() -> void:
	for d in doors.values():
		if d.has_method("lock"):
			d.lock()


func _open_all_doors() -> void:
	for d in doors.values():
		if d.has_method("unlock"):
			d.unlock()


func _on_enemy_died(_pos: Vector2, _type: String) -> void:
	enemies_alive -= 1
	if enemies_alive <= 0 and not cleared:
		_clear_room()


func _on_boss_died(_pos: Vector2, _type: String) -> void:
	enemies_alive = 0
	_clear_room()
	_place_treasure()


func _clear_room() -> void:
	cleared = true
	_open_all_doors()
	if not (room_pos in GameState.cleared_rooms):
		GameState.cleared_rooms.append(room_pos)
	EventBus.room_cleared.emit(room_pos)
	AudioManager.play_sfx("room_clear")


func get_entry_point(from_dir: String) -> Vector2:
	match from_dir:
		"north": return Vector2(ROOM_W * 0.5, PLAYFIELD_TOP + 60)
		"south": return Vector2(ROOM_W * 0.5, PLAYFIELD_BOTTOM - 60)
		"east": return Vector2(PLAYFIELD_RIGHT - 60, ROOM_H * 0.5)
		"west": return Vector2(PLAYFIELD_LEFT + 60, ROOM_H * 0.5)
	return Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
