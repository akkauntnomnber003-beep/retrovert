# MiniMap.gd
# Renders the procedurally-generated map as a small grid in the corner.
extends Control

const CELL_SIZE := 14
const CELL_GAP := 2

@onready var color_map := {
	RoomGen.RoomType.START: Color(0.55, 0.55, 0.55),
	RoomGen.RoomType.NORMAL: Color(0.45, 0.45, 0.45),
	RoomGen.RoomType.BOSS: Color(0.85, 0.25, 0.25),
	RoomGen.RoomType.SHOP: Color(0.25, 0.7, 0.25),
	RoomGen.RoomType.TREASURE: Color(0.9, 0.8, 0.3),
	RoomGen.RoomType.SECRET: Color(0.2, 0.2, 0.25),
}


func _ready() -> void:
	EventBus.room_entered.connect(func(_p, _t): queue_redraw())
	EventBus.room_cleared.connect(func(_p): queue_redraw())


func _draw() -> void:
	if RoomGen.rooms.is_empty():
		return
	# Find min/max so we can offset.
	var min_x: int = 999
	var min_y: int = 999
	for pos in RoomGen.rooms:
		min_x = min(min_x, pos.x)
		min_y = min(min_y, pos.y)
	for pos in RoomGen.rooms:
		var rd = RoomGen.rooms[pos]
		var local := Vector2i(pos.x - min_x, pos.y - min_y)
		var rect := Rect2(
			Vector2(local.x * (CELL_SIZE + CELL_GAP),
				local.y * (CELL_SIZE + CELL_GAP)),
			Vector2(CELL_SIZE, CELL_SIZE))
		var col: Color = color_map.get(rd.type, Color.GRAY)
		if not rd.visited and pos != GameState.current_room_pos:
			col.a = 0.35
		if pos == GameState.current_room_pos:
			col = Color.WHITE
		draw_rect(rect, col, true)
		draw_rect(rect, Color(0, 0, 0, 1), false, 1)
