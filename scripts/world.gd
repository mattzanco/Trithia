extends Node2D

# Procedural world generation for grid-based game

const TILE_SIZE = 32
const CHUNK_SIZE = 16  # 16x16 tiles per chunk
const RENDER_DISTANCE = 2  # How many chunks to render around player

var generated_chunks = {}  # Dictionary to track which chunks have been generated
var terrain_data = {}  # Dictionary to store terrain type at each tile position
var noise: FastNoiseLite
var last_drawn_count = 0

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
	# Redraw if terrain data changed
	if terrain_data.size() != last_drawn_count:
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
		var tile_rect = Rect2(tile_x, tile_y, TILE_SIZE, TILE_SIZE)
		
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
	if terrain_data.has(world_position):
		var terrain = terrain_data[world_position]
		return terrain != "water"  # Can walk on grass and stone, but not water
	return true  # Default to walkable if not yet generated
