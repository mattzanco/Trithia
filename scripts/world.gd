extends Node2D

# Procedural world generation for grid-based game

const TILE_SIZE = 32
const CHUNK_SIZE = 16  # 16x16 tiles per chunk
const RENDER_DISTANCE = 2  # How many chunks to render around player

var generated_chunks = {}  # Dictionary to track which chunks have been generated
var terrain_data = {}  # Dictionary to store terrain type at each tile position
var noise: FastNoiseLite
var last_drawn_count = 0
var time_passed = 0.0  # For water animation

# Water animation parameters
var water_wave_speed = 3.0  # Speed of the wave
var water_wave_amplitude = 2.0  # How far the water moves (pixels)

# Terrain textures for detailed rendering
var terrain_textures = {}

# Fallback terrain colors if textures fail to load
var terrain_colors = {
	"grass": Color(76.0/255.0, 153.0/255.0, 51.0/255.0),    # Green
	"stone": Color(140.0/255.0, 140.0/255.0, 140.0/255.0),  # Gray
	"water": Color(51.0/255.0, 102.0/255.0, 204.0/255.0)    # Blue
}

func _ready():
	# Initialize noise for procedural generation
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	# Load terrain textures using Image class to bypass import system
	var grass_image = Image.new()
	var stone_image = Image.new()
	var water_image = Image.new()
	
	if grass_image.load("res://assets/sprites/grass_tile.png") == OK:
		terrain_textures["grass"] = ImageTexture.create_from_image(grass_image)
		print("Loaded grass texture")
	else:
		print("Warning: Failed to load grass texture, using color fallback")
	
	if stone_image.load("res://assets/sprites/stone_tile.png") == OK:
		terrain_textures["stone"] = ImageTexture.create_from_image(stone_image)
		print("Loaded stone texture")
	else:
		print("Warning: Failed to load stone texture, using color fallback")
	
	if water_image.load("res://assets/sprites/water_tile.png") == OK:
		terrain_textures["water"] = ImageTexture.create_from_image(water_image)
		print("Loaded water texture")
	else:
		print("Warning: Failed to load water texture, using color fallback")
	
	# Generate initial terrain around origin
	update_world(Vector2.ZERO)

func _process(_delta):
	# Accumulate time for water animation
	time_passed += _delta
	# Only redraw when terrain changes or periodically for water animation
	if terrain_data.size() != last_drawn_count or fmod(time_passed, 0.1) < _delta:
		last_drawn_count = terrain_data.size()
		queue_redraw()

func update_world(player_position: Vector2):
	# Calculate which chunk the player is in
	var player_chunk = Vector2i(
		floor(player_position.x / (CHUNK_SIZE * TILE_SIZE)),
		floor(player_position.y / (CHUNK_SIZE * TILE_SIZE))
	)
	
	# Generate chunks around the player
	for x in range(player_chunk.x - RENDER_DISTANCE, player_chunk.x + RENDER_DISTANCE + 1):
		for y in range(player_chunk.y - RENDER_DISTANCE, player_chunk.y + RENDER_DISTANCE + 1):
			var chunk_pos = Vector2i(x, y)
			if not generated_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)

func generate_chunk(chunk_pos: Vector2i):
	generated_chunks[chunk_pos] = true
	
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var tile_x = start_x + x
			var tile_y = start_y + y
			
			# Get noise value for this position
			var noise_val = noise.get_noise_2d(tile_x, tile_y)
			
			# Determine terrain type
			var terrain_type = "grass"  # Default
			
			if noise_val < -0.3:
				terrain_type = "water"
			elif noise_val > 0.4:
				terrain_type = "stone"
			
			# Store terrain type for collision detection
			var tile_world_pos = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			terrain_data[tile_world_pos] = terrain_type
	
	# Trigger redraw when new terrain is generated
	queue_redraw()

func _draw():
	# Draw all terrain tiles with textures or color fallback
	for tile_pos in terrain_data.keys():
		var terrain_type = terrain_data[tile_pos]
		var tile_x = int(tile_pos.x - TILE_SIZE/2)
		var tile_y = int(tile_pos.y - TILE_SIZE/2)
		
		# Apply wave animation to water tiles
		var tile_width = TILE_SIZE
		var tile_height = TILE_SIZE
		
		if terrain_type == "water":
			# Create wave effect using sine function
			var wave_offset = sin(time_passed * water_wave_speed + tile_pos.x * 0.01 + tile_pos.y * 0.01) * water_wave_amplitude
			tile_y += int(wave_offset)
			# Make water tiles slightly larger to cover gaps during animation
			tile_width = TILE_SIZE + 2
			tile_height = TILE_SIZE + 2
			tile_x -= 1  # Offset to maintain centering with extra size
			tile_y -= 1
		
		var tile_rect = Rect2(tile_x, tile_y, tile_width, tile_height)
		
		# Try to use texture if available, otherwise use color
		if terrain_type in terrain_textures and terrain_textures[terrain_type] != null:
			draw_texture_rect(terrain_textures[terrain_type], tile_rect, false)
		elif terrain_type in terrain_colors:
			draw_rect(tile_rect, terrain_colors[terrain_type])
		else:
			# Fallback to white if neither texture nor color available
			draw_rect(tile_rect, Color.WHITE)
	


func is_walkable(world_position: Vector2) -> bool:
	# Check if the given world position is walkable
	# First try exact position match
	if terrain_data.has(world_position):
		var terrain = terrain_data[world_position]
		return terrain != "water"
	
	# If no exact match, find the closest tile and check it
	# Round to nearest tile center
	var tile_x = round(world_position.x / TILE_SIZE)
	var tile_y = round(world_position.y / TILE_SIZE)
	var nearest_tile = Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2, tile_y * TILE_SIZE + TILE_SIZE / 2)
	
	if terrain_data.has(nearest_tile):
		var terrain = terrain_data[nearest_tile]
		return terrain != "water"
	
	# If terrain not yet generated, check if it would be water based on noise
	# This provides early validation before terrain is fully generated
	if has_method("generate_chunk"):
		# Check the noise value at this position
		var tile_x_int = int(tile_x)
		var tile_y_int = int(tile_y)
		var noise_val = noise.get_noise_2d(tile_x_int, tile_y_int)
		# Return false (unwalkable) if it would be water
		if noise_val < -0.3:
			return false
		# If not water according to noise, it's walkable
		return true
	
	# If no noise generation method, assume it's walkable
	return true

func get_terrain_at(world_position: Vector2) -> String:
	"""Get terrain type at a world position"""
	if terrain_data.has(world_position):
		return terrain_data[world_position]
	
	# Check nearest tile
	var tile_x = round(world_position.x / TILE_SIZE)
	var tile_y = round(world_position.y / TILE_SIZE)
	var nearest_tile = Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2, tile_y * TILE_SIZE + TILE_SIZE / 2)
	
	if terrain_data.has(nearest_tile):
		return terrain_data[nearest_tile]
	
	# For ungenerated terrain, check noise value prediction
	var tile_x_int = int(tile_x)
	var tile_y_int = int(tile_y)
	var noise_val = noise.get_noise_2d(tile_x_int, tile_y_int)
	if noise_val < -0.3:
		return "water"
	elif noise_val < 0.2:
		return "grass"
	else:
		return "stone"
func find_path(start: Vector2, goal: Vector2, requester: Node) -> Array:
	"""Shared pathfinding function used by both player and orcs.
	
	Args:
		start: Starting tile center position
		goal: Goal tile center position
		requester: The node requesting the path (used to exclude it from occupancy checks)
	
	Returns:
		Array of waypoints (tile centers) from start to goal
	"""
	
	# If start and goal are the same, no path needed
	if start == goal:
		return []
	
	# Check if goal is walkable (apply feet offset to account for sprite animation)
	var feet_offset = Vector2(0, TILE_SIZE / 2)
	var goal_feet = goal + feet_offset
	var goal_tile_x = floor(goal_feet.x / TILE_SIZE)
	var goal_tile_y = floor(goal_feet.y / TILE_SIZE)
	var goal_tile_center = Vector2(goal_tile_x * TILE_SIZE + TILE_SIZE/2, goal_tile_y * TILE_SIZE + TILE_SIZE/2)
	if not is_walkable(goal_tile_center):
		return []
	
	# A* pathfinding
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: heuristic(start, goal)}
	var closed_set = {}
	var iterations = 0
	var max_iterations = 1000  # Reduced from 50000 - pathfinding is fast enough for most cases
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		# Find node with lowest f_score
		var current = open_set[0]
		var current_f = f_score.get(current, INF)
		var current_h = heuristic(current, goal)
		for node in open_set:
			var node_f = f_score.get(node, INF)
			if node_f < current_f:
				current = node
				current_f = node_f
				current_h = heuristic(node, goal)
			elif abs(node_f - current_f) < 0.01:  # Tie-breaking: prefer node closer to goal
				var node_h = heuristic(node, goal)
				if node_h < current_h:
					current = node
					current_f = node_f
					current_h = node_h
		
		# Reached goal
		if current == goal:
			return reconstruct_path(came_from, current)
		
		open_set.erase(current)
		closed_set[current] = true
		
		# Check all neighbors (8 directions)
		var neighbors = get_neighbors_world(current)
		for neighbor in neighbors:
			if neighbor in closed_set:
				continue
			
			# Check walkability (apply feet offset)
			var feet_position = neighbor + feet_offset
			var tile_x = floor(feet_position.x / TILE_SIZE)
			var tile_y = floor(feet_position.y / TILE_SIZE)
			var tile_center = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			
			if not is_walkable(tile_center):
				continue
			
			# EXTRA SAFEGUARD: Double-check terrain type directly isn't water
			# This catches edge cases where is_walkable might have a bug
			if has_method("get_terrain_at"):
				if get_terrain_at(neighbor) == "water":
					continue
				if get_terrain_at(tile_center) == "water":
					continue
			
			# Check if occupied by another entity (not by requester itself)
			# For pathfinding, allow paths through occupied tiles with a cost penalty
			# This prevents orcs from getting completely stuck when near each other
			var is_occupied = is_tile_occupied_by_other(neighbor, requester)
			
			# Calculate tentative g_score
			var tentative_g = g_score.get(current, INF) + current.distance_to(neighbor)
			
			# Add cost penalty for occupied tiles, but don't block them completely
			if is_occupied:
				tentative_g += TILE_SIZE  # Small penalty for occupied tiles
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				# Prefer diagonal movement by reducing its effective cost
				var move_dir = (neighbor - current).normalized()
				var is_diagonal = abs(move_dir.x) > 0.5 and abs(move_dir.y) > 0.5
				var diagonal_bonus = -3.0 if is_diagonal else 0.0
				f_score[neighbor] = tentative_g + heuristic(neighbor, goal) + diagonal_bonus
				
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	# No path found
	return []

func get_neighbors_world(tile_center: Vector2) -> Array:
	"""Get all 8 neighboring tiles (world version for pathfinding)"""
	var neighbors = []
	var tile_x = floor(tile_center.x / TILE_SIZE)
	var tile_y = floor(tile_center.y / TILE_SIZE)
	
	var directions = [
		Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
		Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)
	]
	
	for dir in directions:
		var neighbor_x = tile_x + dir.x
		var neighbor_y = tile_y + dir.y
		var neighbor_center = Vector2(neighbor_x * TILE_SIZE + TILE_SIZE/2, neighbor_y * TILE_SIZE + TILE_SIZE/2)
		neighbors.append(neighbor_center)
	
	return neighbors

func heuristic(a: Vector2, b: Vector2) -> float:
	"""Heuristic for A* (Chebyshev distance for 8-directional movement)"""
	var dx = abs(a.x - b.x) / TILE_SIZE
	var dy = abs(a.y - b.y) / TILE_SIZE
	return max(dx, dy) * TILE_SIZE

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	"""Reconstruct the path from came_from map"""
	var path = [current]
	while current in came_from:
		current = came_from[current]
		path.insert(0, current)
	return path

func is_tile_occupied_by_other(tile_position: Vector2, requester: Node) -> bool:
	"""Check if a tile is occupied by another entity (not the requester)"""
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			# Skip the requester itself
			if child == requester:
				continue
			
			# Check if any other character is on this tile
			if child is CharacterBody2D and child.has_method("get_position"):
				var distance = tile_position.distance_to(child.position)
				# Only consider a tile truly "occupied" if another entity is almost exactly on it
				# This allows pathfinding to work when entities are close but not perfectly overlapped
				if distance < TILE_SIZE * 0.2:  # ~6 pixels for TILE_SIZE=32
					return true
	
	return false