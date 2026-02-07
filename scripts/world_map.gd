extends Control

const TILE_SIZE = 32

@export var pixel_per_tile = 2
@export var map_margin = 24
@export var max_view_radius = 250

var player = null
var world = null
var discovered_tiles = {}

var tiles_horizontal = 16
var tiles_vertical = 16

# Colors for the world map
var color_grass = Color(0.4, 0.6, 0.3)
var color_dirt = Color(139.0 / 255.0, 90.0 / 255.0, 43.0 / 255.0)
var color_sand = Color(194.0 / 255.0, 178.0 / 255.0, 128.0 / 255.0)
var color_water = Color(0.2, 0.4, 0.7)
var color_road = Color(0.55, 0.4, 0.2)
var color_player = Color(1.0, 1.0, 0.0)
var color_fog = Color(0.05, 0.05, 0.05)
var color_building = Color(0.35, 0.25, 0.2)
var color_background = Color(0.02, 0.02, 0.02, 0.8)
var color_frame = Color(0.7, 0.65, 0.55, 0.9)

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	
	var root = get_tree().get_root()
	player = root.find_child("Player", true, false)
	world = root.find_child("World", true, false)
	if world != null:
		if world.has_meta("discovered_tiles"):
			discovered_tiles = world.get_meta("discovered_tiles")
		else:
			world.set_meta("discovered_tiles", discovered_tiles)
	update_view_window()

func toggle():
	visible = not visible
	set_process(visible)
	if visible:
		update_view_window()
		queue_redraw()

func _process(_delta):
	if not visible:
		return
	update_discovered_tiles()
	queue_redraw()

func update_view_window():
	var viewport_size = get_viewport_rect().size
	var camera_zoom = 1.0
	if player != null and player.has_node("Camera2D"):
		camera_zoom = player.get_node("Camera2D").zoom.x
	
	tiles_horizontal = int((viewport_size.x / camera_zoom) / TILE_SIZE / 2) - 1
	tiles_vertical = int((viewport_size.y / camera_zoom) / TILE_SIZE / 2) - 1

func update_discovered_tiles():
	if player == null:
		return
	var player_tile_x = int(floor(player.position.x / TILE_SIZE))
	var player_tile_y = int(floor(player.position.y / TILE_SIZE))
	for dy in range(-tiles_vertical, tiles_vertical + 1):
		for dx in range(-tiles_horizontal, tiles_horizontal + 1):
			var tile_x = player_tile_x + dx
			var tile_y = player_tile_y + dy
			var tile_key = Vector2(tile_x, tile_y)
			if not discovered_tiles.has(tile_key):
				discovered_tiles[tile_key] = true

func _draw():
	if not visible:
		return
	if player == null or world == null:
		return
	
	draw_rect(Rect2(Vector2.ZERO, size), color_background)
	
	var map_size = int(min(size.x, size.y) - map_margin * 2)
	if map_size <= 0:
		return
	var map_origin = Vector2((size.x - map_size) / 2.0, (size.y - map_size) / 2.0)
	var view_radius = int(floor(map_size / (2.0 * pixel_per_tile)))
	view_radius = min(view_radius, max_view_radius)
	
	var player_tile_x = int(floor(player.position.x / TILE_SIZE))
	var player_tile_y = int(floor(player.position.y / TILE_SIZE))
	
	for dy in range(-view_radius, view_radius + 1):
		for dx in range(-view_radius, view_radius + 1):
			var tile_x = player_tile_x + dx
			var tile_y = player_tile_y + dy
			var tile_key = Vector2(tile_x, tile_y)
			var map_x = map_origin.x + (map_size / 2) + (dx * pixel_per_tile) - pixel_per_tile / 2
			var map_y = map_origin.y + (map_size / 2) + (dy * pixel_per_tile) - pixel_per_tile / 2
			if discovered_tiles.has(tile_key):
				var terrain_type = "grass"
				if world.has_method("get_render_terrain_type"):
					terrain_type = world.get_render_terrain_type(tile_x, tile_y)
				elif world.has_method("get_terrain_type_from_noise"):
					terrain_type = world.get_terrain_type_from_noise(tile_x, tile_y)
				var tile_color = color_grass
				if terrain_type == "water":
					tile_color = color_water
				elif terrain_type == "dirt":
					tile_color = color_road
				elif terrain_type == "grass":
					tile_color = color_grass
				elif terrain_type == "sand":
					tile_color = color_sand
				draw_rect(Rect2(map_x, map_y, pixel_per_tile, pixel_per_tile), tile_color)
			else:
				draw_rect(Rect2(map_x, map_y, pixel_per_tile, pixel_per_tile), color_fog)
	
	if world.has_method("get_building_zones"):
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
					var map_x = map_origin.x + (map_size / 2) + (dx * pixel_per_tile) - pixel_per_tile / 2
					var map_y = map_origin.y + (map_size / 2) + (dy * pixel_per_tile) - pixel_per_tile / 2
					draw_rect(Rect2(map_x, map_y, pixel_per_tile, pixel_per_tile), color_building)
	
	var player_pos = map_origin + Vector2(map_size / 2, map_size / 2)
	draw_circle(player_pos, max(1.0, pixel_per_tile * 1.5), color_player)
	draw_rect(Rect2(map_origin, Vector2(map_size, map_size)), color_frame, false, 2.0)
