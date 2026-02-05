extends Node2D

const TILE_SIZE = 32

var size_tiles: Vector2i = Vector2i(4, 4)
var roof_color := Color(0.35, 0.2, 0.15)
var is_player_inside := false

func _ready():
	queue_redraw()

func _draw():
	var size_px = Vector2(size_tiles.x * TILE_SIZE, size_tiles.y * TILE_SIZE)
	var roof_col = roof_color
	if is_player_inside:
		roof_col.a = 0.2
	var roof_height = max(6.0, size_px.y - TILE_SIZE)
	var roof_rect = Rect2(Vector2.ZERO, Vector2(size_px.x, roof_height))
	draw_rect(roof_rect, roof_col)
	if is_player_inside:
		var back_wall_col = roof_color
		back_wall_col.a = 0.45
		var back_wall_rect = Rect2(Vector2.ZERO, Vector2(size_px.x, TILE_SIZE))
		draw_rect(back_wall_rect, back_wall_col)
