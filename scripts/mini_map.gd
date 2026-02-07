extends Control

# Mini-map that displays a small view of the world around the player

const TILE_SIZE = 32
const PIXEL_PER_TILE = 3  # How many pixels each tile takes on the mini-map
const DISCOVERY_RADIUS = 7  # How close player needs to be to discover a tile

var player = null
var world = null
var orcs = []
var map_size = 150  # Will be set based on container size
var view_radius = 16  # Will be calculated based on viewport size
var tiles_horizontal = 16  # Horizontal tile count
var tiles_vertical = 16  # Vertical tile count

# Fog of war - tracks discovered tiles
var discovered_tiles = {}  # Dictionary with tile coords as keys

# Colors for the mini-map
var color_grass = Color(0.4, 0.6, 0.3)
var color_dirt = Color(139.0/255.0, 90.0/255.0, 43.0/255.0)
var color_sand = Color(194.0/255.0, 178.0/255.0, 128.0/255.0)
var color_water = Color(0.2, 0.4, 0.7)
var color_road = Color(0.55, 0.4, 0.2)
var color_player = Color(1.0, 1.0, 0.0)  # Yellow
var color_enemy = Color(1.0, 0.2, 0.2)  # Red
var color_fog = Color(0.05, 0.05, 0.05)  # Nearly black for undiscovered
var color_discovered_dim = 0.6  # Multiply color by this for discovered but not currently visible
var color_building = Color(0.35, 0.25, 0.2)

func _ready():
	# Find player and world references
	var root = get_tree().get_root()
	player = root.find_child("Player", true, false)
	world = root.find_child("World", true, false)
	
	# Calculate view radius based on viewport size and camera zoom
	var viewport_size = get_viewport_rect().size
	var camera_zoom = 1.0
	if player != null and player.has_node("Camera2D"):
		camera_zoom = player.get_node("Camera2D").zoom.x
	
	tiles_horizontal = int((viewport_size.x / camera_zoom) / TILE_SIZE / 2) - 1
	tiles_vertical = int((viewport_size.y / camera_zoom) / TILE_SIZE / 2) - 1
	view_radius = int(max(tiles_horizontal, tiles_vertical))
	
	# Redraw frequently to update positions
	set_process(true)

func _process(_delta):
	# Update discovered tiles based on player position
	if player != null:
		var player_tile_x = int(floor(player.position.x / TILE_SIZE))
		var player_tile_y = int(floor(player.position.y / TILE_SIZE))
		
		# Discover tiles within the rectangular viewport (everything visible on screen)
		for dy in range(-tiles_vertical, tiles_vertical + 1):
			for dx in range(-tiles_horizontal, tiles_horizontal + 1):
				var tile_x = player_tile_x + dx
				var tile_y = player_tile_y + dy
				
				var tile_key = Vector2(tile_x, tile_y)
				if not discovered_tiles.has(tile_key):
					discovered_tiles[tile_key] = true
	
	queue_redraw()

func _draw():
	# Update map size based on current control size
	map_size = int(min(size.x, size.y))
	
	if player == null or world == null:
		return
	
	# Get player's tile position
	var player_tile_x = int(floor(player.position.x / TILE_SIZE))
	var player_tile_y = int(floor(player.position.y / TILE_SIZE))
	
	# Draw terrain tiles around player
	for dy in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			var tile_x = player_tile_x + dx
			var tile_y = player_tile_y + dy
			var tile_key = Vector2(tile_x, tile_y)
			
			# Calculate position on mini-map (centered)
			var map_x = (map_size / 2) + (dx * PIXEL_PER_TILE) - PIXEL_PER_TILE / 2
			var map_y = (map_size / 2) + (dy * PIXEL_PER_TILE) - PIXEL_PER_TILE / 2
			
			# Check if tile has been discovered
			if discovered_tiles.has(tile_key):
				# Use the world render terrain so minimap matches visible tiles.
				var terrain_type = "grass"
				if world != null and world.has_method("get_render_terrain_type"):
					terrain_type = world.get_render_terrain_type(tile_x, tile_y)
				elif world != null and world.has_method("get_terrain_type_from_noise"):
					terrain_type = world.get_terrain_type_from_noise(tile_x, tile_y)
				
				# Choose color based on terrain, with sand override near water.
				var tile_color = color_grass
				if terrain_type == "water":
					tile_color = color_water
				elif terrain_type == "dirt":
					tile_color = color_road
				elif terrain_type == "grass":
					tile_color = color_grass
				elif terrain_type == "sand":
					tile_color = color_sand
				
				# Draw the tile
				draw_rect(Rect2(map_x, map_y, PIXEL_PER_TILE, PIXEL_PER_TILE), tile_color)
			else:
				# Not discovered yet - draw fog
				draw_rect(Rect2(map_x, map_y, PIXEL_PER_TILE, PIXEL_PER_TILE), color_fog)

	# Draw buildings on top of terrain (only if discovered)
	if world != null and world.has_method("get_building_zones"):
		var zones = world.get_building_zones()
		for entry in zones:
			if not entry.has("rect"):
				continue
			var rect: Rect2i = entry["rect"]
			var start_x = max(rect.position.x, player_tile_x - view_radius)
			var end_x = min(rect.position.x + rect.size.x - 1, player_tile_x + view_radius)
			var start_y = max(rect.position.y, player_tile_y - view_radius)
			var end_y = min(rect.position.y + rect.size.y - 1, player_tile_y + view_radius)
			if end_x < start_x or end_y < start_y:
				continue
			for y in range(start_y, end_y + 1):
				for x in range(start_x, end_x + 1):
					var tile_key = Vector2(x, y)
					if not discovered_tiles.has(tile_key):
						continue
					var dx = x - player_tile_x
					var dy = y - player_tile_y
					var map_x = (map_size / 2) + (dx * PIXEL_PER_TILE) - PIXEL_PER_TILE / 2
					var map_y = (map_size / 2) + (dy * PIXEL_PER_TILE) - PIXEL_PER_TILE / 2
					draw_rect(Rect2(map_x, map_y, PIXEL_PER_TILE, PIXEL_PER_TILE), color_building)
	
	# Draw player at center (always on top)
	var player_x = map_size / 2
	var player_y = map_size / 2
	draw_circle(Vector2(player_x, player_y), PIXEL_PER_TILE, color_player)
