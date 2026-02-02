extends Control

const TILE_SIZE = 32

@export var helmet_color := Color(0.7, 0.7, 0.75)

const DRAGGABLE_SCRIPT = preload("res://scripts/draggable_item.gd")

var player = null
var head_slot: Control
var helmet_icon: TextureRect
var ghost_icon: TextureRect
var ghost_layer: CanvasLayer

var is_dragging = false
var drag_offset = Vector2.ZERO
var helmet_world_item = null
var head_slot_style: StyleBox
var head_slot_highlight: StyleBox

func _ready():
	player = get_player_node()
	head_slot = $Panel/Margin/Center/VBox/SlotGrid/HeadSlot
	head_slot_style = head_slot.get_theme_stylebox("panel")
	head_slot_highlight = create_highlight_style()
	ensure_helmet_icon()
	ensure_ghost_icon()
	set_process_input(true)
	set_process(true)
	update_helmet_visual()

func _exit_tree():
	if helmet_world_item and is_instance_valid(helmet_world_item):
		helmet_world_item.queue_free()
		helmet_world_item = null
	if ghost_layer and is_instance_valid(ghost_layer):
		ghost_layer.queue_free()
		ghost_layer = null
		ghost_icon = null
	if helmet_icon and is_instance_valid(helmet_icon):
		helmet_icon.queue_free()
		helmet_icon = null

func _process(_delta):
	# Keep UI in sync when not dragging
	if not is_dragging:
		update_helmet_visual()
	if ghost_icon == null:
		ensure_ghost_icon()
	update_drag_hover_state()
	update_world_drag_preview()

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
	helmet_icon = TextureRect.new()
	helmet_icon.texture = create_helmet_texture()
	helmet_icon.size = Vector2(32, 32)
	helmet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	helmet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(helmet_icon)

func ensure_ghost_icon():
	if ghost_icon != null:
		return
	ghost_layer = CanvasLayer.new()
	ghost_layer.layer = 1000
	get_viewport().add_child(ghost_layer)
	ghost_icon = TextureRect.new()
	ghost_icon.texture = create_helmet_texture()
	ghost_icon.size = Vector2(32, 32)
	ghost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_icon.visible = false
	ghost_layer.add_child(ghost_icon)

func create_helmet_texture() -> Texture2D:
	var helmet_script = load("res://scripts/helmet_item.gd")
	if helmet_script:
		var helmet_instance = helmet_script.new()
		if helmet_instance and helmet_instance.has_method("get_shared_texture"):
			return helmet_instance.get_shared_texture()
	return null

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
	update_drag_hover_state()

func move_icon(mouse_pos: Vector2):
	helmet_icon.global_position = mouse_pos + drag_offset
	update_drag_hover_state()

func finish_drag(mouse_pos: Vector2):
	is_dragging = false
	helmet_icon.z_index = 0
	clear_slot_highlight()
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

func update_drag_hover_state():
	if not is_dragging:
		return
	var icon_rect = helmet_icon.get_global_rect()
	var menu_rect = get_global_rect()
	if icon_rect.intersects(menu_rect):
		helmet_icon.z_index = 100
	else:
		helmet_icon.z_index = 0
	var head_rect = head_slot.get_global_rect()
	if icon_rect.intersects(head_rect):
		apply_slot_highlight()
	else:
		clear_slot_highlight()

func update_world_drag_preview():
	if is_dragging:
		if ghost_icon:
			ghost_icon.visible = false
		return
	var drag_item = DRAGGABLE_SCRIPT.current_drag_item if DRAGGABLE_SCRIPT else null
	if drag_item == null:
		if ghost_icon:
			ghost_icon.visible = false
		return
	var item_script = drag_item.get_script()
	if item_script == null or item_script.resource_path != "res://scripts/helmet_item.gd":
		if ghost_icon:
			ghost_icon.visible = false
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var canvas_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
	var menu_rect = get_global_rect()
	if menu_rect.has_point(canvas_pos):
		if ghost_icon:
			ghost_icon.visible = true
			ghost_icon.global_position = canvas_pos - ghost_icon.size / 2.0
		apply_slot_highlight()
	else:
		if ghost_icon:
			ghost_icon.visible = false
		clear_slot_highlight()

func apply_slot_highlight():
	if head_slot_highlight:
		head_slot.add_theme_stylebox_override("panel", head_slot_highlight)

func clear_slot_highlight():
	if head_slot_style:
		head_slot.add_theme_stylebox_override("panel", head_slot_style)

func create_highlight_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.18, 0.12, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.75, 0.45, 1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 3
	return style

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
