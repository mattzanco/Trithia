extends Node2D

# Main game scene

const TILE_SIZE = 32
const ORC_SCENE = preload("res://scenes/enemies/orc.tscn")
const TROLL_SCENE = preload("res://scenes/enemies/troll.tscn")
const BUILDING_SCENE = preload("res://scenes/town/building.tscn")
const DEV_CONSOLE_SCRIPT = preload("res://scripts/dev_console.gd")

var ysort_container: Node2D = null
var dev_console: CanvasLayer = null

func _ready():
	print("Trithia game started!")
	print("Main node ready, about to wait for process frame")

	setup_y_sort()
	setup_dev_console()
	
	await get_tree().process_frame  # Wait one frame for player to be ready
	print("About to call spawn_starting_orcs()")
	
	setup_towns()
	# Enemy spawning disabled for now.
	print("Enemy spawning disabled")

func spawn_starting_orcs():
	# Spawn 10 enemies at random spawn points around the world
	var player = get_player_node()
	var world = get_world_node()
	if world == null or not world.has_method("get_available_spawn_points"):
		return
	
	# Wait for world to generate spawn points
	await get_tree().process_frame
	
	var available_spawns = world.get_available_spawn_points(player.position)
	var enemies_to_spawn = min(10, available_spawns.size())
	
	print("[SPAWN] Found ", available_spawns.size(), " available spawn points")
	print("[SPAWN] Spawning ", enemies_to_spawn, " enemies")
	
	for i in range(enemies_to_spawn):
		var spawn_pos = available_spawns[i]
		spawn_enemy_at_spawn_point(spawn_pos)
		print("[SPAWN] Enemy ", i + 1, " spawned at: ", spawn_pos)

func _on_spawn_timer_timeout():
	"""Periodically spawn orcs at available spawn points"""
	var player = get_player_node()
	if player == null:
		return  # Player is dead, stop spawning
	
	var world = get_world_node()
	if world == null or not world.has_method("get_available_spawn_points"):
		return
	
	var available_spawns = world.get_available_spawn_points(player.position)
	
	# Spawn 1-3 enemies if spawn points are available
	if available_spawns.size() > 0:
		var num_to_spawn = min(randi_range(1, 3), available_spawns.size())
		for i in range(num_to_spawn):
			var random_index = randi_range(0, available_spawns.size() - 1)
			var spawn_pos = available_spawns[random_index]
			spawn_enemy_at_spawn_point(spawn_pos)
			print("[SPAWN TIMER] Spawned enemy at: ", spawn_pos)
			available_spawns.remove_at(random_index)

func spawn_enemy_at_spawn_point(spawn_pos: Vector2):
	"""Spawn an enemy at a specific spawn point"""
	var scene = ORC_SCENE if randi_range(0, 99) < 75 else TROLL_SCENE
	var enemy = scene.instantiate()
	enemy.position = spawn_pos
	if ysort_container:
		ysort_container.add_child(enemy)
	else:
		add_child(enemy)
	print("[SPAWN_FUNC] Enemy spawned at spawn point: ", spawn_pos)

func setup_towns():
	var player = get_player_node()
	var world = get_world_node()
	if player == null or world == null or not world.has_method("get_town_centers"):
		return
	var town_centers = world.get_town_centers()
	if town_centers.is_empty():
		return
	var start_center = town_centers[0]
	var spawn_pos = find_grass_spawn(world, start_center, world.get_town_radius_world())
	player.position = spawn_pos
	if world.has_method("update_world"):
		world.update_world(player.position)
	for town_center in town_centers:
		spawn_town_buildings(world, town_center)

func spawn_town_buildings(world: Node, town_center: Vector2):
	if world == null or not world.has_method("get_town_radius_world"):
		return
	var town_radius = world.get_town_radius_world()
	var building_rects: Array = []
	var attempts = 0
	var placed = 0
	var target_count = 12
	while placed < target_count and attempts < 600:
		attempts += 1
		var size_tiles = Vector2i(randi_range(4, 6), randi_range(4, 6))
		var pos = get_random_town_position(world, town_center, town_radius)
		if pos == Vector2.ZERO:
			continue
		var tile_pos = Vector2i(int(floor(pos.x / TILE_SIZE)), int(floor(pos.y / TILE_SIZE)))
		var rect = Rect2i(tile_pos, size_tiles)
		var center_tile = Vector2i(int(floor(town_center.x / TILE_SIZE)), int(floor(town_center.y / TILE_SIZE)))
		if center_tile.x >= rect.position.x and center_tile.x < rect.position.x + rect.size.x and center_tile.y >= rect.position.y and center_tile.y < rect.position.y + rect.size.y:
			continue
		if not is_building_area_walkable(world, rect):
			continue
		if is_rect_overlapping(rect, building_rects):
			continue
		if not is_building_door_clear(world, rect):
			continue
		building_rects.append(rect)
		var building = BUILDING_SCENE.instantiate()
		building.position = Vector2(rect.position.x * TILE_SIZE, rect.position.y * TILE_SIZE)
		building.set("size_tiles", size_tiles)
		if ysort_container:
			ysort_container.add_child(building)
		else:
			add_child(building)
		if world.has_method("remove_trees_in_rect"):
			world.remove_trees_in_rect(rect)
		placed += 1

func get_random_town_position(world: Node, town_center: Vector2, town_radius: float) -> Vector2:
	for i in range(40):
		var angle = randf() * TAU
		var dist = randf() * (town_radius - TILE_SIZE * 2)
		var pos = town_center + Vector2(cos(angle), sin(angle)) * dist
		if world != null and world.has_method("is_walkable") and not world.is_walkable(pos):
			continue
		return snap_to_tile_center(pos)
	return Vector2.ZERO

func snap_to_tile_center(world_position: Vector2) -> Vector2:
	var tile_x = floor(world_position.x / TILE_SIZE)
	var tile_y = floor(world_position.y / TILE_SIZE)
	return Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2, tile_y * TILE_SIZE + TILE_SIZE / 2)

func is_rect_overlapping(rect: Rect2i, existing_rects: Array) -> bool:
	for other in existing_rects:
		if rect.intersects(other):
			return true
	return false

func is_building_area_walkable(world: Node, rect: Rect2i) -> bool:
	if world == null or not world.has_method("is_walkable"):
		return true
	if world.has_method("is_tile_blocked_by_tree"):
		var door_tile = Vector2i(rect.position.x + int(rect.size.x / 2), rect.position.y + rect.size.y - 1)
		var outside_tile = Vector2i(door_tile.x, door_tile.y + 1)
		var porch_left = Vector2i(door_tile.x - 1, door_tile.y + 1)
		var porch_right = Vector2i(door_tile.x + 1, door_tile.y + 1)
		if world.is_tile_blocked_by_tree(door_tile):
			return false
		if world.is_tile_blocked_by_tree(outside_tile):
			return false
		if world.is_tile_blocked_by_tree(porch_left):
			return false
		if world.is_tile_blocked_by_tree(porch_right):
			return false
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var pos = Vector2(x * TILE_SIZE + TILE_SIZE / 2, y * TILE_SIZE + TILE_SIZE / 2)
			if world.has_method("get_forced_terrain"):
				if world.get_forced_terrain(Vector2i(x, y)) == "dirt":
					return false
			if world.has_method("is_tile_blocked_by_tree"):
				if world.is_tile_blocked_by_tree(Vector2i(x, y)):
					return false
			if not world.is_walkable(pos):
				return false
	return true

func is_building_door_clear(world: Node, rect: Rect2i) -> bool:
	if world == null or not world.has_method("is_walkable"):
		return true
	var door_tile = Vector2i(rect.position.x + int(rect.size.x / 2), rect.position.y + rect.size.y - 1)
	var outside_tile = Vector2i(door_tile.x, door_tile.y + 1)
	var porch_left = Vector2i(door_tile.x - 1, door_tile.y + 1)
	var porch_right = Vector2i(door_tile.x + 1, door_tile.y + 1)
	var door_pos = tile_to_world_center(door_tile)
	var outside_pos = tile_to_world_center(outside_tile)
	if not world.is_walkable(door_pos):
		return false
	if not world.is_walkable(outside_pos):
		return false
	if not world.is_walkable(tile_to_world_center(porch_left)):
		return false
	if not world.is_walkable(tile_to_world_center(porch_right)):
		return false
	if world.has_method("is_tile_blocked_by_building"):
		if world.is_tile_blocked_by_building(door_tile) or world.is_tile_blocked_by_building(outside_tile):
			return false
		if world.is_tile_blocked_by_building(porch_left) or world.is_tile_blocked_by_building(porch_right):
			return false
	return true

func find_grass_spawn(world: Node, town_center: Vector2, town_radius: float) -> Vector2:
	var center_tile = Vector2i(int(floor(town_center.x / TILE_SIZE)), int(floor(town_center.y / TILE_SIZE)))
	for radius in range(0, int(town_radius / TILE_SIZE) + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var tile = Vector2i(center_tile.x + dx, center_tile.y + dy)
				var pos = tile_to_world_center(tile)
				if world.has_method("get_terrain_type_from_noise"):
					if world.get_terrain_type_from_noise(tile.x, tile.y) != "grass":
						continue
				if world.has_method("is_tile_blocked_by_building") and world.is_tile_blocked_by_building(tile):
					continue
				return pos
	return town_center

func tile_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2, tile.y * TILE_SIZE + TILE_SIZE / 2)

func _process(_delta):
	# Y-sorting handles draw order when enabled.
	if ysort_container and ysort_container.y_sort_enabled:
		return
	update_depth_sorting()

func update_depth_sorting():
	# Get references to player
	var player = get_player_node()
	
	if player:
		if get_child_count() < 2:
			return
		# Get all enemy children
		var enemies = []
		for child in get_children():
			if child.is_in_group("enemies"):
				enemies.append(child)
		
		# Sort all enemies based on Y position relative to player
		for enemy in enemies:
			if enemy and enemy.get_parent() == self and player.get_parent() == self:
				# Character with higher Y (lower on screen) should be behind
				# Character with lower Y (higher on screen) should be in front
				var back_index = min(1, get_child_count() - 1)
				var front_index = min(2, get_child_count() - 1)
				if player.position.y > enemy.position.y:
					# Player is lower, enemy should be in front
					move_child(enemy, back_index)
					move_child(player, front_index)
				else:
					# Enemy is lower or same, player should be in front
					move_child(player, back_index)
					move_child(enemy, front_index)

func setup_y_sort():
	if ysort_container:
		return
	ysort_container = Node2D.new()
	ysort_container.name = "YSort"
	ysort_container.y_sort_enabled = true
	add_child(ysort_container)
	var corpse_layer = get_node_or_null("CorpseLayer")
	if corpse_layer:
		move_child(ysort_container, 2)
	else:
		move_child(ysort_container, 1)
	var player = get_node_or_null("Player")
	if player:
		player.reparent(ysort_container, true)

func setup_dev_console():
	if dev_console:
		return
	dev_console = CanvasLayer.new()
	dev_console.set_script(DEV_CONSOLE_SCRIPT)
	add_child(dev_console)
	dev_console.command_submitted.connect(_on_console_command)

func get_player_node() -> Node:
	if ysort_container:
		var player = ysort_container.get_node_or_null("Player")
		if player:
			return player
	return get_tree().get_root().find_child("Player", true, false)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			if dev_console:
				dev_console.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			var world_map = get_world_map_node()
			if world_map:
				if world_map.has_method("toggle"):
					world_map.toggle()
				else:
					world_map.visible = not world_map.visible
			get_viewport().set_input_as_handled()

func _on_console_command(command: String):
	var tokens = command.to_lower().split(" ", false)
	if tokens.is_empty():
		return
	if tokens[0] == "spawn" and tokens.size() >= 2:
		var enemy_type = tokens[1]
		if spawn_enemy_near_player(enemy_type):
			dev_console.append_log("Spawned " + enemy_type)
		else:
			dev_console.append_log("Failed to spawn " + enemy_type)
		return
	dev_console.append_log("Unknown command: " + command)

func spawn_enemy_near_player(enemy_type: String) -> bool:
	var player = get_player_node()
	var world = get_world_node()
	if player == null or world == null:
		return false
	var scene = null
	if enemy_type == "orc":
		scene = ORC_SCENE
	elif enemy_type == "troll":
		scene = TROLL_SCENE
	else:
		return false
	var player_tile = Vector2i(int(floor(player.position.x / TILE_SIZE)), int(floor(player.position.y / TILE_SIZE)))
	var min_dist = 6
	var max_dist = 12
	# Dev-spawn ignores town restrictions.
	for i in range(120):
		var angle = randf() * TAU
		var dist = randi_range(min_dist, max_dist)
		var offset = Vector2(cos(angle), sin(angle)) * dist
		var tile = Vector2i(player_tile.x + int(round(offset.x)), player_tile.y + int(round(offset.y)))
		var spawn_pos = tile_to_world_center(tile)
		if world.has_method("is_walkable"):
			if not world.is_walkable(spawn_pos):
				continue
		if world.has_method("is_tile_occupied_by_other") and world.is_tile_occupied_by_other(spawn_pos, null):
			continue
		var enemy = scene.instantiate()
		enemy.position = spawn_pos
		if ysort_container:
			ysort_container.add_child(enemy)
		else:
			add_child(enemy)
		return true
	return false


func get_world_node() -> Node:
	var direct = get_node_or_null("World")
	if direct and direct.has_method("get_available_spawn_points"):
		return direct
	var root = get_tree().get_root()
	var found = root.find_child("World", true, false)
	if found and found.has_method("get_available_spawn_points"):
		return found
	return direct

func get_world_map_node() -> Node:
	var direct = get_node_or_null("WorldMap")
	if direct:
		if direct.has_method("toggle"):
			return direct
		var child = direct.get_node_or_null("WorldMap")
		if child:
			return child
	var root = get_tree().get_root()
	var found = root.find_child("WorldMap", true, false)
	if found:
		if found.has_method("toggle"):
			return found
		var child_found = found.get_node_or_null("WorldMap")
		if child_found:
			return child_found
	return null


func show_game_over():
	# Disable the camera so it stops following the player
	var player = get_player_node()
	if player:
		var camera = player.get_node_or_null("Camera2D")
		if camera:
			camera.enabled = false
	
	# Create a CanvasLayer for the UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	# Create a Control node with the death screen script
	var death_screen = Control.new()
	var death_screen_script = load("res://scripts/death_screen.gd")
	death_screen.set_script(death_screen_script)
	
	# Add the death screen to the canvas layer
	canvas_layer.add_child(death_screen)
	
	# Make the control node fill the viewport
	death_screen.anchors_preset = Control.PRESET_FULL_RECT
	
	print("[GAME_OVER] Game over screen displayed")

