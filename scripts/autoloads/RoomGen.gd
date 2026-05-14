# RoomGen.gd
# Procedural floor / room graph generator.
# Generates a connected map of rooms with start, normal, boss, shop,
# treasure, and (optional) secret rooms — Isaac-style.
extends Node

enum RoomType { START = 0, NORMAL = 1, BOSS = 2, SHOP = 3, TREASURE = 4, SECRET = 5 }

const MIN_ROOMS := 8
const MAX_ROOMS := 12

class RoomData:
	var pos: Vector2i
	var type: int = 1  # RoomType
	var exits: Array = []
	var cleared: bool = false
	var visited: bool = false
	var layout_seed: int = 0

	func _init(p: Vector2i = Vector2i.ZERO, t: int = 1) -> void:
		pos = p
		type = t
		layout_seed = randi()


var rooms: Dictionary = {}              # Vector2i → RoomData
var start_pos: Vector2i = Vector2i.ZERO
var boss_pos: Vector2i = Vector2i.ZERO

const DIRS := {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0),
}

const DIR_OPPOSITE := {
	"north": "south",
	"south": "north",
	"east": "west",
	"west": "east",
}


func generate_floor(floor_num: int) -> void:
	rooms.clear()
	start_pos = Vector2i.ZERO
	_create_room(start_pos, RoomType.START)

	var target := randi_range(MIN_ROOMS + floor_num, MAX_ROOMS + floor_num)
	target = clampi(target, MIN_ROOMS, MAX_ROOMS + 4)
	var frontier: Array = [start_pos]
	var attempts := 0

	while rooms.size() < target and attempts < 500:
		attempts += 1
		if frontier.is_empty():
			break
		var from: Vector2i = frontier[randi() % frontier.size()]
		var dir_keys: Array = DIRS.keys()
		dir_keys.shuffle()
		var added := false
		for dir_name in dir_keys:
			var next_pos: Vector2i = from + DIRS[dir_name]
			if not rooms.has(next_pos) and _count_neighbors(next_pos) <= 1:
				if randf() < 0.7:
					_create_room(next_pos, RoomType.NORMAL)
					_link_rooms(from, next_pos, dir_name)
					frontier.append(next_pos)
					added = true
					break
		if not added and randf() < 0.2:
			frontier.erase(from)

	_assign_special_rooms(floor_num)
	_link_all_adjacent()
	GameState.current_map = rooms


func _create_room(pos: Vector2i, type_: int) -> void:
	rooms[pos] = RoomData.new(pos, type_)


func _link_rooms(a: Vector2i, b: Vector2i, dir: String) -> void:
	if rooms.has(a) and dir not in rooms[a].exits:
		rooms[a].exits.append(dir)
	if rooms.has(b):
		var opp: String = DIR_OPPOSITE[dir]
		if opp not in rooms[b].exits:
			rooms[b].exits.append(opp)


func _link_all_adjacent() -> void:
	for pos in rooms:
		for dir_name in DIRS:
			var neighbor: Vector2i = pos + DIRS[dir_name]
			if rooms.has(neighbor):
				if dir_name not in rooms[pos].exits:
					rooms[pos].exits.append(dir_name)
				var opp: String = DIR_OPPOSITE[dir_name]
				if opp not in rooms[neighbor].exits:
					rooms[neighbor].exits.append(opp)


func _count_neighbors(pos: Vector2i) -> int:
	var count := 0
	for d in DIRS.values():
		if rooms.has(pos + d):
			count += 1
	return count


func _assign_special_rooms(floor_num: int) -> void:
	# Boss: farthest from spawn (Manhattan distance).
	var farthest: Vector2i = Vector2i.ZERO
	var max_dist := 0
	for pos in rooms:
		if pos == start_pos:
			continue
		var dist: int = absi(pos.x) + absi(pos.y)
		if dist > max_dist:
			max_dist = dist
			farthest = pos
	if rooms.has(farthest) and farthest != start_pos:
		rooms[farthest].type = RoomType.BOSS
		boss_pos = farthest

	# Choose shop, treasure, secret from leftover normal rooms.
	var normals: Array = []
	for pos in rooms:
		if rooms[pos].type == RoomType.NORMAL and pos != start_pos:
			normals.append(pos)
	normals.shuffle()

	if normals.size() > 0:
		rooms[normals[0]].type = RoomType.SHOP
	if normals.size() > 1:
		rooms[normals[1]].type = RoomType.TREASURE
	if normals.size() > 2 and floor_num >= 2:
		rooms[normals[2]].type = RoomType.SECRET


func get_room(pos: Vector2i):
	return rooms.get(pos, null)


func get_exits(pos: Vector2i) -> Array:
	var r = get_room(pos)
	if r != null:
		return r.exits
	return []


func map_size() -> int:
	return rooms.size()


func describe() -> String:
	return "Floor %d: %d rooms, boss @ %s" % [
		GameState.run_floor, rooms.size(), str(boss_pos)
	]
