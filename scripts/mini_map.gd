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
var color_stone = Color(0.5, 0.5, 0.5)
var color_water = Color(0.2, 0.4, 0.7)
var color_player = Color(1.0, 1.0, 0.0)  # Yellow
var color_enemy = Color(1.0, 0.2, 0.2)  # Red
var color_fog = Color(0.05, 0.05, 0.05)  # Nearly black for undiscovered
var color_discovered_dim = 0.6  # Multiply color by this for discovered but not currently visible

func _ready():
	# Find player and world references
	var root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
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
					# Store terrain type when discovered
					var terrain_type = "grass"
					if world != null and world.has_method("get_terrain_type_from_noise"):
						terrain_type = world.get_terrain_type_from_noise(tile_x, tile_y)
					discovered_tiles[tile_key] = terrain_type
	
	# Update orc list
	orcs.clear()
	var root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	for child in root.get_children():
		if child.is_class("CharacterBody2D") and child != player and child.has_method("perform_attack"):
			orcs.append(child)
	
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
				var terrain_type = discovered_tiles[tile_key]
				
				# Choose color based on terrain
				var tile_color = color_grass
				if terrain_type == "water":
					tile_color = color_water
				elif terrain_type == "stone":
					tile_color = color_stone
				
				# Draw the tile
				draw_rect(Rect2(map_x, map_y, PIXEL_PER_TILE, PIXEL_PER_TILE), tile_color)
			else:
				# Not discovered yet - draw fog
				draw_rect(Rect2(map_x, map_y, PIXEL_PER_TILE, PIXEL_PER_TILE), color_fog)
	
	# Draw player at center (always on top)
	var player_x = map_size / 2
	var player_y = map_size / 2
	draw_circle(Vector2(player_x, player_y), PIXEL_PER_TILE, color_player)
