extends "res://scripts/draggable_item.gd"

# Visual representation of a dead orc with container functionality

var container_window: Control = null
var container_slots: Array = []
var container_items: Array = []
var is_container_open = false

func _ready():
	super._ready()
	# Match base draggable pickup area
	pick_rect_size = Vector2(32, 32)
	pick_rect_offset = -pick_rect_size / 2.0
	# Initialize 8-slot container
	for i in range(8):
		container_items.append(null)
	# Dead bodies don't need to be draggable
	requires_adjacent = true
	set_process(true)
	queue_redraw()

func _process(_delta):
	if container_window and container_window.visible:
		if not is_player_adjacent():
			container_window.visible = false
			is_container_open = false

func _input(event):
	# Handle right-click to open container BEFORE parent drag handling
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		if get_pick_rect().has_point(mouse_pos):
			if is_player_adjacent():
				toggle_container()
			else:
				move_player_to_body_and_open()
			get_viewport().set_input_as_handled()
			return
	
	# Let parent handle dragging
	super._input(event)

func toggle_container():
	if container_window == null:
		create_container_window()
	container_window.visible = !container_window.visible
	if container_window.visible:
		position_container_window()
	is_container_open = container_window.visible

var pending_open := false

func move_player_to_body_and_open():
	var player = get_player_node()
	if player == null:
		return
	if player.has_method("move_to_position"):
		var adjacent_target = get_best_adjacent_tile_center(player)
		if adjacent_target != Vector2.ZERO:
			player.move_to_position(adjacent_target)
		else:
			player.move_to_position(global_position)
	if pending_open:
		return
	pending_open = true
	await wait_for_adjacent_and_open()
	pending_open = false

func wait_for_adjacent_and_open():
	while is_instance_valid(self):
		if is_player_adjacent():
			toggle_container()
			return
		await get_tree().process_frame

func is_player_adjacent() -> bool:
	var player = get_player_node()
	if player == null:
		return false
	var player_feet_pos = player.global_position + Vector2(0, TILE_SIZE / 2)
	var player_tile = get_tile_coords(player_feet_pos)
	var item_tile = get_tile_coords(global_position)
	var dx = abs(player_tile.x - item_tile.x)
	var dy = abs(player_tile.y - item_tile.y)
	return (dx <= 1 and dy <= 1) and not (dx == 0 and dy == 0)

func get_best_adjacent_tile_center(player: Node) -> Vector2:
	var world = get_world_node()
	var base_tile = get_tile_coords(global_position)
	var best_center := Vector2.ZERO
	var best_dist := INF
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var tile = Vector2i(base_tile.x + ox, base_tile.y + oy)
			var center = Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2, tile.y * TILE_SIZE + TILE_SIZE / 2)
			if world and world.has_method("is_walkable"):
				if not world.is_walkable(center):
					continue
			if player.has_method("is_position_occupied"):
				if player.is_position_occupied(center):
					continue
			var dist = player.global_position.distance_to(center)
			if dist < best_dist:
				best_dist = dist
				best_center = center
	return best_center

func create_container_window():
	var root = get_tree().root
	var equip_menu = root.find_child("EquipmentMenu", true, false)
	if equip_menu == null:
		return
	
	container_window = PanelContainer.new()
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
	container_window.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	container_window.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	# Title bar with close button
	var title_bar = HBoxContainer.new()
	title_bar.set_meta("is_title_bar", true)
	title_bar.set_meta("body_ref", self)
	vbox.add_child(title_bar)
	
	var title = Label.new()
	title.text = "Dead Orc"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.9, 0.85, 0.75, 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(20, 20)
	close_button.modulate = Color(0.9, 0.85, 0.75, 1)
	close_button.pressed.connect(func(): container_window.visible = false)
	title_bar.add_child(close_button)
	
	# Grid for items
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)
	
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
	
	# Create 8 slots
	for i in range(8):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(32, 32)
		slot.add_theme_stylebox_override("panel", slot_style)
		grid.add_child(slot)
		container_slots.append(slot)
	
	var ui_parent: Node = equip_menu
	if equip_menu.get_parent() is CanvasLayer:
		ui_parent = equip_menu.get_parent()
	ui_parent.add_child(container_window)
	container_window.visible = false
	position_container_window()
	container_window.custom_minimum_size = Vector2(160, 120)
	container_window.set_meta("is_body_container", true)
	container_window.set_meta("body_ref", self)

func position_container_window():
	if container_window == null:
		return
	var viewport = get_viewport()
	if viewport == null:
		return
	var canvas_transform = viewport.get_canvas_transform()
	var screen_pos = canvas_transform * global_position
	# Center the window above the body
	var offset = Vector2(-container_window.custom_minimum_size.x / 2.0, -container_window.custom_minimum_size.y - 16)
	container_window.position = screen_pos + offset

func get_slot_index_at_screen_pos(screen_pos: Vector2) -> int:
	for i in range(container_slots.size()):
		var slot = container_slots[i]
		var rect = Rect2(slot.global_position, slot.size)
		if rect.has_point(screen_pos):
			return i
	return -1

func add_item_to_slot(item_type: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= container_items.size():
		return false
	if container_items[slot_index] != null:
		return false
	container_items[slot_index] = item_type
	update_container_slot_visual(slot_index)
	return true

func add_item_to_first_empty(item_type: String) -> bool:
	for i in range(container_items.size()):
		if container_items[i] == null:
			container_items[i] = item_type
			update_container_slot_visual(i)
			return true
	return false

func get_item_at_slot(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= container_items.size():
		return ""
	return container_items[slot_index] if container_items[slot_index] != null else ""

func get_slot_rect(slot_index: int) -> Rect2:
	if slot_index < 0 or slot_index >= container_slots.size():
		return Rect2()
	var slot = container_slots[slot_index]
	return Rect2(slot.global_position, slot.size)

func remove_item_from_slot(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= container_items.size():
		return ""
	var item_type = container_items[slot_index]
	if item_type == null:
		return ""
	container_items[slot_index] = null
	update_container_slot_visual(slot_index)
	return item_type

func update_container_slot_visual(slot_index: int):
	if slot_index < 0 or slot_index >= container_slots.size():
		return
	var slot = container_slots[slot_index]
	for child in slot.get_children():
		child.queue_free()
	var item_type = container_items[slot_index]
	if item_type == "helmet":
		var icon = TextureRect.new()
		icon.texture = get_helmet_texture()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.anchor_left = 0
		icon.anchor_top = 0
		icon.anchor_right = 1
		icon.anchor_bottom = 1
	elif item_type == "club":
		var icon = TextureRect.new()
		icon.texture = get_club_texture()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.anchor_left = 0
		icon.anchor_top = 0
		icon.anchor_right = 1
		icon.anchor_bottom = 1
	elif item_type == "armor":
		var icon = TextureRect.new()
		icon.texture = get_armor_texture()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.anchor_left = 0
		icon.anchor_top = 0
		icon.anchor_right = 1
		icon.anchor_bottom = 1
	elif item_type == "pants":
		var icon = TextureRect.new()
		icon.texture = get_pants_texture()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.anchor_left = 0
		icon.anchor_top = 0
		icon.anchor_right = 1
		icon.anchor_bottom = 1

func get_helmet_texture() -> Texture2D:
	var helmet_script = load("res://scripts/helmet_item.gd")
	if helmet_script:
		var helmet_instance = helmet_script.new()
		if helmet_instance and helmet_instance.has_method("get_shared_texture"):
			return helmet_instance.get_shared_texture()
	return null

func get_club_texture() -> Texture2D:
	var club_script = load("res://scripts/club_item.gd")
	if club_script:
		var club_instance = club_script.new()
		if club_instance and club_instance.has_method("get_shared_texture"):
			return club_instance.get_shared_texture()
	return null

func get_armor_texture() -> Texture2D:
	var armor_script = load("res://scripts/cloth_armor_item.gd")
	if armor_script:
		var armor_instance = armor_script.new()
		if armor_instance and armor_instance.has_method("get_shared_texture"):
			return armor_instance.get_shared_texture()
	return null

func get_pants_texture() -> Texture2D:
	var pants_script = load("res://scripts/cloth_pants_item.gd")
	if pants_script:
		var pants_instance = pants_script.new()
		if pants_instance and pants_instance.has_method("get_shared_texture"):
			return pants_instance.get_shared_texture()
	return null

func _exit_tree():
	if container_window and is_instance_valid(container_window):
		container_window.queue_free()
		container_window = null

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


