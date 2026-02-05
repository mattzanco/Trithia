extends Control

const TILE_SIZE = 32

@export var helmet_color := Color(0.7, 0.7, 0.75)
@export var bag_color := Color(0.6, 0.4, 0.2)

const DRAGGABLE_SCRIPT = preload("res://scripts/draggable_item.gd")

var player = null
var head_slot: Control
var backpack_slot: Control
var weapon_slot: Control
var shield_slot: Control
var armor_slot: Control
var legs_slot: Control
var helmet_icon: TextureRect
var club_icon: TextureRect
var armor_icon: TextureRect
var pants_icon: TextureRect
var bag_icon: TextureRect
var ghost_icon: TextureRect
var ghost_layer: CanvasLayer
var bag_container: Control
var bag_slots: Array = []
var bag_items: Array = []  # Track items in each bag slot

var is_dragging = false
var is_dragging_club = false
var is_dragging_armor = false
var is_dragging_pants = false
var is_dragging_bag_icon = false
var drag_offset = Vector2.ZERO
var club_drag_offset = Vector2.ZERO
var armor_drag_offset = Vector2.ZERO
var pants_drag_offset = Vector2.ZERO
var helmet_world_item = null
var club_world_item = null
var armor_world_item = null
var pants_world_item = null
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
var club_equipped_slot: String = ""
var armor_equipped = false
var pants_equipped = false

@export var start_with_club = true
@export var start_with_armor = true
@export var start_with_pants = true

func _ready():
	player = get_player_node()
	head_slot = $Panel/Margin/Center/VBox/SlotGrid/HeadSlot
	backpack_slot = $Panel/Margin/Center/VBox/SlotGrid/BackpackSlot
	weapon_slot = $Panel/Margin/Center/VBox/SlotGrid/WeaponSlot
	shield_slot = $Panel/Margin/Center/VBox/SlotGrid/ShieldSlot
	armor_slot = $Panel/Margin/Center/VBox/SlotGrid/ArmorSlot
	legs_slot = $Panel/Margin/Center/VBox/SlotGrid/LegsSlot
	equipment_title = $Panel/Margin/Center/VBox/Title
	head_slot_style = head_slot.get_theme_stylebox("panel")
	head_slot_highlight = create_highlight_style()
	ensure_helmet_icon()
	ensure_club_icon()
	ensure_armor_icon()
	ensure_pants_icon()
	ensure_bag_icon()
	ensure_ghost_icon()
	create_bag_container()
	set_process_input(true)
	set_process(true)
	update_helmet_visual()
	update_club_visual()
	update_armor_visual()
	update_pants_visual()
	update_bag_visual()
	if start_with_club and club_equipped_slot == "":
		set_club_equipped("weapon")
	if start_with_armor and not armor_equipped:
		set_armor_equipped(true)
	if start_with_pants and not pants_equipped:
		set_pants_equipped(true)

func _exit_tree():
	if helmet_world_item and is_instance_valid(helmet_world_item):
		helmet_world_item.queue_free()
		helmet_world_item = null
	if club_world_item and is_instance_valid(club_world_item):
		club_world_item.queue_free()
		club_world_item = null
	if armor_world_item and is_instance_valid(armor_world_item):
		armor_world_item.queue_free()
		armor_world_item = null
	if pants_world_item and is_instance_valid(pants_world_item):
		pants_world_item.queue_free()
		pants_world_item = null
	if backpack_world_item and is_instance_valid(backpack_world_item):
		backpack_world_item.queue_free()
		backpack_world_item = null
	if ghost_layer and is_instance_valid(ghost_layer):
		ghost_layer.queue_free()
		ghost_layer = null
		ghost_icon = null
	if helmet_icon and is_instance_valid(helmet_icon):
		helmet_icon.queue_free()
		helmet_icon = null
	if club_icon and is_instance_valid(club_icon):
		club_icon.queue_free()
		club_icon = null
	if armor_icon and is_instance_valid(armor_icon):
		armor_icon.queue_free()
		armor_icon = null
	if pants_icon and is_instance_valid(pants_icon):
		pants_icon.queue_free()
		pants_icon = null
	if bag_icon and is_instance_valid(bag_icon):
		bag_icon.queue_free()
		bag_icon = null
	if bag_container and is_instance_valid(bag_container):
		bag_container.queue_free()
		bag_container = null

func _process(_delta):
	# Keep UI in sync when not dragging
	if not is_dragging:
		update_helmet_visual()
	if not is_dragging_club:
		update_club_visual()
	if not is_dragging_armor:
		update_armor_visual()
	if not is_dragging_pants:
		update_pants_visual()
	update_bag_visual()
	close_bag_if_not_adjacent()
	if ghost_icon == null:
		ensure_ghost_icon()
	update_drag_hover_state()
	update_world_drag_preview()

func close_bag_if_not_adjacent():
	if bag_container == null or not bag_container.visible:
		return
	if backpack_world_item == null or not is_instance_valid(backpack_world_item):
		return
	if player == null:
		player = get_player_node()
	if player == null:
		return
	var player_feet_pos = player.global_position + Vector2(0, TILE_SIZE / 2)
	var player_tile = get_tile_coords(player_feet_pos)
	var bag_tile = get_tile_coords(backpack_world_item.global_position)
	var dx = abs(player_tile.x - bag_tile.x)
	var dy = abs(player_tile.y - bag_tile.y)
	if dx > 1 or dy > 1:
		bag_container.visible = false

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.shift_pressed:
				if (is_mouse_on_helmet_icon() or is_mouse_on_head_slot()) and is_helmet_equipped():
					DRAGGABLE_SCRIPT.show_center_text(get_helmet_description(), self)
					get_viewport().set_input_as_handled()
					return
				elif (is_mouse_on_club_icon() or is_mouse_on_weapon_slot() or is_mouse_on_shield_slot()) and is_club_equipped():
					DRAGGABLE_SCRIPT.show_center_text(get_club_description(), self)
					get_viewport().set_input_as_handled()
					return
				elif (is_mouse_on_armor_icon() or is_mouse_on_armor_slot()) and is_armor_equipped():
					DRAGGABLE_SCRIPT.show_center_text(get_armor_description(), self)
					get_viewport().set_input_as_handled()
					return
				elif (is_mouse_on_pants_icon() or is_mouse_on_legs_slot()) and is_pants_equipped():
					DRAGGABLE_SCRIPT.show_center_text(get_pants_description(), self)
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
					elif bag_slot_index >= 0 and bag_items[bag_slot_index] == "club":
						DRAGGABLE_SCRIPT.show_center_text(get_club_description(), self)
						get_viewport().set_input_as_handled()
						return
					elif bag_slot_index >= 0 and bag_items[bag_slot_index] == "armor":
						DRAGGABLE_SCRIPT.show_center_text(get_armor_description(), self)
						get_viewport().set_input_as_handled()
						return
					elif bag_slot_index >= 0 and bag_items[bag_slot_index] == "pants":
						DRAGGABLE_SCRIPT.show_center_text(get_pants_description(), self)
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
			# Check for club icon dragging
			elif is_mouse_on_club_icon() or is_mouse_on_weapon_slot() or is_mouse_on_shield_slot():
				if is_club_equipped():
					start_club_drag(event.global_position)
					get_viewport().set_input_as_handled()
			# Check for armor icon dragging
			elif is_mouse_on_armor_icon() or is_mouse_on_armor_slot():
				if is_armor_equipped():
					start_armor_drag(event.global_position)
					get_viewport().set_input_as_handled()
			# Check for pants icon dragging
			elif is_mouse_on_pants_icon() or is_mouse_on_legs_slot():
				if is_pants_equipped():
					start_pants_drag(event.global_position)
					get_viewport().set_input_as_handled()
			# Check for bag icon dragging
			elif is_mouse_on_bag_icon() or is_mouse_on_backpack_slot():
				start_bag_icon_drag(event.global_position)
				get_viewport().set_input_as_handled()
			else:
				# Check for dragging from dead body container
				var body_item = get_body_container_item_at_mouse()
				if body_item:
					start_body_item_drag(body_item, event.global_position)
					get_viewport().set_input_as_handled()
					return
				var bag_slot_index = get_bag_slot_at_mouse()
				if bag_slot_index >= 0 and bag_items[bag_slot_index] != null:
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
			elif is_dragging_club:
				finish_club_drag(event.global_position)
				get_viewport().set_input_as_handled()
			elif is_dragging_armor:
				finish_armor_drag(event.global_position)
				get_viewport().set_input_as_handled()
			elif is_dragging_pants:
				finish_pants_drag(event.global_position)
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
		elif is_dragging_club:
			move_club_icon(event.global_position)
			get_viewport().set_input_as_handled()
		elif is_dragging_armor:
			move_armor_icon(event.global_position)
			get_viewport().set_input_as_handled()
		elif is_dragging_pants:
			move_pants_icon(event.global_position)
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
	elif slot_index < bag_items.size() and bag_items[slot_index] == "club":
		var icon = TextureRect.new()
		icon.texture = create_club_texture()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.anchor_left = 0
		icon.anchor_top = 0
		icon.anchor_right = 1
		icon.anchor_bottom = 1
	elif slot_index < bag_items.size() and bag_items[slot_index] == "armor":
		var icon = TextureRect.new()
		icon.texture = create_armor_texture()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		icon.anchor_left = 0
		icon.anchor_top = 0
		icon.anchor_right = 1
		icon.anchor_bottom = 1
	elif slot_index < bag_items.size() and bag_items[slot_index] == "pants":
		var icon = TextureRect.new()
		icon.texture = create_pants_texture()
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

func ensure_club_icon():
	if club_icon != null:
		return
	club_icon = TextureRect.new()
	club_icon.texture = create_club_texture()
	club_icon.size = Vector2(32, 32)
	club_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	club_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(club_icon)

func ensure_armor_icon():
	if armor_icon != null:
		return
	armor_icon = TextureRect.new()
	armor_icon.texture = create_armor_texture()
	armor_icon.size = Vector2(32, 32)
	armor_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	armor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(armor_icon)

func ensure_pants_icon():
	if pants_icon != null:
		return
	pants_icon = TextureRect.new()
	pants_icon.texture = create_pants_texture()
	pants_icon.size = Vector2(32, 32)
	pants_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pants_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pants_icon)

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

func create_club_texture() -> Texture2D:
	var club_script = load("res://scripts/club_item.gd")
	if club_script:
		var club_instance = club_script.new()
		if club_instance and club_instance.has_method("get_shared_texture"):
			return club_instance.get_shared_texture()
	return null

func create_armor_texture() -> Texture2D:
	var armor_script = load("res://scripts/cloth_armor_item.gd")
	if armor_script:
		var armor_instance = armor_script.new()
		if armor_instance and armor_instance.has_method("get_shared_texture"):
			return armor_instance.get_shared_texture()
	return null

func create_pants_texture() -> Texture2D:
	var pants_script = load("res://scripts/cloth_pants_item.gd")
	if pants_script:
		var pants_instance = pants_script.new()
		if pants_instance and pants_instance.has_method("get_shared_texture"):
			return pants_instance.get_shared_texture()
	return null

func get_helmet_description() -> String:
	return "Cloth Hat\nSimple headwear."

func get_backpack_description() -> String:
	return "Backpack\nStores items."

func get_club_description() -> String:
	return "Club\nA simple wooden weapon."

func get_armor_description() -> String:
	return "Cloth Armor\nSimple protective cloth."

func get_pants_description() -> String:
	return "Cloth Pants\nSimple cloth trousers."

func update_helmet_visual():
	if helmet_icon == null:
		return
	if is_helmet_equipped():
		helmet_icon.visible = true
		position_icon_in_slot()
	else:
		helmet_icon.visible = false

func update_club_visual():
	if club_icon == null:
		return
	if is_club_equipped():
		club_icon.visible = true
		position_club_in_slot()
	else:
		club_icon.visible = false

func update_armor_visual():
	if armor_icon == null:
		return
	if is_armor_equipped():
		armor_icon.visible = true
		position_armor_in_slot()
	else:
		armor_icon.visible = false

func update_pants_visual():
	if pants_icon == null:
		return
	if is_pants_equipped():
		pants_icon.visible = true
		position_pants_in_slot()
	else:
		pants_icon.visible = false

func position_icon_in_slot():
	var slot_rect = get_head_slot_rect()
	var icon_pos = slot_rect.position + (slot_rect.size - helmet_icon.size) / 2.0
	helmet_icon.global_position = icon_pos

func position_club_in_slot():
	var slot_rect = get_weapon_slot_rect() if club_equipped_slot == "weapon" else get_shield_slot_rect()
	var icon_pos = slot_rect.position + (slot_rect.size - club_icon.size) / 2.0
	club_icon.global_position = icon_pos

func position_armor_in_slot():
	var slot_rect = get_armor_slot_rect()
	var icon_pos = slot_rect.position + (slot_rect.size - armor_icon.size) / 2.0
	armor_icon.global_position = icon_pos

func position_pants_in_slot():
	var slot_rect = get_legs_slot_rect()
	var icon_pos = slot_rect.position + (slot_rect.size - pants_icon.size) / 2.0
	pants_icon.global_position = icon_pos

func start_drag(mouse_pos: Vector2):
	is_dragging = true
	drag_offset = helmet_icon.global_position - mouse_pos
	update_drag_hover_state()

func start_club_drag(mouse_pos: Vector2):
	is_dragging_club = true
	club_drag_offset = club_icon.global_position - mouse_pos

func start_armor_drag(mouse_pos: Vector2):
	is_dragging_armor = true
	armor_drag_offset = armor_icon.global_position - mouse_pos

func start_pants_drag(mouse_pos: Vector2):
	is_dragging_pants = true
	pants_drag_offset = pants_icon.global_position - mouse_pos

func move_club_icon(mouse_pos: Vector2):
	club_icon.global_position = mouse_pos + club_drag_offset

func move_armor_icon(mouse_pos: Vector2):
	armor_icon.global_position = mouse_pos + armor_drag_offset

func move_pants_icon(mouse_pos: Vector2):
	pants_icon.global_position = mouse_pos + pants_drag_offset

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
		# Check if dropping on dead body container slot
		var body_target = get_body_container_slot_target()
		if body_target:
			set_helmet_equipped(false)
			var body_ref = body_target["body"]
			var slot_index = body_target["index"]
			if body_ref and body_ref.has_method("add_item_to_slot"):
				if body_ref.add_item_to_slot("helmet", slot_index):
					return
		# Check if dropping on a bag slot
		var bag_slot_index = get_bag_slot_at_mouse()
		if bag_slot_index >= 0:
			set_helmet_equipped(false)
			if add_helmet_to_bag_slot(bag_slot_index):
				return  # Successfully added to bag
		
		# Otherwise drop to world
		set_helmet_equipped(false)
		spawn_helmet_in_world_at(mouse_pos)

func finish_club_drag(mouse_pos: Vector2):
	is_dragging_club = false
	# Check if dropping on weapon slot
	if is_point_in_rect(mouse_pos, get_weapon_slot_rect()):
		set_club_equipped("weapon")
		position_club_in_slot()
		return
	# Check if dropping on shield slot
	if is_point_in_rect(mouse_pos, get_shield_slot_rect()):
		set_club_equipped("shield")
		position_club_in_slot()
		return
	# Check if dropping on dead body container slot
	var body_target = get_body_container_slot_target()
	if body_target:
		var body_ref = body_target["body"]
		var slot_index = body_target["index"]
		if body_ref and body_ref.has_method("add_item_to_slot"):
			if body_ref.add_item_to_slot("club", slot_index):
				set_club_equipped("")
				club_icon.visible = false
				return
	# Check if dropping on a bag slot
	var bag_slot_index = get_bag_slot_at_mouse()
	if bag_slot_index >= 0:
		if add_item_to_bag_slot("club", bag_slot_index):
			set_club_equipped("")
			club_icon.visible = false
			return
	# Otherwise drop to world
	set_club_equipped("")
	spawn_club_in_world_at(mouse_pos)

func finish_armor_drag(mouse_pos: Vector2):
	is_dragging_armor = false
	# Check if dropping on armor slot
	if is_point_in_rect(mouse_pos, get_armor_slot_rect()):
		set_armor_equipped(true)
		position_armor_in_slot()
		return
	# Check if dropping on dead body container slot
	var body_target = get_body_container_slot_target()
	if body_target:
		var body_ref = body_target["body"]
		var slot_index = body_target["index"]
		if body_ref and body_ref.has_method("add_item_to_slot"):
			if body_ref.add_item_to_slot("armor", slot_index):
				set_armor_equipped(false)
				armor_icon.visible = false
				return
	# Check if dropping on a bag slot
	var bag_slot_index = get_bag_slot_at_mouse()
	if bag_slot_index >= 0:
		if add_item_to_bag_slot("armor", bag_slot_index):
			set_armor_equipped(false)
			armor_icon.visible = false
			return
	# Otherwise drop to world
	set_armor_equipped(false)
	spawn_armor_in_world_at(mouse_pos)

func finish_pants_drag(mouse_pos: Vector2):
	is_dragging_pants = false
	# Check if dropping on legs slot
	if is_point_in_rect(mouse_pos, get_legs_slot_rect()):
		set_pants_equipped(true)
		position_pants_in_slot()
		return
	# Check if dropping on dead body container slot
	var body_target = get_body_container_slot_target()
	if body_target:
		var body_ref = body_target["body"]
		var slot_index = body_target["index"]
		if body_ref and body_ref.has_method("add_item_to_slot"):
			if body_ref.add_item_to_slot("pants", slot_index):
				set_pants_equipped(false)
				pants_icon.visible = false
				return
	# Check if dropping on a bag slot
	var bag_slot_index = get_bag_slot_at_mouse()
	if bag_slot_index >= 0:
		if add_item_to_bag_slot("pants", bag_slot_index):
			set_pants_equipped(false)
			pants_icon.visible = false
			return
	# Otherwise drop to world
	set_pants_equipped(false)
	spawn_pants_in_world_at(mouse_pos)

func is_helmet_equipped() -> bool:
	return player != null and player.has_helmet

func is_club_equipped() -> bool:
	return club_equipped_slot != ""

func is_armor_equipped() -> bool:
	return armor_equipped

func is_pants_equipped() -> bool:
	return pants_equipped

func set_helmet_equipped(equipped: bool):
	if player and player.has_method("set_helmet_equipped"):
		player.set_helmet_equipped(equipped)
	if equipped:
		remove_world_helmet()
	update_helmet_visual()

func set_club_equipped(slot_name: String):
	club_equipped_slot = slot_name
	if slot_name != "":
		remove_world_club()
	update_club_visual()

func set_armor_equipped(equipped: bool):
	armor_equipped = equipped
	if equipped:
		remove_world_armor()
	update_armor_visual()

func set_pants_equipped(equipped: bool):
	pants_equipped = equipped
	if equipped:
		remove_world_pants()
	update_pants_visual()

func is_mouse_on_head_slot() -> bool:
	return is_point_in_rect(get_global_mouse_position(), get_head_slot_rect())

func is_mouse_on_helmet_icon() -> bool:
	if helmet_icon == null or not helmet_icon.visible:
		return false
	var rect = Rect2(helmet_icon.global_position, helmet_icon.size)
	return rect.has_point(get_global_mouse_position())

func is_mouse_on_club_icon() -> bool:
	if club_icon == null or not club_icon.visible:
		return false
	var rect = Rect2(club_icon.global_position, club_icon.size)
	return rect.has_point(get_global_mouse_position())

func is_mouse_on_armor_icon() -> bool:
	if armor_icon == null or not armor_icon.visible:
		return false
	var rect = Rect2(armor_icon.global_position, armor_icon.size)
	return rect.has_point(get_global_mouse_position())

func is_mouse_on_pants_icon() -> bool:
	if pants_icon == null or not pants_icon.visible:
		return false
	var rect = Rect2(pants_icon.global_position, pants_icon.size)
	return rect.has_point(get_global_mouse_position())

func get_head_slot_rect() -> Rect2:
	return Rect2(head_slot.global_position, head_slot.size)

func get_weapon_slot_rect() -> Rect2:
	return Rect2(weapon_slot.global_position, weapon_slot.size)

func get_shield_slot_rect() -> Rect2:
	return Rect2(shield_slot.global_position, shield_slot.size)

func get_armor_slot_rect() -> Rect2:
	return Rect2(armor_slot.global_position, armor_slot.size)

func get_legs_slot_rect() -> Rect2:
	return Rect2(legs_slot.global_position, legs_slot.size)

func is_mouse_on_weapon_slot() -> bool:
	return is_point_in_rect(get_global_mouse_position(), get_weapon_slot_rect())

func is_mouse_on_shield_slot() -> bool:
	return is_point_in_rect(get_global_mouse_position(), get_shield_slot_rect())

func is_mouse_on_armor_slot() -> bool:
	return is_point_in_rect(get_global_mouse_position(), get_armor_slot_rect())

func is_mouse_on_legs_slot() -> bool:
	return is_point_in_rect(get_global_mouse_position(), get_legs_slot_rect())

func is_point_in_rect(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)

func get_tile_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))

func update_drag_hover_state():
	if not is_dragging:
		return
	var icon_rect = helmet_icon.get_global_rect()
	# Keep helmet icon above other UI while dragging
	helmet_icon.z_index = 100
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
		clear_slot_highlight()
		return
	var item_script = drag_item.get_script()
	if item_script == null or item_script.resource_path != "res://scripts/helmet_item.gd":
		if ghost_icon:
			ghost_icon.visible = false
		clear_slot_highlight()
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
	return

func clear_slot_highlight():
	return

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

func spawn_club_in_world_at(screen_pos: Vector2):
	if club_world_item != null:
		if is_instance_valid(club_world_item) and not club_world_item.is_queued_for_deletion():
			var world_pos_existing = screen_to_world_position(get_viewport().get_mouse_position())
			club_world_item.position = snap_to_tile_center(world_pos_existing)
			return
		club_world_item = null
	if player == null:
		player = get_player_node()
	if player == null:
		return
	var world = get_world_node()
	if world == null:
		return
	var club_item = Area2D.new()
	club_item_setup(club_item)
	var world_pos = screen_to_world_position(get_viewport().get_mouse_position())
	var snapped = snap_to_tile_center(world_pos)
	club_item.position = snapped
	club_item.z_index = 0
	world.add_child(club_item)
	club_world_item = club_item
	club_item.tree_exited.connect(func():
		if club_world_item == club_item:
			club_world_item = null
	)

func spawn_armor_in_world_at(screen_pos: Vector2):
	if armor_world_item != null:
		if is_instance_valid(armor_world_item) and not armor_world_item.is_queued_for_deletion():
			var world_pos_existing = screen_to_world_position(get_viewport().get_mouse_position())
			armor_world_item.position = snap_to_tile_center(world_pos_existing)
			return
		armor_world_item = null
	if player == null:
		player = get_player_node()
	if player == null:
		return
	var world = get_world_node()
	if world == null:
		return
	var armor_item = Area2D.new()
	armor_item_setup(armor_item)
	var world_pos = screen_to_world_position(get_viewport().get_mouse_position())
	var snapped = snap_to_tile_center(world_pos)
	armor_item.position = snapped
	armor_item.z_index = 0
	world.add_child(armor_item)
	armor_world_item = armor_item
	armor_item.tree_exited.connect(func():
		if armor_world_item == armor_item:
			armor_world_item = null
	)

func spawn_pants_in_world_at(screen_pos: Vector2):
	if pants_world_item != null:
		if is_instance_valid(pants_world_item) and not pants_world_item.is_queued_for_deletion():
			var world_pos_existing = screen_to_world_position(get_viewport().get_mouse_position())
			pants_world_item.position = snap_to_tile_center(world_pos_existing)
			return
		pants_world_item = null
	if player == null:
		player = get_player_node()
	if player == null:
		return
	var world = get_world_node()
	if world == null:
		return
	var pants_item = Area2D.new()
	pants_item_setup(pants_item)
	var world_pos = screen_to_world_position(get_viewport().get_mouse_position())
	var snapped = snap_to_tile_center(world_pos)
	pants_item.position = snapped
	pants_item.z_index = 0
	world.add_child(pants_item)
	pants_world_item = pants_item
	pants_item.tree_exited.connect(func():
		if pants_world_item == pants_item:
			pants_world_item = null
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

func club_item_setup(club_item: Area2D):
	var club_script = load("res://scripts/club_item.gd")
	club_item.set_script(club_script)

func armor_item_setup(armor_item: Area2D):
	var armor_script = load("res://scripts/cloth_armor_item.gd")
	armor_item.set_script(armor_script)

func pants_item_setup(pants_item: Area2D):
	var pants_script = load("res://scripts/cloth_pants_item.gd")
	pants_item.set_script(pants_script)

func remove_world_helmet():
	if helmet_world_item != null:
		helmet_world_item.queue_free()
		helmet_world_item = null

func remove_world_club():
	if club_world_item != null:
		club_world_item.queue_free()
		club_world_item = null

func remove_world_armor():
	if armor_world_item != null:
		armor_world_item.queue_free()
		armor_world_item = null

func remove_world_pants():
	if pants_world_item != null:
		pants_world_item.queue_free()
		pants_world_item = null

func try_equip_helmet_from_world(item: Node) -> bool:
	var mouse_pos = get_global_mouse_position()
	
	# Check if dropping on dead body container slot
	var body_target = get_body_container_slot_target()
	if body_target:
		var body_ref = body_target["body"]
		var slot_index = body_target["index"]
		if body_ref and body_ref.has_method("add_item_to_slot"):
			if body_ref.add_item_to_slot("helmet", slot_index):
				if item:
					item.queue_free()
				return true
		return false
	
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

func try_equip_club_from_world(item: Node) -> bool:
	var mouse_pos = get_global_mouse_position()
	# Check if dropping on weapon slot
	if is_point_in_rect(mouse_pos, get_weapon_slot_rect()):
		set_club_equipped("weapon")
		if item:
			item.queue_free()
		return true
	# Check if dropping on shield slot
	if is_point_in_rect(mouse_pos, get_shield_slot_rect()):
		set_club_equipped("shield")
		if item:
			item.queue_free()
		return true
	# Check if dropping on bag slot
	var bag_slot_index = get_bag_slot_at_mouse()
	if bag_slot_index >= 0:
		if add_item_to_bag_slot("club", bag_slot_index):
			if item:
				item.queue_free()
			return true
		return false
	# Check if dropping on dead body container slot
	var body_target = get_body_container_slot_target()
	if body_target:
		var body_ref = body_target["body"]
		var slot_index = body_target["index"]
		if body_ref and body_ref.has_method("add_item_to_slot"):
			if body_ref.add_item_to_slot("club", slot_index):
				if item:
					item.queue_free()
				return true
		return false
	return false

func try_equip_armor_from_world(item: Node) -> bool:
	var mouse_pos = get_global_mouse_position()
	# Check if dropping on armor slot
	if is_point_in_rect(mouse_pos, get_armor_slot_rect()):
		set_armor_equipped(true)
		if item:
			item.queue_free()
		return true
	# Check if dropping on bag slot
	var bag_slot_index = get_bag_slot_at_mouse()
	if bag_slot_index >= 0:
		if add_item_to_bag_slot("armor", bag_slot_index):
			if item:
				item.queue_free()
			return true
		return false
	# Check if dropping on dead body container slot
	var body_target = get_body_container_slot_target()
	if body_target:
		var body_ref = body_target["body"]
		var slot_index = body_target["index"]
		if body_ref and body_ref.has_method("add_item_to_slot"):
			if body_ref.add_item_to_slot("armor", slot_index):
				if item:
					item.queue_free()
				return true
		return false
	return false

func try_equip_pants_from_world(item: Node) -> bool:
	var mouse_pos = get_global_mouse_position()
	# Check if dropping on legs slot
	if is_point_in_rect(mouse_pos, get_legs_slot_rect()):
		set_pants_equipped(true)
		if item:
			item.queue_free()
		return true
	# Check if dropping on bag slot
	var bag_slot_index = get_bag_slot_at_mouse()
	if bag_slot_index >= 0:
		if add_item_to_bag_slot("pants", bag_slot_index):
			if item:
				item.queue_free()
			return true
		return false
	# Check if dropping on dead body container slot
	var body_target = get_body_container_slot_target()
	if body_target:
		var body_ref = body_target["body"]
		var slot_index = body_target["index"]
		if body_ref and body_ref.has_method("add_item_to_slot"):
			if body_ref.add_item_to_slot("pants", slot_index):
				if item:
					item.queue_free()
				return true
		return false
	return false

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

func add_item_to_bag_slot(item_type: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= bag_items.size():
		return false
	if bag_items[slot_index] != null:
		return false
	bag_items[slot_index] = item_type
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
			var title_bar = get_body_title_bar(child)
			if title_bar:
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
			var title_bar = get_body_title_bar(child)
			if title_bar:
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

func get_body_title_bar(window: Control) -> Control:
	var bars = window.find_children("*", "HBoxContainer", true, false)
	for bar in bars:
		if bar.has_meta("is_title_bar"):
			return bar
	return null

func get_body_container_slot_target() -> Dictionary:
	var screen_pos = get_viewport().get_mouse_position()
	for child in get_body_container_parents():
		if child.has_meta("is_body_container") and child.visible:
			var body_ref = child.get_meta("body_ref")
			if body_ref and body_ref.has_method("get_slot_index_at_screen_pos"):
				var slot_index = body_ref.get_slot_index_at_screen_pos(screen_pos)
				if slot_index >= 0:
					return {"body": body_ref, "index": slot_index}
	return {}

func get_body_container_item_at_mouse() -> Dictionary:
	var target = get_body_container_slot_target()
	if target.is_empty():
		return {}
	var body_ref = target["body"]
	var slot_index = target["index"]
	if body_ref and body_ref.has_method("get_item_at_slot"):
		var item_type = body_ref.get_item_at_slot(slot_index)
		if item_type != "":
			return {"body": body_ref, "index": slot_index, "item": item_type}
	return {}

func start_body_item_drag(body_item: Dictionary, mouse_pos: Vector2):
	var body_ref = body_item.get("body", null)
	var slot_index = body_item.get("index", -1)
	var item_type = body_item.get("item", "")
	if body_ref == null or slot_index < 0 or item_type == "":
		return
	if item_type == "helmet":
		if body_ref.has_method("remove_item_from_slot"):
			var removed = body_ref.remove_item_from_slot(slot_index)
			if removed == "":
				return
		set_helmet_equipped(true)
		if body_ref.has_method("get_slot_rect"):
			var slot_rect = body_ref.get_slot_rect(slot_index)
			helmet_icon.global_position = slot_rect.position + (slot_rect.size - helmet_icon.size) / 2.0
		is_dragging = true
		drag_offset = helmet_icon.global_position - mouse_pos
		update_drag_hover_state()
	elif item_type == "club":
		if body_ref.has_method("remove_item_from_slot"):
			var removed = body_ref.remove_item_from_slot(slot_index)
			if removed == "":
				return
		set_club_equipped("weapon")
		if body_ref.has_method("get_slot_rect"):
			var slot_rect = body_ref.get_slot_rect(slot_index)
			club_icon.global_position = slot_rect.position + (slot_rect.size - club_icon.size) / 2.0
		is_dragging_club = true
		club_drag_offset = club_icon.global_position - mouse_pos
	elif item_type == "armor":
		if body_ref.has_method("remove_item_from_slot"):
			var removed = body_ref.remove_item_from_slot(slot_index)
			if removed == "":
				return
		set_armor_equipped(true)
		if body_ref.has_method("get_slot_rect"):
			var slot_rect = body_ref.get_slot_rect(slot_index)
			armor_icon.global_position = slot_rect.position + (slot_rect.size - armor_icon.size) / 2.0
		is_dragging_armor = true
		armor_drag_offset = armor_icon.global_position - mouse_pos
	elif item_type == "pants":
		if body_ref.has_method("remove_item_from_slot"):
			var removed = body_ref.remove_item_from_slot(slot_index)
			if removed == "":
				return
		set_pants_equipped(true)
		if body_ref.has_method("get_slot_rect"):
			var slot_rect = body_ref.get_slot_rect(slot_index)
			pants_icon.global_position = slot_rect.position + (slot_rect.size - pants_icon.size) / 2.0
		is_dragging_pants = true
		pants_drag_offset = pants_icon.global_position - mouse_pos

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
	var item_type = bag_items[slot_index]
	if item_type == null:
		return
	
	# Remove from bag
	bag_items[slot_index] = null
	update_bag_slot_visual(slot_index)
	
	# Equip and start dragging
	var slot = bag_slots[slot_index]
	var slot_rect = Rect2(slot.global_position, slot.size)
	if item_type == "helmet":
		set_helmet_equipped(true)
		helmet_icon.global_position = slot_rect.position + (slot_rect.size - helmet_icon.size) / 2.0
		is_dragging = true
		drag_offset = helmet_icon.global_position - mouse_pos
		update_drag_hover_state()
	elif item_type == "club":
		set_club_equipped("weapon")
		club_icon.global_position = slot_rect.position + (slot_rect.size - club_icon.size) / 2.0
		is_dragging_club = true
		club_drag_offset = club_icon.global_position - mouse_pos
	elif item_type == "armor":
		set_armor_equipped(true)
		armor_icon.global_position = slot_rect.position + (slot_rect.size - armor_icon.size) / 2.0
		is_dragging_armor = true
		armor_drag_offset = armor_icon.global_position - mouse_pos
	elif item_type == "pants":
		set_pants_equipped(true)
		pants_icon.global_position = slot_rect.position + (slot_rect.size - pants_icon.size) / 2.0
		is_dragging_pants = true
		pants_drag_offset = pants_icon.global_position - mouse_pos
