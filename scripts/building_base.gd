extends Node2D

const TILE_SIZE = 32

var size_tiles: Vector2i = Vector2i(4, 4)
var wall_color := Color(0.6, 0.55, 0.45)
var door_color := Color(0.25, 0.15, 0.1)
var outline_color := Color(0.12, 0.1, 0.08)
var is_player_inside := false
var door_open := false

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
	# Door (one full tile wide, centered on a tile)
	var door_width = float(TILE_SIZE)
	var door_height = float(TILE_SIZE)
	var door_x = float(int(size_tiles.x / 2) * TILE_SIZE)
	var door_y = float((size_tiles.y - 1) * TILE_SIZE)
	var door_pos = Vector2(door_x, door_y)
	# Bottom wall row (door row) with a doorway gap.
	var left_width = max(0.0, door_pos.x)
	var right_x = door_pos.x + door_width
	var right_width = max(0.0, size_px.x - right_x)
	if left_width > 0.0:
		var left_rect = Rect2(Vector2(0, door_pos.y), Vector2(left_width, door_height))
		draw_rect(left_rect, wall_col)
		draw_rect(left_rect, outline_col, false, 1.0)
	if right_width > 0.0:
		var right_rect = Rect2(Vector2(right_x, door_pos.y), Vector2(right_width, door_height))
		draw_rect(right_rect, wall_col)
		draw_rect(right_rect, outline_col, false, 1.0)
	# Doorway is transparent when open; show a faint frame when inside.
	if not door_open and not is_player_inside:
		var door_rect = Rect2(door_pos, Vector2(door_width, door_height))
		draw_rect(door_rect, door_color)
		draw_rect(door_rect, outline_col, false, 1.0)
		var panel_col = door_color.lightened(0.12)
		var panel_rect = Rect2(door_pos + Vector2(4, 4), Vector2(door_width - 8, door_height - 8))
		draw_rect(panel_rect, panel_col)
		var handle_col = door_color.darkened(0.25)
		var handle_rect = Rect2(door_pos + Vector2(door_width - 7, door_height / 2 - 1), Vector2(3, 4))
		draw_rect(handle_rect, handle_col)
	elif not door_open and is_player_inside:
		var door_col = door_color
		door_col.a = 0.45
		var frame_col = outline_col
		frame_col.a = 0.35
		var door_rect = Rect2(door_pos, Vector2(door_width, door_height))
		draw_rect(door_rect, door_col)
		draw_rect(door_rect, frame_col, false, 1.0)
		var panel_col = door_color.lightened(0.12)
		panel_col.a = 0.35
		var panel_rect = Rect2(door_pos + Vector2(4, 4), Vector2(door_width - 8, door_height - 8))
		draw_rect(panel_rect, panel_col)
		var handle_col = door_color.darkened(0.25)
		handle_col.a = 0.35
		var handle_rect = Rect2(door_pos + Vector2(door_width - 7, door_height / 2 - 1), Vector2(3, 4))
		draw_rect(handle_rect, handle_col)
