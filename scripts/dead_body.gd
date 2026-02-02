extends Area2D

# Visual representation of a dead orc

const TILE_SIZE = 32

var is_dragging = false
var drag_offset = Vector2.ZERO
var original_position = Vector2.ZERO
var world = null
var player = null

func _ready():
	input_pickable = true
	world = get_world_node()
	player = get_player_node()
	ensure_collision_shape()
	set_process_input(true)
	# Make sure the body is drawn when added to the scene
	queue_redraw()

func _input(event):
	handle_drag_input(event)

func get_world_node() -> Node:
	var parent = get_parent()
	if parent:
		if parent.name == "World":
			return parent
		var world_node = parent.get_node_or_null("World")
		if world_node:
			return world_node
	return get_tree().get_root().find_child("World", true, false)

func get_player_node() -> Node:
	var parent = get_parent()
	if parent:
		var player_node = parent.get_node_or_null("Player")
		if player_node:
			return player_node
	return get_tree().get_root().find_child("Player", true, false)

func ensure_collision_shape():
	if get_node_or_null("CollisionShape2D"):
		return
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	collision.shape = shape
	collision.position = Vector2(0, 16)
	add_child(collision)

func _input_event(_viewport, event, _shape_idx):
	handle_drag_input(event)

func _unhandled_input(event):
	# Fallback in case Area2D input events aren't firing
	handle_drag_input(event)

func handle_drag_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if event.pressed:
			if get_pick_rect().has_point(mouse_pos) and can_player_drag():
				is_dragging = true
				original_position = global_position
				drag_offset = global_position - mouse_pos
				get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				is_dragging = false
				finish_drop()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset
		get_viewport().set_input_as_handled()

func get_pick_rect() -> Rect2:
	# Approximate clickable area based on the drawn body
	return Rect2(global_position + Vector2(-16, 0), Vector2(32, 32))

func can_player_drag() -> bool:
	if player == null:
		player = get_player_node()
	if player == null:
		return false
	var player_tile = get_tile_coords(player.global_position)
	var body_tile = get_tile_coords(global_position)
	var dx = abs(player_tile.x - body_tile.x)
	var dy = abs(player_tile.y - body_tile.y)
	# Must be adjacent (including diagonals), not the same tile
	return (dx <= 1 and dy <= 1) and not (dx == 0 and dy == 0)

func get_tile_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))

func finish_drop():
	var snapped_position = snap_to_tile_center(global_position)
	if is_drop_valid(snapped_position):
		global_position = snapped_position
	else:
		global_position = original_position

func snap_to_tile_center(world_position: Vector2) -> Vector2:
	var tile_x = round(world_position.x / TILE_SIZE)
	var tile_y = round(world_position.y / TILE_SIZE)
	return Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2, tile_y * TILE_SIZE + TILE_SIZE / 2)

func is_drop_valid(world_position: Vector2) -> bool:
	if world and world.has_method("is_walkable"):
		return world.is_walkable(world_position)
	return true

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


