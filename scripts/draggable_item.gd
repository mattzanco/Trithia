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
var original_z_index = 0
var original_top_level = false
var drag_canvas_layer: CanvasLayer = null
var drag_visual: Node2D = null
var world = null
var player = null
static var current_drag_item: DraggableItem = null
static var info_layer: CanvasLayer = null
static var info_label: Label = null
static var info_token: int = 0

func _ready():
	input_pickable = true
	world = get_world_node()
	player = get_player_node()
	ensure_collision_shape()
	set_process_input(true)

func _exit_tree():
	if current_drag_item == self:
		current_drag_item = null
	cleanup_drag_layer()
	cleanup_info_layer()

func _input(event):
	handle_drag_input(event)

func _unhandled_input(event):
	# Fallback in case Area2D input events aren't firing
	handle_drag_input(event)

func handle_drag_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if event.pressed:
			if event.shift_pressed and get_pick_rect().has_point(mouse_pos):
				show_center_text(get_item_description(), self)
				get_viewport().set_input_as_handled()
				return
			if get_pick_rect().has_point(mouse_pos) and can_player_drag():
				is_dragging = true
				current_drag_item = self
				original_position = snap_to_tile_center(global_position)
				original_top_level = top_level
				start_drag_rendering()
				drag_offset = global_position - mouse_pos
				get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				is_dragging = false
				end_drag_rendering()
				z_index = original_z_index
				if current_drag_item == self:
					current_drag_item = null
				finish_drop()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset
		update_drag_visual_position(mouse_pos + drag_offset)
		get_viewport().set_input_as_handled()

func finish_drop():
	var snapped_position = snap_to_tile_center(global_position)
	if is_drop_valid(snapped_position):
		global_position = snapped_position
	else:
		global_position = original_position

func snap_to_tile_center(world_position: Vector2) -> Vector2:
	var tile_x = floor(world_position.x / TILE_SIZE)
	var tile_y = floor(world_position.y / TILE_SIZE)
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

func get_item_description() -> String:
	return "Item"

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

func start_drag_rendering():
	# Create a high-layer CanvasLayer to render above UI
	drag_canvas_layer = CanvasLayer.new()
	drag_canvas_layer.layer = 2000
	get_viewport().add_child(drag_canvas_layer)
	
	# Create visual clone on the canvas layer
	drag_visual = Area2D.new()
	drag_visual.input_pickable = false
	drag_visual.monitoring = false
	drag_visual.monitorable = false
	drag_visual.set_process(false)
	drag_visual.set_physics_process(false)
	drag_visual.set_process_input(false)
	drag_visual.set_process_unhandled_input(false)
	drag_visual.set_process_unhandled_key_input(false)
	drag_canvas_layer.add_child(drag_visual)
	
	# Copy the visual from this item
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D or child is Node2D:
			var clone = child.duplicate()
			drag_visual.add_child(clone)
	
	# If this item draws itself, create a proxy that redraws
	if has_method("_draw"):
		drag_visual.set_script(get_script())
		drag_visual.queue_redraw()

func end_drag_rendering():
	cleanup_drag_layer()

func update_drag_visual_position(world_pos: Vector2):
	if drag_visual and is_instance_valid(drag_visual):
		# Convert world position to screen position
		var viewport = get_viewport()
		if viewport:
			var canvas_transform = viewport.get_canvas_transform()
			var screen_pos = canvas_transform * world_pos
			drag_visual.position = screen_pos

func cleanup_drag_layer():
	if drag_visual and is_instance_valid(drag_visual):
		drag_visual.queue_free()
		drag_visual = null
	if drag_canvas_layer and is_instance_valid(drag_canvas_layer):
		drag_canvas_layer.queue_free()
		drag_canvas_layer = null

static func show_center_text(text: String, owner: Node, duration: float = 1.5):
	if owner == null or owner.get_tree() == null:
		return
	var root = owner.get_tree().get_root()
	if root == null:
		return
	if info_layer == null or not is_instance_valid(info_layer):
		info_layer = CanvasLayer.new()
		info_layer.layer = 5000
		root.add_child(info_layer)
	if info_label == null or not is_instance_valid(info_label):
		info_label = Label.new()
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info_label.modulate = Color(0.95, 0.9, 0.8, 1)
		info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		info_label.add_theme_constant_override("outline_size", 2)
		info_label.add_theme_font_size_override("font_size", 18)
		info_layer.add_child(info_label)
	info_label.text = text
	info_label.set_anchors_preset(Control.PRESET_CENTER)
	info_label.position = Vector2.ZERO
	info_label.size = info_label.get_minimum_size()
	info_label.visible = true
	info_token += 1
	var token = info_token
	var timer = owner.get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if token == info_token and is_instance_valid(info_label):
			info_label.visible = false
	)

static func cleanup_info_layer():
	if info_label and is_instance_valid(info_label):
		info_label.queue_free()
		info_label = null
	if info_layer and is_instance_valid(info_layer):
		info_layer.queue_free()
		info_layer = null

