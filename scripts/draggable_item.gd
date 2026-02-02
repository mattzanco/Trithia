extends Area2D
class_name DraggableItem

const TILE_SIZE = 32

@export var requires_adjacent = true
@export var allow_diagonal_adjacent = true
@export var pick_rect_size = Vector2(32, 32)
@export var pick_rect_offset = Vector2(-16, 0)

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

func _input(event):
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

func get_pick_rect() -> Rect2:
	# Approximate clickable area based on the drawn item
	return Rect2(global_position + pick_rect_offset, pick_rect_size)

func can_player_drag() -> bool:
	if not requires_adjacent:
		return true
	if player == null:
		player = get_player_node()
	if player == null:
		return false
	var player_tile = get_tile_coords(player.global_position)
	var item_tile = get_tile_coords(global_position)
	var dx = abs(player_tile.x - item_tile.x)
	var dy = abs(player_tile.y - item_tile.y)
	if allow_diagonal_adjacent:
		return (dx <= 1 and dy <= 1) and not (dx == 0 and dy == 0)
	return (dx + dy) == 1

func get_tile_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))

func ensure_collision_shape():
	var collision = get_node_or_null("CollisionShape2D")
	if collision == null:
		collision = CollisionShape2D.new()
		add_child(collision)
	var shape = RectangleShape2D.new()
	shape.size = pick_rect_size
	collision.shape = shape
	collision.position = pick_rect_offset + pick_rect_size / 2.0

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
