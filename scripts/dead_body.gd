extends Node2D

# Visual representation of a dead orc

const TILE_SIZE = 32

func _draw():
	# Draw a dead orc lying sideways (pale green) centered in tile
	var dead_color = Color(0.6, 0.8, 0.6)  # Pale green
	var outline_color = Color(0.3, 0.4, 0.3)  # Dark green outline
	var blood_color = Color(0.8, 0.1, 0.1, 0.6)
	
	# Head (lying on its side)
	draw_rect(Rect2(8, 8, 12, 12), dead_color)
	draw_rect(Rect2(7, 7, 14, 14), outline_color, false, 1.0)
	
	# X eyes (death symbol) on the side of head
	draw_line(Vector2(10, 10), Vector2(12, 12), Color.BLACK, 1.5)
	draw_line(Vector2(12, 10), Vector2(10, 12), Color.BLACK, 1.5)
	
	# Body (torso lying horizontal)
	draw_rect(Rect2(-8, 11, 18, 10), dead_color)
	draw_rect(Rect2(-9, 10, 20, 12), outline_color, false, 1.0)
	
	# Left arm (extended up from body)
	draw_line(Vector2(-8, 11), Vector2(-12, 6), dead_color, 3.0)
	draw_line(Vector2(-8, 11), Vector2(-12, 6), outline_color, 1.0)
	
	# Right arm (under body)
	draw_line(Vector2(10, 16), Vector2(14, 20), dead_color, 3.0)
	draw_line(Vector2(10, 16), Vector2(14, 20), outline_color, 1.0)
	
	# Legs (extended to the right, lying down)
	draw_line(Vector2(10, 13), Vector2(16, 12), dead_color, 3.0)
	draw_line(Vector2(10, 13), Vector2(16, 12), outline_color, 1.0)
	draw_line(Vector2(10, 17), Vector2(16, 18), dead_color, 3.0)
	draw_line(Vector2(10, 17), Vector2(16, 18), outline_color, 1.0)
	
	# Blood pool under the body
	draw_circle(Vector2(0, 18), 2.0, blood_color)
	draw_circle(Vector2(5, 19), 1.5, blood_color)
	draw_circle(Vector2(-5, 17), 1.5, blood_color)


