extends Node2D

# Procedural world generation for grid-based game

const TILE_SIZE = 32
const CHUNK_SIZE = 16  # 16x16 tiles per chunk
const RENDER_DISTANCE = 2  # How many chunks to render around player

var generated_chunks = {}  # Dictionary to track which chunks have been generated
var terrain_data = {}  # Dictionary to store terrain type at each tile position
var noise: FastNoiseLite

func _ready():
	# Initialize noise for procedural generation
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	
	print("World initialized with seed: ", noise.seed)

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
			
			# Determine terrain type and store it
			var terrain_type = "grass"  # Default
			var tile_color = Color(0.3, 0.6, 0.2)  # Green for grass
			
			if noise_val < -0.3:
				terrain_type = "water"
				tile_color = Color(0.2, 0.4, 0.8)  # Blue
			elif noise_val > 0.4:
				terrain_type = "stone"
				tile_color = Color(0.5, 0.5, 0.5)  # Gray
			
			# Store terrain type for collision detection
			var tile_world_pos = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			terrain_data[tile_world_pos] = terrain_type
			
			# Create a colored tile sprite based on terrain type
			var tile_sprite = Sprite2D.new()
			tile_sprite.position = tile_world_pos
			
			# Create a simple colored square
			var color_rect = ColorRect.new()
			color_rect.size = Vector2(TILE_SIZE, TILE_SIZE)
			color_rect.position = Vector2(-TILE_SIZE/2, -TILE_SIZE/2)
			color_rect.color = tile_color
			
			# DEBUG: Add border lines to visualize tile edges
			var border = Line2D.new()
			border.width = 1
			border.default_color = Color(0, 0, 0, 0.3)  # Semi-transparent black
			border.add_point(Vector2(-TILE_SIZE/2, -TILE_SIZE/2))  # Top-left
			border.add_point(Vector2(TILE_SIZE/2, -TILE_SIZE/2))   # Top-right
			border.add_point(Vector2(TILE_SIZE/2, TILE_SIZE/2))    # Bottom-right
			border.add_point(Vector2(-TILE_SIZE/2, TILE_SIZE/2))   # Bottom-left
			border.add_point(Vector2(-TILE_SIZE/2, -TILE_SIZE/2))  # Close the loop
			
			tile_sprite.add_child(color_rect)
			tile_sprite.add_child(border)
			add_child(tile_sprite)

func is_walkable(world_position: Vector2) -> bool:
	# Check if the given world position is walkable
	if terrain_data.has(world_position):
		var terrain = terrain_data[world_position]
		return terrain != "water"  # Can walk on grass and stone, but not water
	return true  # Default to walkable if not yet generated
