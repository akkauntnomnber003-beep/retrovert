# RoomBase.gd
# A single Isaac-style room. The room owns its floor tiles, walls,
# doors, obstacles (rocks/pits/poops) and the enemies/pickups currently
# in play. The camera lives on Game.gd and is fixed at the centre of
# the room, so as far as gameplay is concerned the playfield is exactly
# 1280×720 with an 80px safe margin on every side.
extends Node2D
class_name RoomBase

const ROOM_W := 1280
const ROOM_H := 720
const TILE_SIZE := 64
const PLAYFIELD_LEFT := 96
const PLAYFIELD_TOP := 96
const PLAYFIELD_RIGHT := ROOM_W - 96
const PLAYFIELD_BOTTOM := ROOM_H - 96

@onready var floor_tiles: Node2D = $FloorTiles
@onready var wall_tiles: Node2D = $WallTiles
@onready var doors_node: Node2D = $Doors
@onready var spawn_root: Node2D = $SpawnRoot
@onready var pickup_root: Node2D = $PickupRoot
@onready var obstacle_root: Node2D = $ObstacleRoot

var room_pos: Vector2i = Vector2i.ZERO
var room_type: int = 1
var exits: Array = []
var doors: Dictionary = {}
var enemies_alive: int = 0
var cleared: bool = false
var floor_texture: Texture2D
var wall_top_texture: Texture2D
var wall_side_texture: Texture2D
var rock_texture: Texture2D
var pit_texture: Texture2D
var poop_texture: Texture2D

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
	_place_obstacles()
	_populate_room()


func _load_textures() -> void:
	if ResourceLoader.exists("res://assets/sprites/rooms/floor_basement.png"):
		floor_texture = load("res://assets/sprites/rooms/floor_basement.png")
	if ResourceLoader.exists("res://assets/sprites/rooms/wall_top.png"):
		wall_top_texture = load("res://assets/sprites/rooms/wall_top.png")
	if ResourceLoader.exists("res://assets/sprites/rooms/wall_side.png"):
		wall_side_texture = load("res://assets/sprites/rooms/wall_side.png")
	if ResourceLoader.exists("res://assets/sprites/rooms/rock.png"):
		rock_texture = load("res://assets/sprites/rooms/rock.png")
	if ResourceLoader.exists("res://assets/sprites/rooms/pit.png"):
		pit_texture = load("res://assets/sprites/rooms/pit.png")
	if ResourceLoader.exists("res://assets/sprites/rooms/poop.png"):
		poop_texture = load("res://assets/sprites/rooms/poop.png")


func _build_floor() -> void:
	if floor_texture == null:
		return
	var cell: int = floor_texture.get_width()
	if cell <= 0:
		cell = 16
	var step: int = TILE_SIZE
	for y in range(PLAYFIELD_TOP, PLAYFIELD_BOTTOM, step):
		for x in range(PLAYFIELD_LEFT, PLAYFIELD_RIGHT, step):
			var s := Sprite2D.new()
			s.texture = floor_texture
			s.centered = false
			s.scale = Vector2(step / float(cell), step / float(cell))
			s.position = Vector2(x, y)
			# Vary tint slightly so the floor doesn't look like wallpaper.
			s.modulate = Color(1, 1, 1).lerp(
				Color(0.8, 0.78, 0.75), 0.18 * randf())
			floor_tiles.add_child(s)


func _build_walls() -> void:
	if wall_top_texture:
		var w: int = wall_top_texture.get_width()
		var ratio: float = TILE_SIZE / float(w)
		for x in range(0, ROOM_W, TILE_SIZE):
			var s := Sprite2D.new()
			s.texture = wall_top_texture
			s.centered = false
			s.scale = Vector2(ratio, ratio)
			s.position = Vector2(x, 0)
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
	_create_wall_collider()


func _create_wall_collider() -> void:
	# Static body around the playfield. Player + bullets collide with it.
	var sb := StaticBody2D.new()
	sb.name = "WallCollider"
	sb.collision_layer = (1 << 0) | (1 << 6)
	sb.collision_mask = 0
	# Top
	var top := CollisionShape2D.new()
	var rt := RectangleShape2D.new()
	rt.size = Vector2(ROOM_W, PLAYFIELD_TOP * 2)
	top.shape = rt
	top.position = Vector2(ROOM_W * 0.5, 0)
	sb.add_child(top)
	# Bottom
	var bot := CollisionShape2D.new()
	var rb := RectangleShape2D.new()
	rb.size = Vector2(ROOM_W, PLAYFIELD_TOP * 2)
	bot.shape = rb
	bot.position = Vector2(ROOM_W * 0.5, ROOM_H)
	sb.add_child(bot)
	# Left
	var left := CollisionShape2D.new()
	var rl := RectangleShape2D.new()
	rl.size = Vector2(PLAYFIELD_LEFT * 2, ROOM_H)
	left.shape = rl
	left.position = Vector2(0, ROOM_H * 0.5)
	sb.add_child(left)
	# Right
	var right := CollisionShape2D.new()
	var rr := RectangleShape2D.new()
	rr.size = Vector2(PLAYFIELD_LEFT * 2, ROOM_H)
	right.shape = rr
	right.position = Vector2(ROOM_W, ROOM_H * 0.5)
	sb.add_child(right)
	add_child(sb)


func _setup_doors() -> void:
	const door_pos := {
		"north": Vector2(ROOM_W * 0.5, PLAYFIELD_TOP - 32),
		"south": Vector2(ROOM_W * 0.5, PLAYFIELD_BOTTOM + 32),
		"east":  Vector2(PLAYFIELD_RIGHT + 32, ROOM_H * 0.5),
		"west":  Vector2(PLAYFIELD_LEFT - 32, ROOM_H * 0.5),
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


func _place_obstacles() -> void:
	# A handful of rocks/poops/pits, never near doors or the centre.
	if room_type == RoomGen.RoomType.START or \
			room_type == RoomGen.RoomType.SHOP or \
			room_type == RoomGen.RoomType.TREASURE:
		return
	var count: int = randi_range(0, 4)
	var center := Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
	for _i in count:
		var attempts := 6
		while attempts > 0:
			attempts -= 1
			var x := randi_range(PLAYFIELD_LEFT + 120, PLAYFIELD_RIGHT - 120)
			var y := randi_range(PLAYFIELD_TOP + 120, PLAYFIELD_BOTTOM - 120)
			var pos := Vector2(x, y)
			if pos.distance_to(center) < 110.0:
				continue
			_spawn_obstacle(pos)
			break


func _spawn_obstacle(pos: Vector2) -> void:
	var pick: float = randf()
	var tex: Texture2D = rock_texture
	var blocks: bool = true
	if pick > 0.65 and poop_texture:
		tex = poop_texture
	elif pick > 0.85 and pit_texture:
		tex = pit_texture
		blocks = true  # pit also blocks player movement
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	obstacle_root.add_child(s)
	if not blocks:
		return
	var sb := StaticBody2D.new()
	sb.collision_layer = (1 << 0) | (1 << 6)
	sb.collision_mask = 0
	var col := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 26.0
	col.shape = c
	sb.add_child(col)
	sb.position = pos
	obstacle_root.add_child(sb)


func _populate_room() -> void:
	if room_type == RoomGen.RoomType.START:
		return
	if room_type == RoomGen.RoomType.BOSS:
		_spawn_boss()
		_lock_all_doors()
		EventBus.boss_fight_started.emit(self)
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
	var count: int = clampi(2 + GameState.run_floor + (randi() % 4), 2, 8)
	for i in count:
		var path: String = enemy_pool[randi() % enemy_pool.size()]
		if not ResourceLoader.exists(path):
			continue
		var n: Node2D = load(path).instantiate()
		var x := randi_range(PLAYFIELD_LEFT + 80, PLAYFIELD_RIGHT - 80)
		var y := randi_range(PLAYFIELD_TOP + 80, PLAYFIELD_BOTTOM - 80)
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
		c.position = Vector2(ROOM_W * 0.5 - 200 + i * 200, ROOM_H * 0.5)
		pickup_root.add_child(c)


func _lock_all_doors() -> void:
	for d in doors.values():
		if d.has_method("lock"):
			d.lock()


func _open_all_doors() -> void:
	for d in doors.values():
		if d.has_method("unlock"):
			d.unlock()


func _on_enemy_died(pos: Vector2, type_name: String) -> void:
	enemies_alive -= 1
	# Drop some loot with a small scatter so it looks alive.
	_scatter_drop(pos)
	if enemies_alive <= 0 and not cleared:
		_clear_room()


func _on_boss_died(pos: Vector2, _type: String) -> void:
	enemies_alive = 0
	_clear_room()
	_place_treasure()
	# Boss always drops a heart + coins.
	for i in 4:
		_scatter_drop(pos, true)
	EventBus.boss_died.emit(room_pos)


func _scatter_drop(pos: Vector2, force: bool = false) -> void:
	if not force and randf() > 0.35:
		return
	var pick: float = randf()
	var path: String
	if pick < 0.50:
		path = "res://scenes/items/Coin.tscn"
	elif pick < 0.78:
		path = "res://scenes/items/Heart.tscn"
	elif pick < 0.92:
		path = "res://scenes/items/Bomb.tscn"
	else:
		path = "res://scenes/items/Key.tscn"
	if not ResourceLoader.exists(path):
		return
	var p: Node2D = load(path).instantiate()
	pickup_root.add_child(p)
	p.global_position = pos
	# Give pickups a little kinetic kick — Pickup.gd handles drag.
	if "scatter_impulse" in p:
		p.scatter_impulse = Vector2(
			randf_range(-180, 180), randf_range(-180, 180))


func _clear_room() -> void:
	cleared = true
	_open_all_doors()
	GameState.cleared_rooms.append(room_pos)
	EventBus.room_cleared.emit(room_pos)
	AudioManager.play_sfx("room_clear")


func get_entry_point(from_dir: String) -> Vector2:
	match from_dir:
		"north": return Vector2(ROOM_W * 0.5, PLAYFIELD_TOP + 80)
		"south": return Vector2(ROOM_W * 0.5, PLAYFIELD_BOTTOM - 80)
		"east":  return Vector2(PLAYFIELD_RIGHT - 80, ROOM_H * 0.5)
		"west":  return Vector2(PLAYFIELD_LEFT + 80, ROOM_H * 0.5)
	return Vector2(ROOM_W * 0.5, ROOM_H * 0.5)
