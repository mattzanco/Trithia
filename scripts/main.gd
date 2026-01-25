extends Node2D

# Main game scene

const TILE_SIZE = 32
const ORC_SCENE = preload("res://scenes/enemies/orc.tscn")

func _ready():
	print("Trithia game started!")
	print("Main node ready, about to wait for process frame")
	
	# Write debug to file
	var debug = FileAccess.open("res://debug_log.txt", FileAccess.WRITE)
	if debug:
		debug.store_line("Game started")
		debug.flush()
	
	await get_tree().process_frame  # Wait one frame for player to be ready
	print("About to call spawn_starting_orc()")
	
	if debug:
		debug.store_line("About to spawn orc")
		debug.flush()
	
	spawn_starting_orc()
	print("spawn_starting_orc() completed")

func spawn_starting_orc():
	# Spawn an orc at a random walkable location away from the player
	var player = $Player
	var world = $World
	var orc = ORC_SCENE.instantiate()
	
	var orc_position = Vector2.ZERO
	var attempts = 0
	var max_attempts = 100
	
	# Keep trying to spawn on a walkable tile
	while attempts < max_attempts:
		# Random position within reasonable distance
		var random_x = randi_range(-200, 200)
		var random_y = randi_range(-200, 200)
		var candidate_pos = player.position + Vector2(random_x, random_y)
		
		# Snap to tile center
		var tile_x = round(candidate_pos.x / TILE_SIZE)
		var tile_y = round(candidate_pos.y / TILE_SIZE)
		candidate_pos = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
		
		# Check if the feet tile (lower tile) is walkable
		var feet_tile = candidate_pos + Vector2(0, TILE_SIZE/2)
		if world.is_walkable(feet_tile) and candidate_pos.distance_to(player.position) > TILE_SIZE * 2:
			orc_position = candidate_pos
			break
		
		attempts += 1
	
	# If we couldn't find a valid spawn after 100 attempts, use a safe fallback
	if attempts >= max_attempts:
		orc_position = player.position + Vector2(0, 4 * TILE_SIZE)
	
	print("Spawning orc...")
	print("Player position: ", player.position)
	print("Orc position: ", orc_position)
	
	orc.position = orc_position
	# Add orc to Main node
	add_child(orc)
	# Index 0 = World, Index 1 = Player, so insert at index 2
	move_child(orc, 1)  # Insert between World (0) and Player (2)
	
	# Verify both are on grid
	var orc_grid_x = round(orc.position.x / TILE_SIZE)
	var orc_grid_y = round(orc.position.y / TILE_SIZE)
	var player_grid_x = round(player.position.x / TILE_SIZE)
	var player_grid_y = round(player.position.y / TILE_SIZE)
	print("Grid check - Player tile: (", player_grid_x, ", ", player_grid_y, ") at world pos ", player.position)
	print("Grid check - Orc tile: (", orc_grid_x, ", ", orc_grid_y, ") at world pos ", orc.position)
	print("Orc added to Main")

func _process(_delta):
	# Update depth sorting based on Y position
	update_depth_sorting()

func update_depth_sorting():
	# Get references to player and orc
	var player = get_node_or_null("Player")
	var orc = get_node_or_null("Orc")
	
	if player and orc:
		# Character with higher Y (lower on screen) should be behind
		# Character with lower Y (higher on screen) should be in front
		if player.position.y > orc.position.y:
			# Player is lower, orc should be in front
			# World=0, Orc=1, Player=2
			move_child(orc, 1)
			move_child(player, 2)
		else:
			# Orc is lower or same, player should be in front
			# World=0, Player=1, Orc=2
			move_child(player, 1)
			move_child(orc, 2)
