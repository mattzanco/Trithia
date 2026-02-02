extends Node

# Utility script to generate terrain tile textures
# Run this once to create the dirt and sand PNG files

const TILE_SIZE = 32

func _ready():
	generate_dirt_texture()
	generate_sand_texture()
	print("Terrain textures generated successfully!")
	# Auto-quit after generation
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func generate_dirt_texture():
	var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	
	# Base dirt color
	var base_color = Color(139.0/255.0, 90.0/255.0, 43.0/255.0)
	
	# Fill with base color
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(x, y, base_color)
	
	# Add random darker spots (pebbles/rocks)
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistency
	
	for i in range(25):
		var spot_x = rng.randi_range(0, TILE_SIZE - 1)
		var spot_y = rng.randi_range(0, TILE_SIZE - 1)
		var spot_size = rng.randi_range(1, 2)
		var spot_color = Color(100.0/255.0, 60.0/255.0, 30.0/255.0)
		
		# Draw spot
		for dy in range(-spot_size, spot_size + 1):
			for dx in range(-spot_size, spot_size + 1):
				var px = spot_x + dx
				var py = spot_y + dy
				if px >= 0 and px < TILE_SIZE and py >= 0 and py < TILE_SIZE:
					if dx * dx + dy * dy <= spot_size * spot_size:
						var current = img.get_pixel(px, py)
						img.set_pixel(px, py, current.lerp(spot_color, 0.5))
	
	# Add lighter highlights
	for i in range(15):
		var spot_x = rng.randi_range(0, TILE_SIZE - 1)
		var spot_y = rng.randi_range(0, TILE_SIZE - 1)
		var spot_color = Color(160.0/255.0, 110.0/255.0, 60.0/255.0)
		
		if spot_x >= 0 and spot_x < TILE_SIZE and spot_y >= 0 and spot_y < TILE_SIZE:
			var current = img.get_pixel(spot_x, spot_y)
			img.set_pixel(spot_x, spot_y, current.lerp(spot_color, 0.3))
	
	# Save the image
	var error = img.save_png("res://assets/sprites/dirt_tile.png")
	if error == OK:
		print("Dirt texture saved successfully")
	else:
		print("Error saving dirt texture: ", error)

func generate_sand_texture():
	var img = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	
	# Base sand color
	var base_color = Color(194.0/255.0, 178.0/255.0, 128.0/255.0)
	
	# Fill with base color
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(x, y, base_color)
	
	# Add random variation for sand grains
	var rng = RandomNumberGenerator.new()
	rng.seed = 54321  # Different seed for different pattern
	
	# Add darker sand grains
	for i in range(35):
		var spot_x = rng.randi_range(0, TILE_SIZE - 1)
		var spot_y = rng.randi_range(0, TILE_SIZE - 1)
		var spot_color = Color(170.0/255.0, 150.0/255.0, 100.0/255.0)
		
		if spot_x >= 0 and spot_x < TILE_SIZE and spot_y >= 0 and spot_y < TILE_SIZE:
			var current = img.get_pixel(spot_x, spot_y)
			img.set_pixel(spot_x, spot_y, current.lerp(spot_color, 0.4))
	
	# Add lighter sand highlights
	for i in range(30):
		var spot_x = rng.randi_range(0, TILE_SIZE - 1)
		var spot_y = rng.randi_range(0, TILE_SIZE - 1)
		var spot_color = Color(210.0/255.0, 195.0/255.0, 150.0/255.0)
		
		if spot_x >= 0 and spot_x < TILE_SIZE and spot_y >= 0 and spot_y < TILE_SIZE:
			var current = img.get_pixel(spot_x, spot_y)
			img.set_pixel(spot_x, spot_y, current.lerp(spot_color, 0.3))
	
	# Add subtle noise for texture
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			var noise_val = rng.randf_range(-0.05, 0.05)
			var current = img.get_pixel(x, y)
			var r = clamp(current.r + noise_val, 0.0, 1.0)
			var g = clamp(current.g + noise_val, 0.0, 1.0)
			var b = clamp(current.b + noise_val, 0.0, 1.0)
			img.set_pixel(x, y, Color(r, g, b, 1.0))
	
	# Save the image
	var error = img.save_png("res://assets/sprites/sand_tile.png")
	if error == OK:
		print("Sand texture saved successfully")
	else:
		print("Error saving sand texture: ", error)
