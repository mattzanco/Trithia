extends Control

const TILE_SIZE = 32

@export var helmet_color := Color(0.7, 0.7, 0.75)
@export var bag_color := Color(0.6, 0.4, 0.2)

const DRAGGABLE_SCRIPT = preload("res://scripts/draggable_item.gd")

var player = null
var head_slot: Control
var backpack_slot: Control
var helmet_icon: TextureRect
var bag_icon: TextureRect
var ghost_icon: TextureRect
var ghost_layer: CanvasLayer
var bag_container: Control
var bag_slots: Array = []
var bag_items: Array = []  # Track items in each bag slot

var is_dragging = false
var is_dragging_bag_icon = false
var drag_offset = Vector2.ZERO
var helmet_world_item = null
var backpack_world_item = null
var head_slot_style: StyleBox
var head_slot_highlight: StyleBox

var dragging_window = false
var dragging_bag_window = false
var resizing_bag_window = false
var dragging_body_window: Control = null
var resizing_body_window: Control = null
var window_drag_offset = Vector2.ZERO
var equipment_title: Label
var bag_title: Label
var bag_title_bar: HBoxContainer
var bag_grid: GridContainer

func _ready():
	player = get_player_node()
	head_slot = $Panel/Margin/Center/VBox/SlotGrid/HeadSlot
	backpack_slot = $Panel/Margin/Center/VBox/SlotGrid/BackpackSlot
	equipment_title = $Panel/Margin/Center/VBox/Title
	head_slot_style = head_slot.get_theme_stylebox("panel")
	head_slot_highlight = create_highlight_style()
	ensure_helmet_icon()
	ensure_bag_icon()
	ensure_ghost_icon()
	create_bag_container()
	set_process_input(true)
	set_process(true)
	update_helmet_visual()
	update_bag_visual()

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
	update_bag_visual()
	if ghost_icon == null:
		ensure_ghost_icon()
	update_drag_hover_state()
	update_world_drag_preview()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.shift_pressed:
				if (is_mouse_on_helmet_icon() or is_mouse_on_head_slot()) and is_helmet_equipped():
					DRAGGABLE_SCRIPT.show_center_text(get_helmet_description(), self)
					get_viewport().set_input_as_handled()
					return
				elif is_mouse_on_bag_icon() or is_mouse_on_backpack_slot():
					DRAGGABLE_SCRIPT.show_center_text(get_backpack_description(), self)
					get_viewport().set_input_as_handled()
					return
				else:
					var bag_slot_index = get_bag_slot_at_mouse()
					if bag_slot_index >= 0 and bag_items[bag_slot_index] == "helmet":
						DRAGGABLE_SCRIPT.show_center_text(get_helmet_description(), self)
						get_viewport().set_input_as_handled()
						return
			# Check for dead body window resize handle
			var body_resize = get_body_container_at_resize_handle()
			if body_resize:
				resizing_body_window = body_resize
				window_drag_offset = body_resize.size - event.global_position
				get_viewport().set_input_as_handled()
			# Check for dead body window title dragging
			elif is_mouse_on_body_title():
				var body_title = get_body_container_at_title()
				if body_title:
					dragging_body_window = body_title
					window_drag_offset = body_title.position - event.global_position
					get_viewport().set_input_as_handled()
			# Check for bag resize handle
			elif is_mouse_on_bag_resize_handle():
				resizing_bag_window = true
				window_drag_offset = bag_container.size - event.global_position
				get_viewport().set_input_as_handled()
			# Check for bag window dragging
			elif is_mouse_on_bag_title():
				dragging_bag_window = true
				window_drag_offset = bag_container.position - event.global_position
				get_viewport().set_input_as_handled()
			# Check for helmet icon dragging
			elif is_mouse_on_helmet_icon() or is_mouse_on_head_slot():
				if is_helmet_equipped():
					start_drag(event.global_position)
					get_viewport().set_input_as_handled()
			# Check for bag icon dragging
			elif is_mouse_on_bag_icon() or is_mouse_on_backpack_slot():
				start_bag_icon_drag(event.global_position)
				get_viewport().set_input_as_handled()
			else:
				var bag_slot_index = get_bag_slot_at_mouse()
				if bag_slot_index >= 0 and bag_items[bag_slot_index] == "helmet":
					start_bag_drag(bag_slot_index, event.global_position)
					get_viewport().set_input_as_handled()
		else:
			if resizing_body_window:
				resizing_body_window = null
				get_viewport().set_input_as_handled()
			elif dragging_body_window:
				dragging_body_window = null
				get_viewport().set_input_as_handled()
			elif resizing_bag_window:
				resizing_bag_window = false
				get_viewport().set_input_as_handled()
			elif dragging_bag_window:
				dragging_bag_window = false
				get_viewport().set_input_as_handled()
			elif is_dragging_bag_icon:
				finish_bag_icon_drag(event.global_position)
				get_viewport().set_input_as_handled()
			elif is_dragging:
				finish_drag(event.global_position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_mouse_on_bag_icon() or is_mouse_on_backpack_slot():
			if not is_dragging_bag_icon:
				toggle_bag_container()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if resizing_body_window:
			var new_size = event.global_position + window_drag_offset
			new_size.x = max(160, new_size.x)
			new_size.y = max(120, new_size.y)
			resizing_body_window.custom_minimum_size = new_size
			resizing_body_window.size = new_size
			get_viewport().set_input_as_handled()
		elif dragging_body_window:
			dragging_body_window.position = event.global_position + window_drag_offset
			get_viewport().set_input_as_handled()
		elif resizing_bag_window:
			var new_size = event.global_position + window_drag_offset
			new_size.x = max(180, new_size.x)
			new_size.y = max(180, new_size.y)
			bag_container.custom_minimum_size = new_size
			bag_container.size = new_size
			if bag_grid:
				bag_grid.custom_minimum_size = Vector2(new_size.x - 32, new_size.y - 80)
			get_viewport().set_input_as_handled()
		elif dragging_bag_window:
			bag_container.position = event.global_position + window_drag_offset
			get_viewport().set_input_as_handled()
		elif is_dragging_bag_icon:
			bag_icon.global_position = event.global_position + drag_offset
			get_viewport().set_input_as_handled()
		elif is_dragging:
			move_icon(event.global_position)
			get_viewport().set_input_as_handled()

func unequip_helmet():
	set_helmet_equipped(false)
	# Try to put helmet in bag first
	if not add_helmet_to_bag():
		# If bag is full, drop to ground
		var mouse_pos = get_global_mouse_position()
		spawn_helmet_in_world_at(mouse_pos)

func add_helmet_to_bag() -> bool:
	# Find first empty slot
	for i in range(bag_items.size()):
		if bag_items[i] == null:
			bag_items[i] = "helmet"
			update_bag_slot_visual(i)
			return true
	return false

func update_bag_slot_visual(slot_index: int):
	if slot_index < 0 or slot_index >= bag_slots.size():
		return
	
	var slot = bag_slots[slot_index]
	# Remove old icon if exists
	for child in slot.get_children():
		child.queue_free()
	
	# Add icon if slot has item
	if slot_index < bag_items.size() and bag_items[slot_index] == "helmet":
		var icon = TextureRect.new()
		icon.texture = create_helmet_texture()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.anchor_left = 0
		icon.anchor_top = 0
		icon.anchor_right = 1
		icon.anchor_bottom = 1

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
	get_viewport().add_child.call_deferred(ghost_layer)
	ghost_icon = TextureRect.new()
	ghost_icon.texture = create_helmet_texture()
	ghost_icon.size = Vector2(32, 32)
	ghost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_icon.visible = false
	ghost_layer.add_child.call_deferred(ghost_icon)

func create_helmet_texture() -> Texture2D:
	var helmet_script = load("res://scripts/helmet_item.gd")
	if helmet_script:
		var helmet_instance = helmet_script.new()
		if helmet_instance and helmet_instance.has_method("get_shared_texture"):
			return helmet_instance.get_shared_texture()
	return null

func get_helmet_description() -> String:
	return "Helmet\nProtects your head."

func get_backpack_description() -> String:
	return "Backpack\nStores items."

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
	
	# Check if dropping on head slot
	if is_point_in_rect(mouse_pos, get_head_slot_rect()):
		set_helmet_equipped(true)
		position_icon_in_slot()
	else:
		# Check if dropping on a bag slot
		var bag_slot_index = get_bag_slot_at_mouse()
		if bag_slot_index >= 0:
			set_helmet_equipped(false)
			if add_helmet_to_bag_slot(bag_slot_index):
				return  # Successfully added to bag
		
		# Otherwise drop to world
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
	var root = get_tree().get_root()
	return root.find_child("Player", true, false)

func get_world_node() -> Node:
	var root = get_tree().get_root()
	return root.find_child("World", true, false)

func spawn_helmet_in_world_at(screen_pos: Vector2):
	if helmet_world_item != null:
		if is_instance_valid(helmet_world_item) and not helmet_world_item.is_queued_for_deletion():
			var world_pos_existing = screen_to_world_position(get_viewport().get_mouse_position())
			helmet_world_item.position = snap_to_tile_center(world_pos_existing)
			return
		helmet_world_item = null
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
	var world_pos = screen_to_world_position(get_viewport().get_mouse_position())
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
	if camera:
		if camera.has_method("unproject_position"):
			return camera.unproject_position(screen_pos)
		if camera.has_method("screen_to_world"):
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
	var mouse_pos = get_global_mouse_position()
	
	# Check if dropping on a bag slot
	var bag_slot_index = get_bag_slot_at_mouse()
	if bag_slot_index >= 0:
		if add_helmet_to_bag_slot(bag_slot_index):
			if item:
				item.queue_free()
			return true
		return false
	
	# Check if dropping on head slot
	if not is_point_in_rect(mouse_pos, get_head_slot_rect()):
		return false
	set_helmet_equipped(true)
	if item:
		item.queue_free()
	return true

# Backpack icon dragging functions
func start_bag_icon_drag(mouse_pos: Vector2):
	is_dragging_bag_icon = true
	drag_offset = bag_icon.global_position - mouse_pos
	bag_icon.z_index = 100

func finish_bag_icon_drag(mouse_pos: Vector2):
	is_dragging_bag_icon = false
	bag_icon.z_index = 0
	
	# Check if dropped on backpack slot (re-equip)
	if is_point_in_rect(mouse_pos, get_backpack_slot_rect()):
		position_bag_icon_in_slot()
	else:
		# Drop backpack in world
		spawn_backpack_in_world_at(mouse_pos)

func spawn_backpack_in_world_at(screen_pos: Vector2):
	if backpack_world_item != null:
		return
	if player == null:
		player = get_player_node()
	if player == null:
		return
	var world = get_world_node()
	if world == null:
		return
	
	# Close the bag container when dropping
	if bag_container:
		bag_container.visible = false
	
	var backpack_item = Area2D.new()
	backpack_item_setup(backpack_item)
	var world_pos = screen_to_world_position(screen_pos)
	var snapped = snap_to_tile_center(world_pos)
	backpack_item.position = snapped
	backpack_item.z_index = 0
	world.add_child(backpack_item)
	backpack_world_item = backpack_item
	backpack_item.tree_exited.connect(func():
		if backpack_world_item == backpack_item:
			backpack_world_item = null
	)

func backpack_item_setup(backpack_item: Area2D):
	var backpack_script = load("res://scripts/backpack_item.gd")
	backpack_item.set_script(backpack_script)

func remove_world_backpack():
	if backpack_world_item != null:
		backpack_world_item.queue_free()
		backpack_world_item = null

func equip_backpack_from_world(item: Node):
	if item:
		item.queue_free()
	position_bag_icon_in_slot()

func try_equip_backpack_from_world(item: Node) -> bool:
	var mouse_pos = get_global_mouse_position()
	
	# Check if dropping on backpack slot
	if not is_point_in_rect(mouse_pos, get_backpack_slot_rect()):
		return false
	
	if item:
		item.queue_free()
	position_bag_icon_in_slot()
	return true

func add_helmet_to_bag_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= bag_items.size():
		return false
	if bag_items[slot_index] != null:
		return false  # Slot occupied
	
	bag_items[slot_index] = "helmet"
	update_bag_slot_visual(slot_index)
	return true

# Bag functions
func ensure_bag_icon():
	if bag_icon != null:
		return
	bag_icon = TextureRect.new()
	bag_icon.texture = create_bag_texture()
	bag_icon.size = Vector2(32, 32)
	bag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bag_icon)

func create_bag_texture() -> Texture2D:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var bag_brown = bag_color
	var bag_dark = Color(0.4, 0.25, 0.15)
	var bag_light = Color(0.75, 0.5, 0.3)
	
	# Main bag body
	for y in range(8, 26):
		for x in range(6, 26):
			img.set_pixel(x, y, bag_brown)
	
	# Flap
	for y in range(6, 10):
		for x in range(8, 24):
			img.set_pixel(x, y, bag_dark)
	
	# Straps
	for y in range(10, 24):
		for x in range(6, 8):
			img.set_pixel(x, y, bag_dark)
		for x in range(24, 26):
			img.set_pixel(x, y, bag_dark)
	
	# Highlight
	for y in range(12, 16):
		for x in range(10, 14):
			img.set_pixel(x, y, bag_light)
	
	return ImageTexture.create_from_image(img)

func update_bag_visual():
	if bag_icon == null:
		return
	# Only show bag icon if backpack is not in the world
	bag_icon.visible = (backpack_world_item == null)
	if bag_icon.visible and not is_dragging_bag_icon:
		position_bag_icon_in_slot()

func position_bag_icon_in_slot():
	var slot_rect = get_backpack_slot_rect()
	var icon_pos = slot_rect.position + (slot_rect.size - bag_icon.size) / 2.0
	bag_icon.global_position = icon_pos

func get_backpack_slot_rect() -> Rect2:
	return Rect2(backpack_slot.global_position, backpack_slot.size)

func is_mouse_on_backpack_slot() -> bool:
	return is_point_in_rect(get_global_mouse_position(), get_backpack_slot_rect())

func is_mouse_on_bag_icon() -> bool:
	if bag_icon == null or not bag_icon.visible:
		return false
	var rect = Rect2(bag_icon.global_position, bag_icon.size)
	return rect.has_point(get_global_mouse_position())

func create_bag_container():
	bag_container = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.35, 0.3, 0.25, 1)
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 6
	bag_container.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bag_container.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	# Title bar with close button
	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)
	bag_title_bar = title_bar  # Store reference for dragging
	
	var title = Label.new()
	title.text = "Backpack"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.9, 0.85, 0.75, 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	bag_title = title  # Store reference
	
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(20, 20)
	close_button.modulate = Color(0.9, 0.85, 0.75, 1)
	close_button.pressed.connect(func(): bag_container.visible = false)
	title_bar.add_child(close_button)
	
	# Grid for items (no scroll bar)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.custom_minimum_size = Vector2(160, 150)
	vbox.add_child(grid)
	bag_grid = grid
	
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.14, 0.12, 0.1, 1)
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.5, 0.4, 0.3, 1)
	slot_style.corner_radius_top_left = 3
	slot_style.corner_radius_top_right = 3
	slot_style.corner_radius_bottom_right = 3
	slot_style.corner_radius_bottom_left = 3
	
	# Create 20 slots
	for i in range(20):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(32, 32)
		slot.add_theme_stylebox_override("panel", slot_style)
		grid.add_child(slot)
		bag_slots.append(slot)
		bag_items.append(null)  # Initialize empty slots
	
	add_child(bag_container)
	bag_container.visible = false
	bag_container.position = Vector2(0, 200)
	bag_container.custom_minimum_size = Vector2(180, 180)

func toggle_bag_container():
	if bag_container:
		bag_container.visible = not bag_container.visible

func is_mouse_on_equipment_title() -> bool:
	if equipment_title == null:
		return false
	var rect = Rect2(equipment_title.global_position, equipment_title.size)
	return rect.has_point(get_global_mouse_position())

func is_mouse_on_bag_title() -> bool:
	if bag_title_bar == null or not bag_container.visible:
		return false
	var rect = Rect2(bag_title_bar.global_position, bag_title_bar.size)
	var mouse_pos = get_global_mouse_position()
	# Exclude the close button area (rightmost 20 pixels)
	if rect.has_point(mouse_pos):
		var relative_x = mouse_pos.x - rect.position.x
		if relative_x < rect.size.x - 25:  # Leave some margin for close button
			return true
	return false

func is_mouse_on_bag_resize_handle() -> bool:
	if bag_container == null or not bag_container.visible:
		return false
	var resize_area = Rect2(
		bag_container.global_position + bag_container.size - Vector2(20, 20),
		Vector2(20, 20)
	)
	return resize_area.has_point(get_global_mouse_position())

func is_mouse_on_body_title() -> bool:
	var mouse_pos = get_global_mouse_position()
	for child in get_body_container_parents():
		if child.has_meta("is_body_container") and child.visible:
			var title_bar = child.find_child("*", true, false)
			if title_bar and title_bar.has_meta("is_title_bar"):
				var rect = Rect2(title_bar.global_position, title_bar.size)
				if rect.has_point(mouse_pos):
					var relative_x = mouse_pos.x - rect.position.x
					if relative_x < rect.size.x - 25:
						return true
	return false

func get_body_container_at_title() -> Control:
	var mouse_pos = get_global_mouse_position()
	for child in get_body_container_parents():
		if child.has_meta("is_body_container") and child.visible:
			var title_bar = child.find_child("*", true, false)
			if title_bar and title_bar.has_meta("is_title_bar"):
				var rect = Rect2(title_bar.global_position, title_bar.size)
				if rect.has_point(mouse_pos):
					var relative_x = mouse_pos.x - rect.position.x
					if relative_x < rect.size.x - 25:
						return child
	return null

func get_body_container_at_resize_handle() -> Control:
	var mouse_pos = get_global_mouse_position()
	for child in get_body_container_parents():
		if child.has_meta("is_body_container") and child.visible:
			var resize_area = Rect2(
				child.global_position + child.size - Vector2(20, 20),
				Vector2(20, 20)
			)
			if resize_area.has_point(mouse_pos):
				return child
	return null

func get_body_container_parents() -> Array:
	var parent = get_parent()
	if parent is CanvasLayer:
		return parent.get_children()
	return get_children()

func get_bag_slot_at_mouse() -> int:
	var mouse_pos = get_global_mouse_position()
	for i in range(bag_slots.size()):
		var slot = bag_slots[i]
		var rect = Rect2(slot.global_position, slot.size)
		if rect.has_point(mouse_pos):
			return i
	return -1

func equip_helmet_from_bag(slot_index: int):
	if slot_index < 0 or slot_index >= bag_items.size():
		return
	if bag_items[slot_index] != "helmet":
		return
	
	# Remove from bag
	bag_items[slot_index] = null
	update_bag_slot_visual(slot_index)
	
	# Equip
	set_helmet_equipped(true)

func start_bag_drag(slot_index: int, mouse_pos: Vector2):
	if slot_index < 0 or slot_index >= bag_items.size():
		return
	if bag_items[slot_index] != "helmet":
		return
	
	# Remove from bag
	bag_items[slot_index] = null
	update_bag_slot_visual(slot_index)
	
	# Equip and start dragging
	set_helmet_equipped(true)
	# Position icon at mouse before starting drag to avoid snap
	helmet_icon.global_position = mouse_pos
	is_dragging = true
	drag_offset = Vector2.ZERO
	update_drag_hover_state()
