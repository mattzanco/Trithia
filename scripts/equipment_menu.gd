extends Control

const TILE_SIZE = 32

@export var helmet_color := Color(0.7, 0.7, 0.75)

var player = null
var head_slot: Control
var helmet_icon: ColorRect

var is_dragging = false
var drag_offset = Vector2.ZERO
var helmet_world_item = null

func _ready():
	player = get_player_node()
	head_slot = $Panel/VBox/Slots/HeadSlot
	ensure_helmet_icon()
	set_process_input(true)
	set_process(true)
	update_helmet_visual()

func _process(_delta):
	# Keep UI in sync when not dragging
	if not is_dragging:
		update_helmet_visual()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_mouse_on_helmet_icon() or is_mouse_on_head_slot():
				if is_helmet_equipped():
					start_drag(event.global_position)
					get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				finish_drag(event.global_position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging:
		move_icon(event.global_position)
		get_viewport().set_input_as_handled()

func ensure_helmet_icon():
	if helmet_icon != null:
		return
	helmet_icon = ColorRect.new()
	helmet_icon.color = helmet_color
	helmet_icon.size = Vector2(16, 16)
	helmet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(helmet_icon)

func update_helmet_visual():
	if helmet_icon == null:
		return
	if is_helmet_equipped():
		helmet_icon.visible = true
		position_icon_in_slot()
	else:
		helmet_icon.visible = false

func position_icon_in_slot():
	var slot_rect = get_head_slot_rect()
	var icon_pos = slot_rect.position + (slot_rect.size - helmet_icon.size) / 2.0
	helmet_icon.global_position = icon_pos

func start_drag(mouse_pos: Vector2):
	is_dragging = true
	drag_offset = helmet_icon.global_position - mouse_pos

func move_icon(mouse_pos: Vector2):
	helmet_icon.global_position = mouse_pos + drag_offset

func finish_drag(mouse_pos: Vector2):
	is_dragging = false
	if is_point_in_rect(mouse_pos, get_head_slot_rect()):
		set_helmet_equipped(true)
		position_icon_in_slot()
	else:
		set_helmet_equipped(false)
		spawn_helmet_in_world_at(mouse_pos)

func is_helmet_equipped() -> bool:
	return player != null and player.has_helmet

func set_helmet_equipped(equipped: bool):
	if player and player.has_method("set_helmet_equipped"):
		player.set_helmet_equipped(equipped)
	if equipped:
		remove_world_helmet()
	update_helmet_visual()

func is_mouse_on_head_slot() -> bool:
	return is_point_in_rect(get_global_mouse_position(), get_head_slot_rect())

func is_mouse_on_helmet_icon() -> bool:
	if helmet_icon == null or not helmet_icon.visible:
		return false
	var rect = Rect2(helmet_icon.global_position, helmet_icon.size)
	return rect.has_point(get_global_mouse_position())

func get_head_slot_rect() -> Rect2:
	return Rect2(head_slot.global_position, head_slot.size)

func is_point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)

func get_player_node() -> Node:
	var root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	return root.find_child("Player", true, false)

func get_world_node() -> Node:
	var root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	return root.find_child("World", true, false)

func spawn_helmet_in_world_at(screen_pos: Vector2):
	if helmet_world_item != null:
		return
	if player == null:
		player = get_player_node()
	if player == null:
		return
	var world = get_world_node()
	if world == null:
		return
	var helmet_item = Area2D.new()
	helmet_item_setup(helmet_item)
	# Place at mouse drop tile in world space
	var world_pos = screen_to_world_position(screen_pos)
	var snapped = snap_to_tile_center(world_pos)
	helmet_item.position = snapped
	helmet_item.z_index = 0
	world.add_child(helmet_item)
	helmet_world_item = helmet_item
	helmet_item.tree_exited.connect(func():
		if helmet_world_item == helmet_item:
			helmet_world_item = null
	)

func snap_to_tile_center(world_position: Vector2) -> Vector2:
	var tile_x = round(world_position.x / TILE_SIZE)
	var tile_y = round(world_position.y / TILE_SIZE)
	return Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2, tile_y * TILE_SIZE + TILE_SIZE / 2)

func screen_to_world_position(screen_pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return screen_pos
	var camera = viewport.get_camera_2d()
	if camera and camera.has_method("screen_to_world"):
		return camera.screen_to_world(screen_pos)
	# Fallback for CanvasLayer/UI transforms
	var canvas_transform = viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos

func helmet_item_setup(helmet_item: Area2D):
	var helmet_script = load("res://scripts/helmet_item.gd")
	helmet_item.set_script(helmet_script)

func remove_world_helmet():
	if helmet_world_item != null:
		helmet_world_item.queue_free()
		helmet_world_item = null

func try_equip_helmet_from_world(item: Node) -> bool:
	if not is_point_in_rect(get_global_mouse_position(), get_head_slot_rect()):
		return false
	set_helmet_equipped(true)
	if item:
		item.queue_free()
	return true
