extends Node2D

const TILE_SIZE = 32

@export var trunk_color := Color(0.45, 0.3, 0.15)
@export var trunk_dark := Color(0.3, 0.2, 0.1)
@export var outline_color := Color(0.1, 0.1, 0.1)

func _ready():
	z_as_relative = true
	z_index = 0
	queue_redraw()

func _draw():
	# Trunk occupies the lower tile.
	var trunk_base_w = 26.0
	var trunk_top_w = 16.0
	var trunk_h = 24.0
	var trunk_bottom_y = TILE_SIZE / 2.0
	var trunk_top_y = trunk_bottom_y - trunk_h
	var trunk_poly = PackedVector2Array([
		Vector2(-trunk_base_w / 2.0, trunk_bottom_y),
		Vector2(trunk_base_w / 2.0, trunk_bottom_y),
		Vector2(trunk_top_w / 2.0, trunk_top_y),
		Vector2(-trunk_top_w / 2.0, trunk_top_y)
	])
	draw_colored_polygon(trunk_poly, trunk_color)
	draw_polyline(trunk_poly, outline_color, 1.0, true)
	# A darker core for depth.
	var core_poly = PackedVector2Array([
		Vector2(-trunk_base_w / 2.0 + 5.0, trunk_bottom_y - 2.0),
		Vector2(trunk_base_w / 2.0 - 5.0, trunk_bottom_y - 2.0),
		Vector2(trunk_top_w / 2.0 - 3.0, trunk_top_y + 3.0),
		Vector2(-trunk_top_w / 2.0 + 3.0, trunk_top_y + 3.0)
	])
	draw_colored_polygon(core_poly, trunk_dark)
	# Small roots at the base.
	draw_rect(Rect2(Vector2(-trunk_base_w / 2.0 - 2.0, trunk_bottom_y - 6.0), Vector2(6.0, 6.0)), trunk_dark)
	draw_rect(Rect2(Vector2(trunk_base_w / 2.0 - 4.0, trunk_bottom_y - 6.0), Vector2(6.0, 6.0)), trunk_dark)
