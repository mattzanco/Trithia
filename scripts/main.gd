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
	
	spawn_starting_orcs()
	print("spawn_starting_orcs() completed")

func spawn_starting_orcs():
	# Spawn two orcs at random walkable locations away from the player
	var player = $Player
	var world = $World
	var occupied_positions = []  # Track orc positions to prevent overlap
	
	var first_orc_pos = spawn_orc_at_position(player, world, Vector2.ZERO, 100, occupied_positions)
	occupied_positions.append(first_orc_pos)
	print("[SPAWN] First orc final position: ", first_orc_pos)
	
	# Spawn second orc nearby the first one
	print("[SPAWN] Spawning second orc near: ", first_orc_pos)
	var second_orc_pos = spawn_orc_at_position(player, world, first_orc_pos, 100, occupied_positions)
	print("[SPAWN] Second orc final position: ", second_orc_pos)

func spawn_orc_at_position(player: Node2D, world: Node2D, near_position: Vector2, max_attempts: int, occupied_positions: Array) -> Vector2:
	var orc = ORC_SCENE.instantiate()
	var orc_position = Vector2.ZERO
	var attempts = 0
	var min_spacing = TILE_SIZE * 2  # Minimum distance between orcs
	
	print("[SPAWN_FUNC] Starting spawn with near_position: ", near_position, ", is_first_orc: ", near_position == Vector2.ZERO)
	
	# Keep trying to spawn on a walkable tile
	while attempts < max_attempts:
		# If near_position is Vector2.ZERO, spawn relative to player
		# Otherwise spawn near the given position (for nearby spawns)
		var base_pos = player.position if near_position == Vector2.ZERO else near_position
		var spawn_range = 150 if near_position == Vector2.ZERO else 100
		
		var random_x = randi_range(-spawn_range, spawn_range)
		var random_y = randi_range(-spawn_range, spawn_range)
		var candidate_pos = base_pos + Vector2(random_x, random_y)
		
		# Snap to tile center
		var tile_x = round(candidate_pos.x / TILE_SIZE)
		var tile_y = round(candidate_pos.y / TILE_SIZE)
		candidate_pos = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
		
		# Check if the feet tile (lower tile) is walkable
		var feet_position = candidate_pos + Vector2(0, TILE_SIZE/2)
		# Snap to tile center for walkability check
		var feet_tile_x = round(feet_position.x / TILE_SIZE)
		var feet_tile_y = round(feet_position.y / TILE_SIZE)
		var feet_tile = Vector2(feet_tile_x * TILE_SIZE + TILE_SIZE/2, feet_tile_y * TILE_SIZE + TILE_SIZE/2)
		
		# Check distance from player and all other orcs
		var too_close_to_player = candidate_pos.distance_to(player.position) <= TILE_SIZE * 2
		var too_close_to_orc = false
		
		for occupied_pos in occupied_positions:
			if candidate_pos.distance_to(occupied_pos) < min_spacing:
				too_close_to_orc = true
				break
		
		if world.is_walkable(feet_tile) and not too_close_to_player and not too_close_to_orc:
			orc_position = candidate_pos
			break
		
		attempts += 1
	
	# If we couldn't find a valid spawn after max_attempts, use a safe fallback
	if attempts >= max_attempts:
		var fallback_found = false
		
		# Try to find a walkable fallback position
		if near_position == Vector2.ZERO:
			# First orc: try positions around player
			for offset_x in [-4, -3, -2, 2, 3, 4, 0]:
				for offset_y in [3, 4, 5, -3, -4, -5]:
					var fallback_candidate = player.position + Vector2(offset_x * TILE_SIZE, offset_y * TILE_SIZE)
					# Snap to tile center
					var tile_x = round(fallback_candidate.x / TILE_SIZE)
					var tile_y = round(fallback_candidate.y / TILE_SIZE)
					fallback_candidate = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
					var fallback_feet = fallback_candidate + Vector2(0, TILE_SIZE/2)
					# Snap feet to tile center for walkability check
					var feet_tile_x = round(fallback_feet.x / TILE_SIZE)
					var feet_tile_y = round(fallback_feet.y / TILE_SIZE)
					var feet_tile = Vector2(feet_tile_x * TILE_SIZE + TILE_SIZE/2, feet_tile_y * TILE_SIZE + TILE_SIZE/2)
					if world.is_walkable(feet_tile) and fallback_candidate.distance_to(player.position) > TILE_SIZE * 2:
						orc_position = fallback_candidate
						fallback_found = true
						print("[SPAWN] Using fallback position for first orc: ", orc_position)
						break
				if fallback_found:
					break
		else:
			# Second orc: try positions around first orc
			for offset_x in [-3, -2, 2, 3, -1, 1, 0]:
				for offset_y in [2, 3, -2, -3, -1, 1, 0]:
					var fallback_candidate = near_position + Vector2(offset_x * TILE_SIZE, offset_y * TILE_SIZE)
					# Snap to tile center
					var tile_x = round(fallback_candidate.x / TILE_SIZE)
					var tile_y = round(fallback_candidate.y / TILE_SIZE)
					fallback_candidate = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
					var fallback_feet = fallback_candidate + Vector2(0, TILE_SIZE/2)
					# Snap feet to tile center for walkability check
					var feet_tile_x = round(fallback_feet.x / TILE_SIZE)
					var feet_tile_y = round(fallback_feet.y / TILE_SIZE)
					var feet_tile = Vector2(feet_tile_x * TILE_SIZE + TILE_SIZE/2, feet_tile_y * TILE_SIZE + TILE_SIZE/2)
					var too_close_to_player = fallback_candidate.distance_to(player.position) <= TILE_SIZE * 2
					var too_close_to_other = false
					for occupied_pos in occupied_positions:
						if fallback_candidate.distance_to(occupied_pos) < TILE_SIZE * 2:
							too_close_to_other = true
							break
					
					if world.is_walkable(feet_tile) and not too_close_to_player and not too_close_to_other:
						orc_position = fallback_candidate
						fallback_found = true
						print("[SPAWN] Using fallback position for second orc: ", orc_position)
						break
				if fallback_found:
					break
		
		# If still no valid fallback found, use the first valid position we can find
		if not fallback_found:
			orc_position = player.position + Vector2(0, 4 * TILE_SIZE)
			print("[SPAWN] No valid fallback found, using final fallback: ", orc_position)
	
	print("Spawning orc...")
	print("Player position: ", player.position)
	print("Orc position: ", orc_position)
	
	orc.position = orc_position
	# Add orc to Main node
	add_child(orc)
	# Insert between World (0) and Player (1)
	move_child(orc, 1)
	
	# Verify orc is on grid
	var orc_grid_x = round(orc.position.x / TILE_SIZE)
	var orc_grid_y = round(orc.position.y / TILE_SIZE)
	var player_grid_x = round(player.position.x / TILE_SIZE)
	var player_grid_y = round(player.position.y / TILE_SIZE)
	print("Grid check - Player tile: (", player_grid_x, ", ", player_grid_y, ") at world pos ", player.position)
	print("Grid check - Orc tile: (", orc_grid_x, ", ", orc_grid_y, ") at world pos ", orc.position)
	print("Orc added to Main")
	
	return orc.position  # Return the actual snapped position of the orc

func _process(_delta):
	# Update depth sorting based on Y position
	update_depth_sorting()

func update_depth_sorting():
	# Get references to player
	var player = get_node_or_null("Player")
	
	if player:
		# Get all orc children
		var orcs = []
		for child in get_children():
			if child.name == "Orc":
				orcs.append(child)
		
		# Sort all orcs based on Y position relative to player
		for orc in orcs:
			if orc:
				# Character with higher Y (lower on screen) should be behind
				# Character with lower Y (higher on screen) should be in front
				if player.position.y > orc.position.y:
					# Player is lower, orc should be in front
					move_child(orc, 1)
					move_child(player, 2)
				else:
					# Orc is lower or same, player should be in front
					move_child(player, 1)
					move_child(orc, 2)


func show_game_over():
	# Disable the camera so it stops following the player
	var player = get_node_or_null("Player")
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

