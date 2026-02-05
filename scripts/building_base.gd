extends Node2D

const TILE_SIZE = 32

var size_tiles: Vector2i = Vector2i(4, 4)
var wall_color := Color(0.6, 0.55, 0.45)
var door_color := Color(0.25, 0.15, 0.1)
var outline_color := Color(0.12, 0.1, 0.08)
var is_player_inside := false

func _ready():
	queue_redraw()

func _draw():
	var size_px = Vector2(size_tiles.x * TILE_SIZE, size_tiles.y * TILE_SIZE)
	var wall_rect = Rect2(Vector2(0, size_px.y - TILE_SIZE), Vector2(size_px.x, TILE_SIZE))
	var wall_col = wall_color
	var outline_col = outline_color
	if is_player_inside:
		wall_col.a = 0.45
		outline_col.a = 0.35
		var floor_col = Color(0.7, 0.65, 0.55, 0.35)
		var floor_rect = Rect2(Vector2.ZERO, size_px)
		draw_rect(floor_rect, floor_col)
	# Bottom wall row (door row)
	draw_rect(wall_rect, wall_col)
	draw_rect(wall_rect, outline_col, false, 1.0)
	# Door (one full tile wide, centered on a tile)
	var door_width = float(TILE_SIZE)
	var door_height = float(TILE_SIZE)
	var door_x = float(int(size_tiles.x / 2) * TILE_SIZE)
	var door_y = float((size_tiles.y - 1) * TILE_SIZE)
	var door_pos = Vector2(door_x, door_y)
	draw_rect(Rect2(door_pos, Vector2(door_width, door_height)), door_color)
