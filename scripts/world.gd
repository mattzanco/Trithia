extends Node2D

# Procedural world generation for grid-based game

const TILE_SIZE = 32
const CHUNK_SIZE = 16  # 16x16 tiles per chunk
const RENDER_DISTANCE = 2  # How many chunks to render around player
const CHUNK_UNLOAD_DISTANCE = 3  # Chunks beyond this distance are evicted
const TOWN_RADIUS_TILES = 30
const TOWN_SPACING_TILES = 600
const TOWN_CELL_RADIUS = 2
const TOWN_OFFSET_TILES = 160
const TOWN_CELL_CHANCE = 0.45
const TOWN_ROAD_WIDTH = 2
const TOWN_CONNECT_COUNT = 2
const TOWN_NAME_PREFIXES = ["Stone", "Oak", "River", "Elder", "Grey", "High", "Low", "North", "South", "East", "West", "Bright", "Red", "Black", "Green", "Gold", "Iron", "Wind", "Ash", "Pine"]
const TOWN_NAME_SUFFIXES = ["ford", "vale", "watch", "keep", "mere", "brook", "hollow", "ridge", "haven", "crest", "dale", "moor", "gate", "cross", "fall", "port", "hold", "field"]
const TREE_TRUNK_SCRIPT = preload("res://scripts/tree_trunk.gd")
const TREE_CANOPY_SCRIPT = preload("res://scripts/tree_canopy.gd")

var generated_chunks = {}  # Dictionary to track which chunks have been generated
var terrain_data = {}  # Dictionary to store terrain type at each tile position
var chunk_tiles = {}  # Dictionary of chunk_pos -> Array of tile world positions
var spawn_points = []  # Array of spawn point positions (world positions)
var spawn_points_per_chunk = 2  # Number of spawn points to create per chunk
var chunk_spawn_points = {}  # Dictionary of chunk_pos -> Array of spawn points
var tree_nodes = {}  # Dictionary of chunk_pos -> Array of tree nodes
var tree_trunk_tiles = {}  # Dictionary of chunk_pos -> Array of trunk tiles
var tree_trunk_blockers = {}  # Dictionary of Vector2i -> true
var noise: FastNoiseLite
var tree_noise: FastNoiseLite
var world_seed = 0
var last_drawn_count = 0
var time_passed = 0.0  # For water animation
var building_zones: Array = []
var player_inside_building: Node = null
var town_centers: Array = []
var town_grid = {}
var town_names: Array = []
var town_name_grid = {}
var road_connections = {}
var forced_terrain = {}
var last_player_chunk = null

# Water animation parameters
var water_wave_speed = 3.0  # Speed of the wave
var water_wave_amplitude = 2.0  # How far the water moves (pixels)

# Terrain textures for detailed rendering
var terrain_textures = {}

# Fallback terrain colors if textures fail to load
var terrain_colors = {
	"grass": Color(76.0/255.0, 153.0/255.0, 51.0/255.0),    # Green
	"dirt": Color(139.0/255.0, 90.0/255.0, 43.0/255.0),     # Brown
	"sand": Color(194.0/255.0, 178.0/255.0, 128.0/255.0),   # Sandy beige
	"water": Color(51.0/255.0, 102.0/255.0, 204.0/255.0)    # Blue
}

func _ready():
	# Initialize noise for procedural generation
	noise = FastNoiseLite.new()
	world_seed = randi()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	tree_noise = FastNoiseLite.new()
	tree_noise.seed = world_seed + 1337
	tree_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	tree_noise.frequency = 0.02
	
	# Load terrain textures using Image class to bypass import system
	var grass_image = Image.new()
	var dirt_image = Image.new()
	var sand_image = Image.new()
	var water_image = Image.new()
	
	if grass_image.load("res://assets/sprites/grass_tile.png") == OK:
		terrain_textures["grass"] = ImageTexture.create_from_image(grass_image)
		print("Loaded grass texture")
	else:
		print("Warning: Failed to load grass texture, using color fallback")
	
	if dirt_image.load("res://assets/sprites/dirt_tile.png") == OK:
		terrain_textures["dirt"] = ImageTexture.create_from_image(dirt_image)
		print("Loaded dirt texture")
	else:
		print("Warning: Failed to load dirt texture, using color fallback")
	
	if sand_image.load("res://assets/sprites/sand_tile.png") == OK:
		terrain_textures["sand"] = ImageTexture.create_from_image(sand_image)
		print("Loaded sand texture")
	else:
		print("Warning: Failed to load sand texture, using color fallback")
	
	if water_image.load("res://assets/sprites/water_tile.png") == OK:
		terrain_textures["water"] = ImageTexture.create_from_image(water_image)
		print("Loaded water texture")
	else:
		print("Warning: Failed to load water texture, using color fallback")
	
	# Generate initial towns and roads around origin
	ensure_towns_near(Vector2.ZERO)
	connect_new_towns(town_centers)

	# Generate initial terrain around origin
	update_world(Vector2.ZERO)
	call_deferred("reparent_trees_to_ysort")

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
	if last_player_chunk == player_chunk:
		return
	last_player_chunk = player_chunk
	ensure_towns_near(player_position)
	
	# Generate chunks around the player
	for x in range(player_chunk.x - RENDER_DISTANCE, player_chunk.x + RENDER_DISTANCE + 1):
		for y in range(player_chunk.y - RENDER_DISTANCE, player_chunk.y + RENDER_DISTANCE + 1):
			var chunk_pos = Vector2i(x, y)
			if not generated_chunks.has(chunk_pos):
				generate_chunk(chunk_pos)
	
	# Evict far chunks to keep memory bounded
	unload_far_chunks(player_chunk)

func generate_chunk(chunk_pos: Vector2i):
	generated_chunks[chunk_pos] = true
	
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	var tile_list: Array = []
	
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var tile_x = start_x + x
			var tile_y = start_y + y
			
			# Get noise value for this position
			# Determine terrain type with overrides
			var terrain_type = get_terrain_type_from_noise(tile_x, tile_y)
			
			# Store terrain type for collision detection
			var tile_world_pos = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			terrain_data[tile_world_pos] = terrain_type
			tile_list.append(tile_world_pos)
	
	# Second pass: convert some tiles adjacent to water into sand
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var tile_x = start_x + x
			var tile_y = start_y + y
			var tile_world_pos = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			
			if get_forced_terrain(Vector2i(tile_x, tile_y)) != "":
				continue
			if terrain_data[tile_world_pos] in ["grass", "dirt"]:
				if should_apply_sand(tile_x, tile_y):
					terrain_data[tile_world_pos] = "sand"
	
	# Generate spawn points for this chunk
	generate_spawn_points_for_chunk(chunk_pos)
	chunk_tiles[chunk_pos] = tile_list
	generate_trees_for_chunk(chunk_pos)
	
	# Trigger redraw when new terrain is generated
	queue_redraw()

func get_base_terrain_type(tile_x: int, tile_y: int) -> String:
	"""Get terrain type directly from noise value for a tile coordinate"""
	var noise_val = noise.get_noise_2d(tile_x, tile_y)
	if noise_val < -0.3:
		return "water"
	if noise_val > 0.4:
		return "dirt"
	return "grass"

func get_terrain_type_from_noise(tile_x: int, tile_y: int) -> String:
	var forced = get_forced_terrain(Vector2i(tile_x, tile_y))
	if forced != "":
		return forced
	return get_base_terrain_type(tile_x, tile_y)

func get_render_terrain_type(tile_x: int, tile_y: int) -> String:
	var forced = get_forced_terrain(Vector2i(tile_x, tile_y))
	if forced != "":
		return forced
	var base = get_base_terrain_type(tile_x, tile_y)
	if base == "water":
		return base
	# Match the sand pass used during chunk generation.
	if should_apply_sand(tile_x, tile_y):
		return "sand"
	return base

func should_place_tree(tile_x: int, tile_y: int) -> bool:
	var tile = Vector2i(tile_x, tile_y)
	var forced = get_forced_terrain(tile)
	if forced != "" and forced != "grass":
		return false
	if is_tile_blocked_by_building(tile):
		return false
	var render_terrain = get_render_terrain_type(tile_x, tile_y)
	if render_terrain != "grass" and render_terrain != "dirt":
		return false
	var region = tree_noise.get_noise_2d(float(tile_x) * 0.5, float(tile_y) * 0.5)
	var density = 0.02
	if region > 0.35:
		density = 0.08
	if region > 0.55:
		density = 0.16
	return rand01(Vector2i(tile_x, tile_y), 97) < density

func generate_trees_for_chunk(chunk_pos: Vector2i):
	if tree_nodes.has(chunk_pos):
		return
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	var nodes: Array = []
	var trunks: Array = []
	var ysort = get_tree().get_root().find_child("YSort", true, false)
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			var tile_x = start_x + x
			var tile_y = start_y + y
			if not should_place_tree(tile_x, tile_y):
				continue
			var tile = Vector2i(tile_x, tile_y)
			if tree_trunk_blockers.has(tile):
				continue
			var trunk = Node2D.new()
			trunk.name = "TreeTrunk"
			# Nudge trunk up so the player at the same tile renders in front.
			trunk.position = tile_to_world_center(tile) + Vector2(0, -6)
			trunk.set_script(TREE_TRUNK_SCRIPT)
			trunk.set_meta("trunk_tile", tile)
			var canopy = Node2D.new()
			canopy.name = "TreeCanopy"
			canopy.position = trunk.position + Vector2(0, -TILE_SIZE)
			canopy.set_script(TREE_CANOPY_SCRIPT)
			canopy.set_meta("trunk_tile", tile)
			if ysort:
				ysort.add_child(trunk)
				ysort.add_child(canopy)
			else:
				add_child(trunk)
				add_child(canopy)
			nodes.append(trunk)
			nodes.append(canopy)
			trunks.append(tile)
			tree_trunk_blockers[tile] = true
	tree_nodes[chunk_pos] = nodes
	tree_trunk_tiles[chunk_pos] = trunks

func remove_trees_in_rect(rect: Rect2i):
	for chunk_pos in tree_nodes.keys():
		var nodes = tree_nodes[chunk_pos]
		var remaining_nodes: Array = []
		var removed_tiles = {}
		for node in nodes:
			if node == null or not is_instance_valid(node):
				continue
			if node.has_meta("trunk_tile"):
				var tile: Vector2i = node.get_meta("trunk_tile")
				if is_tile_in_rect(tile, rect):
					removed_tiles[tile] = true
					node.queue_free()
					continue
			remaining_nodes.append(node)
		tree_nodes[chunk_pos] = remaining_nodes
		if removed_tiles.size() > 0 and tree_trunk_tiles.has(chunk_pos):
			var remaining_tiles: Array = []
			for tile in tree_trunk_tiles[chunk_pos]:
				if removed_tiles.has(tile):
					tree_trunk_blockers.erase(tile)
					continue
				remaining_tiles.append(tile)
			tree_trunk_tiles[chunk_pos] = remaining_tiles

func reparent_trees_to_ysort():
	var ysort = get_tree().get_root().find_child("YSort", true, false)
	if not ysort:
		return
	for chunk_pos in tree_nodes.keys():
		for tree in tree_nodes[chunk_pos]:
			if tree and is_instance_valid(tree) and tree.get_parent() != ysort:
				tree.reparent(ysort, true)

func should_apply_sand(tile_x: int, tile_y: int) -> bool:
	# Only consider sand next to water, with a noisy chance for organic patches.
	var has_water_neighbor = false
	var water_neighbors = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if get_base_terrain_type(tile_x + dx, tile_y + dy) == "water":
				has_water_neighbor = true
				water_neighbors += 1
	if not has_water_neighbor:
		return false
	# Use deterministic noise to create patchy sand near water.
	var n = noise.get_noise_2d(float(tile_x) * 0.8 + 100.0, float(tile_y) * 0.8 - 100.0)
	var threshold = -0.1 + float(water_neighbors) * 0.05
	return n > threshold

func generate_spawn_points_for_chunk(chunk_pos: Vector2i):
	"""Generate spawn points within a chunk on walkable terrain"""
	if chunk_spawn_points.has(chunk_pos):
		var cached_points = chunk_spawn_points[chunk_pos]
		for cached in cached_points:
			spawn_points.append(cached)
		return
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	var attempts = 0
	var max_attempts = 50
	var new_points: Array = []
	
	for i in range(spawn_points_per_chunk):
		var spawn_found = false
		attempts = 0
		
		while not spawn_found and attempts < max_attempts:
			# Random position within chunk
			var tile_x = start_x + randi_range(2, CHUNK_SIZE - 3)
			var tile_y = start_y + randi_range(2, CHUNK_SIZE - 3)
			var spawn_pos = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			
			# Check if walkable and not too close to other spawn points
			if is_walkable(spawn_pos):
				if is_point_in_town(spawn_pos):
					attempts += 1
					continue
				var too_close = false
				for existing_spawn in spawn_points:
					if spawn_pos.distance_to(existing_spawn) < TILE_SIZE * 5:
						too_close = true
						break
				
				if not too_close:
					spawn_points.append(spawn_pos)
					new_points.append(spawn_pos)
					spawn_found = true
			
			attempts += 1

	chunk_spawn_points[chunk_pos] = new_points

func unload_far_chunks(player_chunk: Vector2i):
	var to_unload: Array = []
	for chunk_pos in generated_chunks.keys():
		var dx = abs(chunk_pos.x - player_chunk.x)
		var dy = abs(chunk_pos.y - player_chunk.y)
		if dx > CHUNK_UNLOAD_DISTANCE or dy > CHUNK_UNLOAD_DISTANCE:
			to_unload.append(chunk_pos)
	for chunk_pos in to_unload:
		unload_chunk(chunk_pos)

func unload_chunk(chunk_pos: Vector2i):
	if chunk_tiles.has(chunk_pos):
		var tiles = chunk_tiles[chunk_pos]
		for tile_pos in tiles:
			terrain_data.erase(tile_pos)
		chunk_tiles.erase(chunk_pos)
	if chunk_spawn_points.has(chunk_pos):
		var points = chunk_spawn_points[chunk_pos]
		for spawn_pos in points:
			spawn_points.erase(spawn_pos)
		chunk_spawn_points.erase(chunk_pos)
	if tree_nodes.has(chunk_pos):
		for tree in tree_nodes[chunk_pos]:
			if tree and is_instance_valid(tree):
				tree.queue_free()
		tree_nodes.erase(chunk_pos)
	if tree_trunk_tiles.has(chunk_pos):
		for tile in tree_trunk_tiles[chunk_pos]:
			tree_trunk_blockers.erase(tile)
		tree_trunk_tiles.erase(chunk_pos)
	# Allow regeneration when revisiting
	generated_chunks.erase(chunk_pos)

func is_spawn_point_visible(spawn_pos: Vector2, player_pos: Vector2, view_distance: float = 600.0) -> bool:
	"""Check if a spawn point is visible to the player (within view distance)"""
	return spawn_pos.distance_to(player_pos) < view_distance

func get_available_spawn_points(player_pos: Vector2) -> Array:
	"""Get all spawn points that are not visible to the player"""
	var available = []
	for spawn_pos in spawn_points:
		if is_point_in_town(spawn_pos):
			continue
		if not is_spawn_point_visible(spawn_pos, player_pos):
			available.append(spawn_pos)
	return available

func get_town_center() -> Vector2:
	if town_centers.is_empty():
		return Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	return town_centers[0]

func get_town_centers() -> Array:
	return town_centers

func get_town_radius_world() -> float:
	return TOWN_RADIUS_TILES * TILE_SIZE

func is_point_in_town(world_position: Vector2) -> bool:
	for center in town_centers:
		if world_position.distance_to(center) <= get_town_radius_world():
			return true
	return false

func get_forced_terrain(tile: Vector2i) -> String:
	return forced_terrain.get(tile, "")

func set_forced_terrain(tile: Vector2i, terrain_type: String):
	forced_terrain[tile] = terrain_type
	var world_pos = tile_to_world_center(tile)
	if terrain_data.has(world_pos):
		terrain_data[world_pos] = terrain_type

func tile_to_world_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2, tile.y * TILE_SIZE + TILE_SIZE / 2)

func world_to_town_cell(world_position: Vector2) -> Vector2i:
	var tile = get_tile_coords(world_position)
	return Vector2i(int(floor(float(tile.x) / float(TOWN_SPACING_TILES))), int(floor(float(tile.y) / float(TOWN_SPACING_TILES))))

func hash_cell(cell: Vector2i, salt: int) -> int:
	var h = int(cell.x * 73856093) ^ int(cell.y * 19349663) ^ int(world_seed + salt)
	return abs(h)

func rand01(cell: Vector2i, salt: int) -> float:
	return float(hash_cell(cell, salt) % 10000) / 10000.0

func should_spawn_town(cell: Vector2i) -> bool:
	return rand01(cell, 11) < TOWN_CELL_CHANCE

func find_nearest_land_tile(start_tile: Vector2i, max_radius: int) -> Vector2i:
	for r in range(0, max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var tile = start_tile + Vector2i(dx, dy)
				if get_base_terrain_type(tile.x, tile.y) != "water":
					return tile
	return start_tile

func get_town_center_for_cell(cell: Vector2i) -> Vector2:
	var base_tile = Vector2i(cell.x * TOWN_SPACING_TILES, cell.y * TOWN_SPACING_TILES)
	var offset_x = int(round((rand01(cell, 21) * 2.0 - 1.0) * TOWN_OFFSET_TILES))
	var offset_y = int(round((rand01(cell, 31) * 2.0 - 1.0) * TOWN_OFFSET_TILES))
	var start_tile = base_tile + Vector2i(offset_x, offset_y)
	var land_tile = find_nearest_land_tile(start_tile, 30)
	return tile_to_world_center(land_tile)

func apply_town_clearing(town_center: Vector2):
	var center_tile = get_tile_coords(town_center)
	for dx in range(-TOWN_RADIUS_TILES, TOWN_RADIUS_TILES + 1):
		for dy in range(-TOWN_RADIUS_TILES, TOWN_RADIUS_TILES + 1):
			if Vector2(dx, dy).length() > TOWN_RADIUS_TILES:
				continue
			var tile = center_tile + Vector2i(dx, dy)
			if get_base_terrain_type(tile.x, tile.y) == "water":
				continue
			set_forced_terrain(tile, "grass")

func ensure_towns_near(player_position: Vector2):
	var cell = world_to_town_cell(player_position)
	var new_centers: Array = []
	for cx in range(cell.x - TOWN_CELL_RADIUS, cell.x + TOWN_CELL_RADIUS + 1):
		for cy in range(cell.y - TOWN_CELL_RADIUS, cell.y + TOWN_CELL_RADIUS + 1):
			var town_cell = Vector2i(cx, cy)
			if town_grid.has(town_cell):
				continue
			if not should_spawn_town(town_cell):
				continue
			var center = get_town_center_for_cell(town_cell)
			town_grid[town_cell] = center
			_register_town_name(town_cell)
			town_centers.append(center)
			new_centers.append(center)
			apply_town_clearing(center)
	if not new_centers.is_empty():
		connect_new_towns(new_centers)

func _register_town_name(cell: Vector2i):
	if town_name_grid.has(cell):
		return
	var base = _generate_town_name(cell)
	var name = base
	var suffix_index = 2
	while town_names.has(name):
		name = "%s %d" % [base, suffix_index]
		suffix_index += 1
	if name != "":
		town_names.append(name)
		town_name_grid[cell] = name

func _generate_town_name(cell: Vector2i) -> String:
	var prefix = TOWN_NAME_PREFIXES[hash_cell(cell, 71) % TOWN_NAME_PREFIXES.size()]
	var suffix = TOWN_NAME_SUFFIXES[hash_cell(cell, 83) % TOWN_NAME_SUFFIXES.size()]
	return "%s%s" % [prefix, suffix]

func get_town_name_for_center(town_center: Vector2) -> String:
	for cell in town_grid.keys():
		if town_grid[cell] == town_center:
			return town_name_grid.get(cell, "")
	return ""

func get_nearest_towns(center: Vector2, count: int) -> Array:
	var candidates: Array = []
	for other in town_centers:
		if other == center:
			continue
		candidates.append({"pos": other, "dist": center.distance_to(other)})
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var result: Array = []
	for i in range(min(count, candidates.size())):
		result.append(candidates[i]["pos"])
	return result

func road_key(a: Vector2, b: Vector2) -> String:
	var a_tile = get_tile_coords(a)
	var b_tile = get_tile_coords(b)
	if a_tile.x > b_tile.x or (a_tile.x == b_tile.x and a_tile.y > b_tile.y):
		var tmp = a_tile
		a_tile = b_tile
		b_tile = tmp
	return "%s,%s|%s,%s" % [a_tile.x, a_tile.y, b_tile.x, b_tile.y]

func connect_new_towns(new_centers: Array):
	for center in new_centers:
		var neighbors = get_nearest_towns(center, TOWN_CONNECT_COUNT)
		for neighbor in neighbors:
			var key = road_key(center, neighbor)
			if road_connections.has(key):
				continue
			create_road(center, neighbor)
			road_connections[key] = true

func is_water_tile(tile: Vector2i) -> bool:
	return get_base_terrain_type(tile.x, tile.y) == "water"

func set_road_brush(tile: Vector2i):
	for dx in range(-TOWN_ROAD_WIDTH, TOWN_ROAD_WIDTH + 1):
		for dy in range(-TOWN_ROAD_WIDTH, TOWN_ROAD_WIDTH + 1):
			if Vector2(dx, dy).length() > TOWN_ROAD_WIDTH:
				continue
			var t = tile + Vector2i(dx, dy)
			set_forced_terrain(t, "dirt")

func create_road(start_world: Vector2, end_world: Vector2):
	var start = get_tile_coords(start_world)
	var goal = get_tile_coords(end_world)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash_cell(start, 77) ^ hash_cell(goal, 91)
	var current = start
	var last_step = Vector2i.ZERO
	var straight_len = 0
	var steps = 0
	var max_steps = int(start.distance_to(goal) * 2.5) + 200
	while current != goal and steps < max_steps:
		set_road_brush(current)
		var dir = Vector2i(sign(goal.x - current.x), sign(goal.y - current.y))
		var toward_steps: Array = []
		var perpendicular_steps: Array = []
		if dir.x != 0:
			toward_steps.append(Vector2i(dir.x, 0))
			perpendicular_steps.append(Vector2i(0, 1))
			perpendicular_steps.append(Vector2i(0, -1))
		if dir.y != 0:
			toward_steps.append(Vector2i(0, dir.y))
			perpendicular_steps.append(Vector2i(1, 0))
			perpendicular_steps.append(Vector2i(-1, 0))
		var candidates: Array = []
		if last_step != Vector2i.ZERO and rng.randf() < (0.55 + min(straight_len, 6) * 0.03):
			candidates.append(last_step)
			candidates.append(last_step)
		for step in toward_steps:
			candidates.append(step)
			candidates.append(step)
		if rng.randf() < 0.45:
			for step in perpendicular_steps:
				candidates.append(step)
		candidates.shuffle()
		var chosen = false
		var blocked_by_water = []
		for cand in candidates:
			var next = current + cand
			if is_water_tile(next):
				blocked_by_water.append(cand)
				if rng.randf() < 0.75:
					continue
			current = next
			if cand == last_step:
				straight_len += 1
			else:
				straight_len = 1
			last_step = cand
			chosen = true
			break
		if not chosen:
			var fallback = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			fallback.shuffle()
			for cand in fallback:
				var next = current + cand
				if is_water_tile(next):
					blocked_by_water.append(cand)
					if rng.randf() < 0.75:
						continue
				current = next
				last_step = cand
				straight_len = 1
				chosen = true
				break
		if not chosen and not blocked_by_water.is_empty():
			var cand = blocked_by_water[rng.randi_range(0, blocked_by_water.size() - 1)]
			current = current + cand
			last_step = cand
			straight_len = 1
			chosen = true
		if not chosen:
			break
		steps += 1
	set_road_brush(goal)

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
	# Calculate which tile this position is in
	var tile_x = int(floor(world_position.x / TILE_SIZE))
	var tile_y = int(floor(world_position.y / TILE_SIZE))
	var tile = Vector2i(tile_x, tile_y)
	
	# Check terrain directly from noise - this is the authoritative source
	var terrain_type = get_terrain_type_from_noise(tile_x, tile_y)
	if terrain_type == "water":
		return false
	if is_tile_blocked_by_building(tile):
		return false
	return true
	
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
	# Calculate which tile this position is in
	var tile_x = int(floor(world_position.x / TILE_SIZE))
	var tile_y = int(floor(world_position.y / TILE_SIZE))
	
	# Get terrain directly from noise - this is the authoritative source
	return get_terrain_type_from_noise(tile_x, tile_y)
	
	# For ungenerated terrain, check noise value prediction
	var tile_x_int = int(tile_x)
	var tile_y_int = int(tile_y)
	var noise_val = noise.get_noise_2d(tile_x_int, tile_y_int)
	if noise_val < -0.3:
		return "water"
	elif noise_val < 0.2:
		return "grass"
	else:
		return "dirt"

func is_walkable_for_player(world_position: Vector2, from_position: Vector2 = Vector2.INF) -> bool:
	var tile_x = int(floor(world_position.x / TILE_SIZE))
	var tile_y = int(floor(world_position.y / TILE_SIZE))
	var tile = Vector2i(tile_x, tile_y)
	var terrain_type = get_terrain_type_from_noise(tile_x, tile_y)
	if terrain_type == "water":
		return false
	if is_tile_blocked_by_tree(tile):
		return false
	var building = get_building_for_tile(tile)
	if building.is_empty():
		if player_inside_building == null:
			return true
		var from_tile = Vector2i.ZERO
		if from_position != Vector2.INF:
			var from_feet = from_position + Vector2(0, TILE_SIZE / 2)
			from_tile = get_tile_coords(from_feet)
		var inside_entry = get_building_entry_for_node(player_inside_building)
		if inside_entry.is_empty():
			return true
		if from_tile == inside_entry["door"]:
			return is_building_door_open(inside_entry)
		return false
	if player_inside_building != null and building["building"] == player_inside_building:
		if tile == building["door"]:
			return true
		return is_tile_in_building_interior(tile, building["rect"])
	if tile == building["door"]:
		return is_building_door_open(building)
	if player_inside_building == null and is_tile_on_building_roof_edge(tile, building["rect"]):
		return true
	return false

func is_walkable_for_actor(world_position: Vector2, from_feet_position: Vector2 = Vector2.INF, inside_building: Node = null, allow_roof_edge: bool = true, allow_doors: bool = true) -> bool:
	var tile_x = int(floor(world_position.x / TILE_SIZE))
	var tile_y = int(floor(world_position.y / TILE_SIZE))
	var tile = Vector2i(tile_x, tile_y)
	var terrain_type = get_terrain_type_from_noise(tile_x, tile_y)
	if terrain_type == "water":
		return false
	if is_tile_blocked_by_tree(tile):
		return false
	var building = get_building_for_tile(tile)
	if building.is_empty():
		if inside_building == null:
			return true
		var from_tile = Vector2i.ZERO
		if from_feet_position != Vector2.INF:
			from_tile = get_tile_coords(from_feet_position)
		var inside_entry = get_building_entry_for_node(inside_building)
		if inside_entry.is_empty():
			return true
		if from_tile == inside_entry["door"]:
			return is_building_door_open(inside_entry)
		return false
	if inside_building != null and building["building"] == inside_building:
		if tile == building["door"]:
			return allow_doors
		return is_tile_in_building_interior(tile, building["rect"])
	if tile == building["door"]:
		return allow_doors and is_building_door_open(building)
	if allow_roof_edge and inside_building == null and is_tile_on_building_roof_edge(tile, building["rect"]):
		return true
	return false

func add_building(building: Node, rect: Rect2i, door_tile: Vector2i):
	building_zones.append({"building": building, "rect": rect, "door": door_tile})

func remove_building(building: Node):
	for i in range(building_zones.size() - 1, -1, -1):
		if building_zones[i]["building"] == building:
			building_zones.remove_at(i)
	if player_inside_building == building:
		player_inside_building = null

func set_player_inside_building(building: Node):
	player_inside_building = building

func clear_player_inside_building(building: Node):
	if player_inside_building == building:
		player_inside_building = null

func get_building_for_tile(tile: Vector2i) -> Dictionary:
	for building in building_zones:
		if is_tile_in_rect(tile, building["rect"]):
			return building
	return {}

func get_building_entry_for_node(building_node: Node) -> Dictionary:
	for building in building_zones:
		if building["building"] == building_node:
			return building
	return {}

func get_building_zones() -> Array:
	return building_zones

func is_building_door_open(building_entry: Dictionary) -> bool:
	if building_entry.is_empty():
		return false
	var building_node = building_entry.get("building", null)
	if building_node == null:
		return false
	if building_node.has_method("is_door_open"):
		return building_node.is_door_open()
	if building_node.has_method("get"):
		return bool(building_node.get("door_open"))
	return false

func is_tile_blocked_by_building(tile: Vector2i) -> bool:
	return not get_building_for_tile(tile).is_empty()

func is_tile_blocked_by_tree(tile: Vector2i) -> bool:
	return tree_trunk_blockers.has(tile)

func is_tile_in_rect(tile: Vector2i, rect: Rect2i) -> bool:
	return tile.x >= rect.position.x and tile.x < rect.position.x + rect.size.x and tile.y >= rect.position.y and tile.y < rect.position.y + rect.size.y

func is_tile_in_building_interior(tile: Vector2i, rect: Rect2i) -> bool:
	return tile.x >= rect.position.x and tile.x < rect.position.x + rect.size.x and tile.y >= rect.position.y + 1 and tile.y < rect.position.y + rect.size.y

func is_tile_on_building_roof_edge(tile: Vector2i, rect: Rect2i) -> bool:
	return tile.y == rect.position.y and tile.x >= rect.position.x and tile.x < rect.position.x + rect.size.x

func get_tile_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))

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
	var is_enemy = requester != null and requester.has_method("is_in_group") and requester.is_in_group("enemies")
	var inside_building = null
	if is_enemy and requester.has_method("get_current_building"):
		inside_building = requester.get_current_building()
		if inside_building == null and requester.has_method("get_pathfinding_building"):
			inside_building = requester.get_pathfinding_building()
	var goal_feet = goal + feet_offset
	var goal_tile_x = floor(goal_feet.x / TILE_SIZE)
	var goal_tile_y = floor(goal_feet.y / TILE_SIZE)
	var goal_tile_center = Vector2(goal_tile_x * TILE_SIZE + TILE_SIZE/2, goal_tile_y * TILE_SIZE + TILE_SIZE/2)
	if is_enemy:
		if not is_walkable_for_actor(goal_feet, start + feet_offset, inside_building, true, true):
			return []
	else:
		if not is_walkable_for_player(goal_tile_center, start):
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
		
		# Check all neighbors (4 directions)
		var neighbors = get_neighbors_world(current)
		for neighbor in neighbors:
			if neighbor in closed_set:
				continue
			
			# Check walkability (apply feet offset)
			var feet_position = neighbor + feet_offset
			var tile_x = floor(feet_position.x / TILE_SIZE)
			var tile_y = floor(feet_position.y / TILE_SIZE)
			var tile_center = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			
			if is_enemy:
				if not is_walkable_for_actor(feet_position, current + feet_offset, inside_building, true, true):
					continue
			else:
				if not is_walkable_for_player(tile_center, current):
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
				# Use straight heuristic without bonuses for most direct paths
				f_score[neighbor] = tentative_g + heuristic(neighbor, goal)
				
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	# No path found
	return []

func get_neighbors_world(tile_center: Vector2) -> Array:
	"""Get the 4 neighboring tiles (cardinal only)"""
	var neighbors = []
	var tile_x = floor(tile_center.x / TILE_SIZE)
	var tile_y = floor(tile_center.y / TILE_SIZE)
	
	var directions = [
		Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)
	]
	
	for dir in directions:
		var neighbor_x = tile_x + dir.x
		var neighbor_y = tile_y + dir.y
		var neighbor_center = Vector2(neighbor_x * TILE_SIZE + TILE_SIZE/2, neighbor_y * TILE_SIZE + TILE_SIZE/2)
		neighbors.append(neighbor_center)
	
	return neighbors

func heuristic(a: Vector2, b: Vector2) -> float:
	"""Heuristic for A* (Manhattan distance for 4-directional movement)"""
	var dx = abs(a.x - b.x) / TILE_SIZE
	var dy = abs(a.y - b.y) / TILE_SIZE
	return (dx + dy) * TILE_SIZE

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