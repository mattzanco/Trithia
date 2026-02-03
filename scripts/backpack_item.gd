extends "res://scripts/draggable_item.gd"

func _ready():
	# Match base draggable setup
	pick_rect_size = Vector2(32, 32)
	pick_rect_offset = -pick_rect_size / 2.0
	super._ready()
	setup_backpack()
	set_process(false)

func setup_backpack():
	var sprite = Sprite2D.new()
	var texture = create_backpack_texture()
	sprite.texture = texture
	add_child(sprite)

func create_backpack_texture() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var bag_brown = Color(0.6, 0.4, 0.2)
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

func get_item_description() -> String:
	return "Backpack\nStores items."

func _input(event):
	super._input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		if get_pick_rect().has_point(mouse_pos):
			if is_player_adjacent():
				open_backpack()
			else:
				move_player_to_bag_and_open()
			get_viewport().set_input_as_handled()

func open_backpack():
	var equipment_menu = get_equipment_menu()
	if equipment_menu == null:
		return
	if equipment_menu.bag_container:
		equipment_menu.bag_container.visible = not equipment_menu.bag_container.visible
	elif equipment_menu.has_method("toggle_bag_container"):
		equipment_menu.toggle_bag_container()

var pending_open := false

func move_player_to_bag_and_open():
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
			open_backpack()
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
	return (dx <= 1 and dy <= 1)

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

func finish_drop():
	if try_equip_in_ui():
		return
	# If dropped over UI but not a valid slot, revert to previous position
	if is_mouse_over_ui():
		global_position = original_position
		return
	super.finish_drop()
	close_if_not_adjacent()

func close_if_not_adjacent():
	var equipment_menu = get_equipment_menu()
	if equipment_menu == null:
		return
	var player = get_player_node()
	if player == null:
		return
	var player_feet_pos = player.global_position + Vector2(0, TILE_SIZE / 2)
	var player_tile = get_tile_coords(player_feet_pos)
	var item_tile = get_tile_coords(global_position)
	var dx = abs(player_tile.x - item_tile.x)
	var dy = abs(player_tile.y - item_tile.y)
	var is_adjacent = (dx <= 1 and dy <= 1) and not (dx == 0 and dy == 0)
	if not is_adjacent and equipment_menu.has_method("toggle_bag_container"):
		# Ensure the backpack closes when thrown away from the player
		if equipment_menu.bag_container and equipment_menu.bag_container.visible:
			equipment_menu.bag_container.visible = false

func try_equip_in_ui() -> bool:
	var equipment_menu = get_equipment_menu()
	if equipment_menu == null:
		return false
	if equipment_menu.has_method("try_equip_backpack_from_world"):
		return equipment_menu.try_equip_backpack_from_world(self)
	return false

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false
	var hovered = viewport.gui_get_hovered_control()
	return hovered != null

func get_equipment_menu():
	return get_tree().get_root().find_child("EquipmentMenu", true, false)
