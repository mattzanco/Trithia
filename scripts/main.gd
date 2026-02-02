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
	print("About to call spawn_starting_orcs()")
	
	if debug:
		debug.store_line("About to spawn orcs")
		debug.flush()
	
	spawn_starting_orcs()
	print("spawn_starting_orcs() completed")
	
	# Start spawn timer for continuous spawning
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = 10.0  # Spawn every 10 seconds
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func spawn_starting_orcs():
	# Spawn 10 orcs at random spawn points around the world
	var player = $Player
	var world = $World
	
	# Wait for world to generate spawn points
	await get_tree().process_frame
	
	var available_spawns = world.get_available_spawn_points(player.position)
	var orcs_to_spawn = min(10, available_spawns.size())
	
	print("[SPAWN] Found ", available_spawns.size(), " available spawn points")
	print("[SPAWN] Spawning ", orcs_to_spawn, " orcs")
	
	for i in range(orcs_to_spawn):
		var spawn_pos = available_spawns[i]
		spawn_orc_at_spawn_point(spawn_pos)
		print("[SPAWN] Orc ", i + 1, " spawned at: ", spawn_pos)

func _on_spawn_timer_timeout():
	"""Periodically spawn orcs at available spawn points"""
	var player = get_node_or_null("Player")
	if player == null:
		return  # Player is dead, stop spawning
	
	var world = $World
	
	var available_spawns = world.get_available_spawn_points(player.position)
	
	# Spawn 1-3 orcs if spawn points are available
	if available_spawns.size() > 0:
		var num_to_spawn = min(randi_range(1, 3), available_spawns.size())
		for i in range(num_to_spawn):
			var random_index = randi_range(0, available_spawns.size() - 1)
			var spawn_pos = available_spawns[random_index]
			spawn_orc_at_spawn_point(spawn_pos)
			print("[SPAWN TIMER] Spawned orc at: ", spawn_pos)
			available_spawns.remove_at(random_index)

func spawn_orc_at_spawn_point(spawn_pos: Vector2):
	"""Spawn an orc at a specific spawn point"""
	var orc = ORC_SCENE.instantiate()
	orc.position = spawn_pos
	add_child(orc)
	print("[SPAWN_FUNC] Orc spawned at spawn point: ", spawn_pos)

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

