extends Node2D

# Main game scene

const TILE_SIZE = 32
const ORC_SCENE = preload("res://scenes/enemies/orc.tscn")
const TROLL_SCENE = preload("res://scenes/enemies/troll.tscn")

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
	# Spawn 10 enemies at random spawn points around the world
	var player = $Player
	var world = $World
	
	# Wait for world to generate spawn points
	await get_tree().process_frame
	
	var available_spawns = world.get_available_spawn_points(player.position)
	var enemies_to_spawn = min(10, available_spawns.size())
	
	print("[SPAWN] Found ", available_spawns.size(), " available spawn points")
	print("[SPAWN] Spawning ", enemies_to_spawn, " enemies")
	
	for i in range(enemies_to_spawn):
		var spawn_pos = available_spawns[i]
		spawn_enemy_at_spawn_point(spawn_pos)
		print("[SPAWN] Enemy ", i + 1, " spawned at: ", spawn_pos)

func _on_spawn_timer_timeout():
	"""Periodically spawn orcs at available spawn points"""
	var player = get_node_or_null("Player")
	if player == null:
		return  # Player is dead, stop spawning
	
	var world = $World
	
	var available_spawns = world.get_available_spawn_points(player.position)
	
	# Spawn 1-3 enemies if spawn points are available
	if available_spawns.size() > 0:
		var num_to_spawn = min(randi_range(1, 3), available_spawns.size())
		for i in range(num_to_spawn):
			var random_index = randi_range(0, available_spawns.size() - 1)
			var spawn_pos = available_spawns[random_index]
			spawn_enemy_at_spawn_point(spawn_pos)
			print("[SPAWN TIMER] Spawned enemy at: ", spawn_pos)
			available_spawns.remove_at(random_index)

func spawn_enemy_at_spawn_point(spawn_pos: Vector2):
	"""Spawn an enemy at a specific spawn point"""
	var scene = ORC_SCENE if randi_range(0, 99) < 75 else TROLL_SCENE
	var enemy = scene.instantiate()
	enemy.position = spawn_pos
	add_child(enemy)
	print("[SPAWN_FUNC] Enemy spawned at spawn point: ", spawn_pos)

func _process(_delta):
	# Update depth sorting based on Y position
	update_depth_sorting()

func update_depth_sorting():
	# Get references to player
	var player = get_node_or_null("Player")
	
	if player:
		if get_child_count() < 2:
			return
		# Get all enemy children
		var enemies = []
		for child in get_children():
			if child.is_in_group("enemies"):
				enemies.append(child)
		
		# Sort all enemies based on Y position relative to player
		for enemy in enemies:
			if enemy and enemy.get_parent() == self and player.get_parent() == self:
				# Character with higher Y (lower on screen) should be behind
				# Character with lower Y (higher on screen) should be in front
				var back_index = min(1, get_child_count() - 1)
				var front_index = min(2, get_child_count() - 1)
				if player.position.y > enemy.position.y:
					# Player is lower, enemy should be in front
					move_child(enemy, back_index)
					move_child(player, front_index)
				else:
					# Enemy is lower or same, player should be in front
					move_child(player, back_index)
					move_child(enemy, front_index)


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

