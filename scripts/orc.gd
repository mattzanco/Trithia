extends CharacterBody2D

# Orc enemy controller

const TILE_SIZE = 32
const MOVE_SPEED = 100.0  # Pixels per second
const WALK_DISTANCE = 3  # How many tiles to walk before changing direction
const COLLISION_RADIUS = 10.0  # Distance to check for collisions

var animated_sprite: AnimatedSprite2D
var current_direction = Vector2.DOWN

# Movement variables
var is_moving = false
var target_position = Vector2.ZERO
var move_timer = 0.0
var direction_change_timer = 0.0
var patrol_direction = Vector2.ZERO
var player = null
var world = null
var chase_update_interval = 1.0  # Update chase path every 1.0 seconds (reduced from 0.6 to avoid stuttering)
var patrol_update_interval = 2.0  # Update patrol direction every 2 seconds
var path_queue = []  # Queue of positions to move through (like player)
var last_player_position = Vector2.ZERO  # Track player position for smart path updates
var last_path_direction = Vector2.ZERO  # Track direction to avoid flashing during movement
var last_fallback_direction = Vector2.ZERO  # Track last fallback diagonal direction
var move_direction = Vector2.DOWN  # Direction to move on current step
var chase_path_timer = 0.0  # Timer for recalculating chase path
var last_move_time = 0.0  # Track when orc last started moving (prevent oscillation)

# Stuck detection system
var last_tile_position = Vector2.ZERO  # Track which tile orc is currently on
var tile_stuck_timer = 0.0  # How long orc has been on current tile
var max_tile_stuck_time = 0.5  # Max seconds to stay on same tile (roughly 2 movement intervals)

# Pathfinding stagger to prevent all orcs from pathfinding in same frame
var pathfind_stagger = 0.0  # Offset to stagger pathfinding calls

# Health system
var max_health = 50
var current_health = 50
var health_bar = null

# Stats system
var max_mp = 25
var current_mp = 25
var strength = 8
var intelligence = 6
var dexterity = 7
var speed = 5

# Targeting system
var is_targeted = false

# Combat system
var targeted_enemy = null
var attack_cooldown = 2.0  # Orc attacks slower than player
var attack_timer = 0.0
var detection_range = TILE_SIZE * 10  # Can detect player from 10 tiles away

func _ready():
	# Get the AnimatedSprite2D node
	animated_sprite = $AnimatedSprite2D
	
	if animated_sprite == null:
		return
	
	# Get reference to the player and world for collision detection
	var parent = get_parent()
	if parent:
		player = parent.find_child("Player", true, false)
		world = parent.find_child("World", true, false)
	else:
		return
	
	# Create animated sprite with walking animations
	create_orc_animations()
	
	# Position sprite offset so feet are lower in the tile
	animated_sprite.offset = Vector2(0, 8)
	
	# Snap to nearest tile center
	position = Vector2(
		round(position.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE/2,
		round(position.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE/2
	)
	
	target_position = position
	
	# Set random facing direction
	var directions = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
	var direction_names = ["down", "up", "left", "right"]
	var random_index = randi() % directions.size()
	current_direction = directions[random_index]
	
	# Start with idle animation for the random direction
	if animated_sprite.sprite_frames != null:
		animated_sprite.play("idle_" + direction_names[random_index])
	
	# Initialize targeted_enemy to the player
	targeted_enemy = null  # Will be set when detecting player
	
	# Setup pathfinding stagger to prevent all orcs from pathfinding simultaneously
	# Use object ID to deterministically stagger each orc differently
	pathfind_stagger = (get_instance_id() % 10) * 0.06  # Spread across 0.6 seconds
	
	# Setup health and health bar
	current_health = max_health
	set_meta("max_health", max_health)
	set_meta("current_health", current_health)
	
	# Create health bar
	var health_bar_scene = preload("res://scenes/health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	
	# Setup stats
	current_mp = max_mp
	set_meta("max_mp", max_mp)
	set_meta("current_mp", current_mp)
	set_meta("strength", strength)
	set_meta("intelligence", intelligence)
	set_meta("dexterity", dexterity)
	set_meta("speed", speed)

func create_orc_animations():
	var sprite_frames = SpriteFrames.new()
	
	# Create animations for all directions
	create_direction_animations(sprite_frames, "down", Vector2.DOWN)
	create_direction_animations(sprite_frames, "up", Vector2.UP)
	create_direction_animations(sprite_frames, "left", Vector2.LEFT)
	create_direction_animations(sprite_frames, "right", Vector2.RIGHT)
	
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle_down")

func create_direction_animations(sprite_frames: SpriteFrames, dir_name: String, dir_vector: Vector2):
	# Create idle animation
	sprite_frames.add_animation("idle_" + dir_name)
	sprite_frames.set_animation_speed("idle_" + dir_name, 5.0)
	var idle_frame = create_orc_frame(dir_vector, 1)
	sprite_frames.add_frame("idle_" + dir_name, idle_frame)
	
	# Create walk animation (4 frames for smooth walk cycle)
	sprite_frames.add_animation("walk_" + dir_name)
	sprite_frames.set_animation_speed("walk_" + dir_name, 12.0)
	sprite_frames.set_animation_loop("walk_" + dir_name, true)
	
	for frame_num in range(4):
		var walk_frame = create_orc_frame(dir_vector, frame_num)
		sprite_frames.add_frame("walk_" + dir_name, walk_frame)

func create_orc_frame(direction: Vector2, frame: int) -> ImageTexture:
	var img = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	
	var green_skin = Color(0.4, 0.7, 0.4)
	var dark_green = Color(0.2, 0.5, 0.2)
	var hair = Color(0.3, 0.2, 0.1)
	var muscle_shadow = Color(0.25, 0.55, 0.25)
	var pants = Color(0.5, 0.4, 0.3)
	var outline = Color(0.1, 0.1, 0.1)
	var metal = Color(0.7, 0.7, 0.75)
	var handle = Color(0.4, 0.3, 0.2)
	
	if direction == Vector2.UP:
		draw_orc_back(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame)
	elif direction == Vector2.DOWN:
		draw_orc_front(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame)
	elif direction == Vector2.LEFT:
		draw_orc_side(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame, true)
	elif direction == Vector2.RIGHT:
		draw_orc_side(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame, false)
	
	var texture = ImageTexture.create_from_image(img)
	return texture

func draw_orc_front(img: Image, skin: Color, dark_skin: Color, hair: Color, muscle: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int):
	# Head (rows 12-23)
	for y in range(12, 24):
		for x in range(9, 23):
			img.set_pixel(x, y, skin)
		img.set_pixel(9, y, outline)
		img.set_pixel(22, y, outline)
	
	# Eyes (rows 16-18)
	for y in range(16, 19):
		img.set_pixel(12, y, outline)
		img.set_pixel(19, y, outline)
	
	# Tusks (rows 18-22)
	img.set_pixel(10, 19, outline)
	img.set_pixel(10, 20, outline)
	img.set_pixel(21, 19, outline)
	img.set_pixel(21, 20, outline)
	
	# Neck (rows 24-27)
	for y in range(24, 28):
		for x in range(11, 21):
			img.set_pixel(x, y, skin)
		img.set_pixel(11, y, outline)
		img.set_pixel(20, y, outline)
	
	# Bare muscular body (rows 28-40)
	for y in range(28, 41):
		for x in range(7, 25):
			img.set_pixel(x, y, skin)
		img.set_pixel(7, y, outline)
		img.set_pixel(24, y, outline)
	
	# Muscle definition (vertical straps)
	for y in range(28, 41):
		for x in range(14, 18):
			img.set_pixel(x, y, muscle)
	# Horizontal muscle lines
	for x in range(10, 22):
		img.set_pixel(x, 32, muscle)
		img.set_pixel(x, 36, muscle)
	
	# Arms with animation
	var left_arm_offset = 0
	var right_arm_offset = 0
	if walk_frame == 0:
		left_arm_offset = 0
		right_arm_offset = 0
	elif walk_frame == 1:
		left_arm_offset = -3
		right_arm_offset = 3
	elif walk_frame == 2:
		left_arm_offset = 0
		right_arm_offset = 0
	elif walk_frame == 3:
		left_arm_offset = 3
		right_arm_offset = -3
	
	# Left arm
	for y in range(max(30, 30 + left_arm_offset), min(40, 40 + left_arm_offset)):
		if y >= 0 and y < 64:
			for x in range(4, 8):
				img.set_pixel(x, y, skin)
			img.set_pixel(4, y, outline)
	
	# Right arm (holding weapon)
	for y in range(max(30, 30 + right_arm_offset), min(40, 40 + right_arm_offset)):
		if y >= 0 and y < 64:
			for x in range(24, 28):
				img.set_pixel(x, y, skin)
			img.set_pixel(27, y, outline)
	
	# Weapon in right hand
	var sword_offset = right_arm_offset
	# Handle
	for y in range(max(38, 38 + sword_offset), min(45, 45 + sword_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(27, y, handle)
	# Blade
	for y in range(max(20, 20 + sword_offset), min(38, 38 + sword_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(27, y, metal)
			if y < 37:
				img.set_pixel(28, y, metal)
	# Blade outline
	for y in range(max(20, 20 + sword_offset), min(38, 38 + sword_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(26, y, outline)
			img.set_pixel(27, y, outline)
	
	# Simple loincloth (rows 41-46)
	for y in range(41, 47):
		for x in range(9, 23):
			img.set_pixel(x, y, pants)
		img.set_pixel(9, y, outline)
		img.set_pixel(22, y, outline)
	
	# Legs with animation (rows 47-62)
	var left_leg_offset = 0
	var right_leg_offset = 0
	if walk_frame == 0:
		left_leg_offset = 0
		right_leg_offset = 0
	elif walk_frame == 1:
		left_leg_offset = 3
		right_leg_offset = -3
	elif walk_frame == 2:
		left_leg_offset = 0
		right_leg_offset = 0
	elif walk_frame == 3:
		left_leg_offset = -3
		right_leg_offset = 3
	
	# Left leg
	for x in range(9, 16):
		for y in range(47, 55):
			var pixel_y = y + left_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, skin)
		var foot_y = 55 + left_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for fy in range(foot_y, min(foot_y + 4, 64)):
				for fx in range(9, 15):
					img.set_pixel(fx, fy, outline)
	
	# Right leg
	for x in range(16, 23):
		for y in range(47, 55):
			var pixel_y = y + right_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, skin)
		var foot_y = 55 + right_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for fy in range(foot_y, min(foot_y + 4, 64)):
				for fx in range(16, 23):
					img.set_pixel(fx, fy, outline)
	
	# Leg outlines
	for y in range(max(47, 47 + left_leg_offset), min(63, 63 + left_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(8, y, outline)
	for y in range(max(47, 47 + right_leg_offset), min(63, 63 + right_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(23, y, outline)

func draw_orc_back(img: Image, skin: Color, dark_skin: Color, hair: Color, muscle: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int):
	# Back-facing orc (32x64)
	
	# Head - rows 12-23
	for y in range(12, 24):
		for x in range(9, 23):
			img.set_pixel(x, y, skin)
		img.set_pixel(8, y, outline)
		img.set_pixel(23, y, outline)
	
	# Back of head detail
	for y in range(14, 22):
		img.set_pixel(16, y, dark_skin)  # Center back stripe
	
	# Neck - rows 24-27
	for y in range(24, 28):
		for x in range(11, 21):
			img.set_pixel(x, y, skin)
		img.set_pixel(10, y, outline)
		img.set_pixel(21, y, outline)
	
	# Bare muscular body - rows 28-39
	for y in range(28, 40):
		for x in range(7, 25):
			img.set_pixel(x, y, skin)
		img.set_pixel(6, y, outline)
		img.set_pixel(25, y, outline)
	
	# Muscle definition
	for y in range(28, 40):
		img.set_pixel(14, y, muscle)
		img.set_pixel(17, y, muscle)
	for x in range(7, 25):
		img.set_pixel(x, 32, muscle)
		img.set_pixel(x, 36, muscle)
	
	# Arms with animation
	var left_arm_offset = 0
	var right_arm_offset = 0
	if walk_frame == 1:
		left_arm_offset = 4
		right_arm_offset = -4
	elif walk_frame == 3:
		left_arm_offset = -4
		right_arm_offset = 4
	
	for y in range(max(32, 32 + left_arm_offset), min(44, 44 + left_arm_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(6, y, skin)
			img.set_pixel(5, y, skin)
			img.set_pixel(4, y, outline)
	
	for y in range(max(32, 32 + right_arm_offset), min(44, 44 + right_arm_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(24, y, skin)
			img.set_pixel(25, y, skin)
			img.set_pixel(26, y, outline)
	
	# Loincloth - rows 40-47
	for y in range(40, 48):
		for x in range(9, 23):
			img.set_pixel(x, y, pants)
		img.set_pixel(8, y, outline)
		img.set_pixel(23, y, outline)
	
	# Legs with animation
	var left_leg_offset = 0
	var right_leg_offset = 0
	if walk_frame == 1:
		left_leg_offset = -4
		right_leg_offset = 4
	elif walk_frame == 3:
		left_leg_offset = 4
		right_leg_offset = -4
	
	# Left leg - rows 48-56
	for x in range(9, 16):
		for y in range(48, 56):
			var pixel_y = y + left_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, skin)
		var foot_y = 56 + left_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for foot_x in range(9, 16):
				for fy in range(foot_y, min(foot_y + 4, 64)):
					img.set_pixel(foot_x, fy, outline)
	
	# Right leg - rows 48-56
	for x in range(16, 23):
		for y in range(48, 56):
			var pixel_y = y + right_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, skin)
		var foot_y = 56 + right_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for foot_x in range(16, 23):
				for fy in range(foot_y, min(foot_y + 4, 64)):
					img.set_pixel(foot_x, fy, outline)
	
	# Leg outlines
	for y in range(max(48, 48 + left_leg_offset), min(60, 60 + left_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(8, y, outline)
	for y in range(max(48, 48 + right_leg_offset), min(60, 60 + right_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(22, y, outline)

func draw_orc_side(img: Image, skin: Color, dark_skin: Color, hair: Color, muscle: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int, flip_x: bool):
	# Side-facing orc (32x64)
	
	var base_x = 16  # Center of 32-pixel width
	var dir = 1 if not flip_x else -1
	
	# Head - rows 12-23
	for y in range(12, 24):
		for dx in range(14):
			var x = base_x + (dx - 6) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, skin)
		var outline_x1 = base_x + 8 * dir
		var outline_x2 = base_x - 6 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	
	# Eye - rows 18-21
	var eye_x = base_x + 6 * dir
	if eye_x >= 0 and eye_x < 32:
		for y in range(18, 22):
			img.set_pixel(eye_x, y, outline)
	
	# Tusk detail (simple protrusion)
	var tusk_x = base_x + 8 * dir
	if tusk_x >= 0 and tusk_x < 32:
		img.set_pixel(tusk_x, 19, outline)
		img.set_pixel(tusk_x, 20, outline)
	
	# Neck - rows 24-31
	for y in range(24, 32):
		for dx in range(10):
			var x = base_x + (dx - 4) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, skin)
		var outline_x1 = base_x + 6 * dir
		var outline_x2 = base_x - 4 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	
	# Bare muscular body - rows 32-47
	for y in range(32, 48):
		for dx in range(18):
			var x = base_x + (dx - 6) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, skin)
		var outline_x1 = base_x + 12 * dir
		var outline_x2 = base_x - 6 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	
	# Muscle definition
	for y in range(32, 48):
		var x = base_x + 4 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, muscle)
	for dx in range(14):
		var x = base_x + (dx - 4) * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, 34, muscle)
			img.set_pixel(x, 38, muscle)
	
	# Front arm with animation
	var front_arm_offset = 0
	if walk_frame == 1:
		front_arm_offset = -12
	elif walk_frame == 3:
		front_arm_offset = 12
	
	var arm_x = base_x + 10 * dir
	for y in range(max(36, 36 + front_arm_offset), min(48, 48 + front_arm_offset)):
		if y >= 0 and y < 64 and arm_x >= 0 and arm_x < 32:
			for dx in range(4):
				var x = arm_x + dx * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, y, skin)
			var outline_x = arm_x + 4 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, y, outline)
	
	# Weapon
	var sword_x = base_x + 14 * dir
	var sword_offset = 0
	if walk_frame == 1:
		sword_offset = -5
	elif walk_frame == 3:
		sword_offset = 5
	
	# Handle
	for y in range(max(44, 44 + sword_offset), min(50, 50 + sword_offset)):
		if y >= 0 and y < 64 and sword_x >= 0 and sword_x < 32:
			img.set_pixel(sword_x, y, handle)
	
	# Blade
	for y in range(max(26, 26 + sword_offset), min(44, 44 + sword_offset)):
		if y >= 0 and y < 64 and sword_x >= 0 and sword_x < 32:
			img.set_pixel(sword_x, y, metal)
			var blade_x2 = sword_x + dir
			if blade_x2 >= 0 and blade_x2 < 32 and y < 43:
				img.set_pixel(blade_x2, y, metal)
	
	# Blade outline
	var blade_outline_x = sword_x - dir
	for y in range(max(26, 26 + sword_offset), min(44, 44 + sword_offset)):
		if y >= 0 and y < 64 and blade_outline_x >= 0 and blade_outline_x < 32:
			img.set_pixel(blade_outline_x, y, outline)
	
	# Sword tip
	var tip_y = max(0, 24 + sword_offset)
	if tip_y >= 0 and tip_y < 64:
		if sword_x >= 0 and sword_x < 32:
			img.set_pixel(sword_x, tip_y, outline)
		var tip_x2 = sword_x + dir
		if tip_x2 >= 0 and tip_x2 < 32:
			img.set_pixel(tip_x2, tip_y, outline)
		var tip_outline_x = sword_x - dir
		if tip_outline_x >= 0 and tip_outline_x < 32:
			img.set_pixel(tip_outline_x, tip_y, outline)
	
	# Fill gap between tip and blade
	var gap_y = max(0, 25 + sword_offset)
	if gap_y >= 0 and gap_y < 64:
		if sword_x >= 0 and sword_x < 32:
			img.set_pixel(sword_x, gap_y, metal)
		var gap_x2 = sword_x + dir
		if gap_x2 >= 0 and gap_x2 < 32:
			img.set_pixel(gap_x2, gap_y, metal)
		var gap_outline_x = sword_x - dir
		if gap_outline_x >= 0 and gap_outline_x < 32:
			img.set_pixel(gap_outline_x, gap_y, outline)
	
	# Loincloth - rows 48-59
	for y in range(48, 60):
		for dx in range(14):
			var x = base_x + (dx - 4) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, pants)
		var outline_x1 = base_x + 10 * dir
		var outline_x2 = base_x - 4 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	
	# Legs with animation
	var front_leg_offset = 0
	var back_leg_offset = 0
	
	if walk_frame == 0:
		front_leg_offset = 0
		back_leg_offset = 0
	elif walk_frame == 1:
		front_leg_offset = 8
		back_leg_offset = -8
	elif walk_frame == 2:
		front_leg_offset = 0
		back_leg_offset = 0
	elif walk_frame == 3:
		front_leg_offset = -8
		back_leg_offset = 8
	
	# Back leg
	for y in range(60, 64):
		var pixel_y = y + back_leg_offset
		if pixel_y >= 0 and pixel_y < 64:
			for dx in range(6):
				var x = base_x + (dx - 5) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, pixel_y, skin)
			var outline_x = base_x - 5 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, pixel_y, outline)
	
	# Front leg
	for y in range(max(55, 55 + front_leg_offset), min(64, 64 + front_leg_offset)):
		if y >= 0 and y < 64:
			for dx in range(7):
				var x = base_x + (dx - 1) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, y, skin)
			var outline_x = base_x + 6 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, y, outline)

func _physics_process(delta):
	# Update timers
	direction_change_timer += delta
	chase_path_timer += delta
	
	# Handle attack cooldown
	if attack_timer > 0.0:
		attack_timer -= delta
	
	# Check if player is in detection range
	var player_just_detected = false
	if player != null:
		var distance_to_player = position.distance_to(player.position)
		if targeted_enemy == null:
			# Only detect new target if we don't have one
			if distance_to_player <= detection_range:
				targeted_enemy = player
				player_just_detected = true
		else:
			# If we already have a target (player), keep them as target
			# Don't lose detection based on distance - only lose if player dies
			# This ensures orcs maintain pursuit once they've locked on
			pass
	
	# If we have a target, check if we should attack
	if targeted_enemy != null:
		var distance_to_target = position.distance_to(targeted_enemy.position)
		if distance_to_target < TILE_SIZE * 1.5:
			# Player is adjacent (surrounding behavior) - perform attack and don't move away
			if attack_timer <= 0.0:
				perform_attack()
				attack_timer = attack_cooldown
			# RULE: Never move away from the player while adjacent
			# Clear any path that might move us away
			path_queue.clear()
	
	# Recalculate path every 0.6 seconds when targeting an enemy (with staggering to prevent frame hitches)
	if targeted_enemy != null and chase_path_timer >= (chase_update_interval + pathfind_stagger):
		chase_path_timer = 0.0
		
		# Recalculate path ONLY when we're at a tile center (not in mid-movement)
		# This prevents oscillation from rapid recalculation while moving
		var at_tile_center = position.distance_to(target_position) < 1.0
		var player_just_appeared = player_just_detected
		
		# Additional check: don't recalculate if we just started moving recently
		# This gives the current path time to work before switching
		var time_since_move = Time.get_ticks_msec() / 1000.0 - last_move_time
		var enough_time_since_move = time_since_move > 0.2  # Wait at least 200ms after moving
		
		if (at_tile_center or player_just_appeared) and enough_time_since_move:
			var distance_to_player = position.distance_to(targeted_enemy.position)
			
			# RULE: If already adjacent to player, don't recalculate path
			# This prevents orcs from moving away when they should be surrounding
			if distance_to_player >= TILE_SIZE * 1.5:
				# ALWAYS try to find a path to the player (even if adjacent)
				# This ensures aggressive pursuit and proper surrounding behavior
				# Snap current position and target position to tile centers
				var start_tile_x = round(position.x / TILE_SIZE)
				var start_tile_y = round(position.y / TILE_SIZE)
				var start_tile_center = Vector2(start_tile_x * TILE_SIZE + TILE_SIZE/2, start_tile_y * TILE_SIZE + TILE_SIZE/2)
				
				# Target the player's tile, accounting for sprite visual offset
				# The player sprite is visually offset by -1 tile in Y, so we match that
				var target_tile_x = floor(targeted_enemy.position.x / TILE_SIZE)
				var target_tile_y = floor(targeted_enemy.position.y / TILE_SIZE)
				target_tile_y -= 1  # Account for player sprite visual offset
				var target_tile_center = Vector2(target_tile_x * TILE_SIZE + TILE_SIZE/2, target_tile_y * TILE_SIZE + TILE_SIZE/2)
			
				# Calculate new path to player's current position
				var new_path = find_path(start_tile_center, target_tile_center)
				
				# Replace path_queue with new path (even if empty - indicates no path available)
				path_queue.clear()  # Clear any previous path
				path_queue = new_path
				# A* already filtered water during pathfinding
				
				# Remove the starting position if it's in the path and we're already on it
				if path_queue.size() > 0 and path_queue[0].distance_to(position) < TILE_SIZE * 0.1:
					path_queue.pop_front()
				
				# Start moving on the new path if not already moving and we have waypoints
				if path_queue.size() > 0 and not is_moving:
					process_next_path_step()
	
	# Move toward target if we have one
	if is_moving:
		# Smoothly move towards target position
		var direction = (target_position - position).normalized()
		var distance = position.distance_to(target_position)
		
		if distance < MOVE_SPEED * delta:
			# Before snapping, check if target tile is still valid
			var target_valid = true
			
			# ABSOLUTE RULE: Check if target tile is walkable (both center and feet)
			if world != null and world.has_method("is_walkable"):
				if not world.is_walkable(target_position):
					target_valid = false
				
				# CRITICAL: Also check feet position on target tile
				if target_valid:
					var feet_offset = Vector2(0, TILE_SIZE / 2)
					var feet_position = target_position + feet_offset
					var feet_tile_x = floor(feet_position.x / TILE_SIZE)
					var feet_tile_y = floor(feet_position.y / TILE_SIZE)
					var feet_tile_center = Vector2(feet_tile_x * TILE_SIZE + TILE_SIZE/2, feet_tile_y * TILE_SIZE + TILE_SIZE/2)
					if not world.is_walkable(feet_tile_center):
						target_valid = false
				# CRITICAL: Also check feet position on target tile
				if target_valid:
					var feet_offset = Vector2(0, TILE_SIZE / 2)
					var feet_position = target_position + feet_offset
					var feet_tile_x = floor(feet_position.x / TILE_SIZE)
					var feet_tile_y = floor(feet_position.y / TILE_SIZE)
					var feet_tile_center = Vector2(feet_tile_x * TILE_SIZE + TILE_SIZE/2, feet_tile_y * TILE_SIZE + TILE_SIZE/2)
					if not world.is_walkable(feet_tile_center):
						target_valid = false
			
			# Check if player is on the target tile
			if target_valid and player != null and target_position.distance_to(player.position) < TILE_SIZE:
				target_valid = false
			
			# Check if another orc is on the target tile
			if target_valid and is_tile_occupied_by_enemy(target_position):
				target_valid = false
			
			if target_valid:
				# Snap to target when close enough
				position = target_position
				
				# ABSOLUTE RULE: Verify current position is walkable after snap (both center and feet)
				if world != null and world.has_method("is_walkable"):
					# Check the center position
					if not world.is_walkable(position):
						# Something went wrong - we're on water! Emergency recalculation
						is_moving = false
						path_queue.clear()
						chase_path_timer = chase_update_interval
						return
					
					# EXTRA SAFEGUARD: Also check the feet position after snap
					var feet_offset = Vector2(0, TILE_SIZE / 2)
					var feet_position = position + feet_offset
					var feet_tile_x = floor(feet_position.x / TILE_SIZE)
					var feet_tile_y = floor(feet_position.y / TILE_SIZE)
					var feet_tile_center = Vector2(feet_tile_x * TILE_SIZE + TILE_SIZE/2, feet_tile_y * TILE_SIZE + TILE_SIZE/2)
					
					if not world.is_walkable(feet_tile_center):
						# Feet landed on water - emergency recalculation
						is_moving = false
						path_queue.clear()
						chase_path_timer = chase_update_interval
						return
				
				is_moving = false
				# Process next step in path
				process_next_path_step()
			else:
				# Target tile is invalid, stop moving
				is_moving = false
		else:
			# Move smoothly towards target
			position += direction * MOVE_SPEED * delta
		
		# Update animation while moving
		var dir_name = get_direction_name(current_direction)
		if animated_sprite != null and animated_sprite.sprite_frames != null:
			var anim_name = "walk_" + dir_name
			if animated_sprite.animation != anim_name:
				animated_sprite.play(anim_name)
	
	# STUCK DETECTION: Check if orc has been on same tile too long while targeting player
	if targeted_enemy != null:
		var current_tile = (position / TILE_SIZE).round()
		
		# If this is a new tile, reset the stuck timer
		if current_tile != last_tile_position:
			last_tile_position = current_tile
			tile_stuck_timer = 0.0
		else:
			# Same tile - increment stuck timer
			tile_stuck_timer += delta
			
			# If stuck too long, force path recalculation
			if tile_stuck_timer > max_tile_stuck_time and not is_moving:
				var distance_to_target = position.distance_to(targeted_enemy.position)
				
				# Only force recalc if NOT adjacent to player (don't interrupt attacking)
				if distance_to_target >= TILE_SIZE * 1.5:
					print("[STUCK] Orc at ", position, " stuck for ", tile_stuck_timer, "s, forcing path recalc")
					path_queue.clear()
					chase_path_timer = chase_update_interval  # Force immediate recalculation
					tile_stuck_timer = 0.0  # Reset stuck timer
	
	if not is_moving:
		# Not moving - check if we should animate or move to next waypoint
		if targeted_enemy != null:
			var distance_to_target = position.distance_to(targeted_enemy.position)
			# If adjacent to target, play idle animation (we're in surrounding behavior attacking)
			if distance_to_target < TILE_SIZE * 1.5:
				var dir_name = get_direction_name(current_direction)
				if animated_sprite != null and animated_sprite.sprite_frames != null:
					var anim_name = "idle_" + dir_name
					if animated_sprite.animation != anim_name:
						animated_sprite.play(anim_name)
				# Maintain surrounding position - try to box in the player
				maintain_surrounding_position()
			# If NOT in attack range, we MUST be moving toward the target
			else:
				# Try to move to next waypoint in path
				if path_queue.size() > 0:
					process_next_path_step()
				# If we have no path, move directly toward the player as simple fallback
				else:
					# No path from A* - use simple greedy movement toward player
					var direction_to_player = (targeted_enemy.position - position).normalized()
					
					# Try 8 directions in order of preference toward player
					var directions_to_check = [
						Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
						Vector2.UP + Vector2.LEFT, Vector2.UP + Vector2.RIGHT,
						Vector2.DOWN + Vector2.LEFT, Vector2.DOWN + Vector2.RIGHT
					]
					
					# Sort by dot product with direction to player (best first)
					var sorted_directions = []
					for dir in directions_to_check:
						var dot = direction_to_player.dot(dir.normalized())
						sorted_directions.append({"dir": dir, "dot": dot})
					sorted_directions.sort_custom(func(a, b): return a["dot"] > b["dot"])
					
					# Try to move in the best direction that's walkable
					var moved = false
					for item in sorted_directions:
						var dir = item["dir"]
						var next_tile = position + dir.normalized() * TILE_SIZE
						var tile_x = round(next_tile.x / TILE_SIZE)
						var tile_y = round(next_tile.y / TILE_SIZE)
						var tile_center = Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2, tile_y * TILE_SIZE + TILE_SIZE / 2)
						
						# Simple walkability check - just check terrain, not occupancy
						var is_walkable = true
						if world != null and world.has_method("is_walkable"):
							if not world.is_walkable(tile_center):
								is_walkable = false
						
						if is_walkable:
							# This direction works - move to it
							target_position = tile_center
							# Update facing direction
							var dx = sign(dir.x)
							var dy = sign(dir.y)
							if dx != 0 or dy != 0:
								current_direction = calculate_direction(int(dx), int(dy))
							is_moving = true
							moved = true
							break
					
					# If no direction worked, force path recalculation
					if not moved:
						chase_path_timer = chase_update_interval
		else:
			# No target - idle animation
			var dir_name = get_direction_name(current_direction)
			if animated_sprite != null and animated_sprite.sprite_frames != null:
				var anim_name = "idle_" + dir_name
				if animated_sprite.animation != anim_name:
					animated_sprite.play(anim_name)
	
	# Update z_index based on y position to ensure proper layering during diagonal movement
	# Clamp to valid range to avoid exceeding Godot's z_index limits
	z_index = clampi(int(position.y / 10) + 1000, 0, 10000)


func process_next_path_step():
	"""Process the next step in the path_queue.
	Uses iterative loop instead of recursion to prevent stack overflow.
	This ensures multiple orcs can chase without causing a freeze."""
	
	var max_iterations = 100  # Safety limit to prevent infinite loops
	var iterations = 0
	var recalc_count = 0  # Track how many times we recalculate paths
	var max_recalcs = 3  # Only allow 3 path recalculations before giving up
	
	while path_queue.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		var next_waypoint = path_queue[0]
		
		# SAFETY CHECK: Verify the next waypoint is actually adjacent to current position
		# This prevents invalid grid-skipping movement when paths have gaps
		var distance_to_waypoint = position.distance_to(next_waypoint)
		var max_adjacent_distance = TILE_SIZE * 1.5  # Allows diagonal movement (sqrt(2) ≈ 1.41)
		
		if distance_to_waypoint > max_adjacent_distance:
			# The next waypoint is not adjacent - path is broken!
			print("[PATHSTEP] ERROR: Next waypoint is not adjacent! Distance: ", distance_to_waypoint, " from ", position, " to ", next_waypoint)
			# Clear the entire path and recalculate
			path_queue.clear()
			if targeted_enemy != null:
				# Force immediate recalculation
				chase_path_timer = chase_update_interval
			return
		
		# Calculate movement direction
		var raw_direction = next_waypoint - position
		var dx = sign(raw_direction.x)
		var dy = sign(raw_direction.y)
		var tile_offset = Vector2(dx, dy)
		
		# Only update direction if it actually changed from the last step
		if tile_offset != last_path_direction:
			# Direction changed - calculate new facing
			var new_direction = calculate_direction(int(dx), int(dy))
			if new_direction != current_direction:
				current_direction = new_direction
			last_path_direction = tile_offset
		
		# ABSOLUTE RULE: Check if target tile is walkable BEFORE moving
		# Apply the same feet offset that pathfinding uses for consistency
		var feet_offset = Vector2(0, TILE_SIZE / 2)
		var feet_position = next_waypoint + feet_offset
		var tile_x = floor(feet_position.x / TILE_SIZE)
		var tile_y = floor(feet_position.y / TILE_SIZE)
		var tile_center = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
		
		# Calculate waypoint tile center
		var waypoint_tile_x = floor(next_waypoint.x / TILE_SIZE)
		var waypoint_tile_y = floor(next_waypoint.y / TILE_SIZE)
		var waypoint_tile_center = Vector2(waypoint_tile_x * TILE_SIZE + TILE_SIZE/2, waypoint_tile_y * TILE_SIZE + TILE_SIZE/2)
		
		if world != null and world.has_method("is_walkable"):
			if not world.is_walkable(tile_center):
				# Cannot move to this waypoint - skip and try next
				path_queue.pop_front()
				continue  # Try next waypoint in loop
			
			if not world.is_walkable(waypoint_tile_center):
				# The waypoint center is water - skip it
				path_queue.pop_front()
				continue  # Try next waypoint in loop
			
			# TRIPLE CHECK: Verify terrain type directly to catch water tiles
			if world.has_method("get_terrain_at"):
				var waypoint_terrain = world.get_terrain_at(waypoint_tile_center)
				if waypoint_terrain == "water":
					path_queue.pop_front()
					continue
				var feet_terrain = world.get_terrain_at(tile_center)
				if feet_terrain == "water":
					path_queue.pop_front()
					continue
		
		# Check if another orc is occupying this tile
		if is_tile_occupied_by_enemy(next_waypoint):
			# Cannot move to this waypoint - recalculate path
			path_queue.clear()
			recalc_count += 1
			if recalc_count > max_recalcs:
				# Too many recalculations, give up and wait for next frame
				return
			var start_tile_center = (position / TILE_SIZE).round() * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
			var target_tile_center = (player.position / TILE_SIZE).round() * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
			var new_path = find_path(start_tile_center, target_tile_center)
			path_queue = new_path
			continue  # Restart loop with new path
		
		# EXTRA SAFEGUARD: Check if the waypoint is trapped (surrounded by water/unwalkable tiles)
		# This prevents getting stuck in dead-ends near water
		if is_tile_trapped_by_water(next_waypoint):
			# Skip this trapped waypoint and recalculate
			path_queue.clear()
			recalc_count += 1
			if recalc_count > max_recalcs:
				# Too many recalculations, give up and wait for next frame
				return
			var start_tile_center = (position / TILE_SIZE).round() * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
			var target_tile_center = (player.position / TILE_SIZE).round() * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
			var new_path = find_path(start_tile_center, target_tile_center)
			path_queue = new_path
			continue  # Restart loop with new path
		
		# Waypoint is valid! Remove it from the queue and move to it
		path_queue.pop_front()
		
		# Set target and begin movement
		target_position = next_waypoint
		is_moving = true
		last_move_time = Time.get_ticks_msec() / 1000.0
		return  # Exit and move to this waypoint
	
	# If we exhausted all waypoints or hit iteration limit, recalculate path
	if iterations >= max_iterations:
		print("[PATHSTEP] WARNING: Hit max iterations (", iterations, "), clearing path and recalculating")
		path_queue.clear()
		if targeted_enemy != null:
			chase_path_timer = chase_update_interval


func calculate_direction(dx: int, dy: int) -> Vector2:
	# Calculate cardinal direction with diagonal preference logic
	if dx != 0 and dy != 0:
		# Diagonal - prefer continuing in same direction
		var facing_h = Vector2(dx, 0)
		var facing_v = Vector2(0, dy)
		var h_back = (facing_h == -current_direction)
		var v_back = (facing_v == -current_direction)
		if h_back and not v_back:
			return facing_v
		elif v_back and not h_back:
			return facing_h
		else:
			if current_direction.x != 0:
				return facing_v
			else:
				return facing_h
	elif dx != 0:
		return Vector2(dx, 0)
	elif dy != 0:
		return Vector2(0, dy)
	return current_direction

func get_direction_name(dir: Vector2) -> String:
	if dir == Vector2.UP:
		return "up"
	elif dir == Vector2.DOWN:
		return "down"
	elif dir == Vector2.LEFT:
		return "left"
	elif dir == Vector2.RIGHT:
		return "right"
	return "down"

func is_tile_occupied_by_enemy(tile_pos: Vector2) -> bool:
	"""Check if a tile is occupied by another orc (not this orc)"""
	var parent = get_parent()
	if parent == null:
		return false
	
	# Get all children of the parent that are orcs
	for child in parent.get_children():
		if child is CharacterBody2D and child != self and child.script == self.script:
			# This is another orc - check if it's on this tile
			if child.position.distance_to(tile_pos) < TILE_SIZE:
				return true
	
	return false

func is_tile_trapped_by_water(tile_center: Vector2) -> bool:
	"""Check if a tile has no escape routes (all adjacent tiles are water/blocked).
	Only checks TERRAIN walkability, not enemy occupancy.
	Returns true if the tile is trapped/isolated by water."""
	if world == null or not world.has_method("is_walkable"):
		return false
	
	# Check all 8 directions (including diagonals) for at least one walkable tile
	var directions = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,  # Cardinal
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)  # Diagonal
	]
	var walkable_neighbors = 0
	
	for dir in directions:
		var neighbor_tile = tile_center + (dir * TILE_SIZE)
		# Only check terrain walkability, not enemy occupancy
		# An occupied tile can still be an escape route if the occupant moves
		if world.is_walkable(neighbor_tile):
			walkable_neighbors += 1
	
	# If at least one neighbor is walkable, this tile is NOT trapped
	return walkable_neighbors == 0

func maintain_surrounding_position():
	"""When adjacent to the player, stay in surrounding position.
	This ensures orcs box in the player and don't move away."""
	if targeted_enemy == null or world == null:
		return
	
	var distance_to_target = position.distance_to(targeted_enemy.position)
	# Only maintain surrounding if NOT already adjacent
	if distance_to_target < TILE_SIZE * 1.5:
		return
	
	# Try to move to an adjacent tile around the player
	# This ensures proper surrounding behavior
	var player_tile_x = floor(targeted_enemy.position.x / TILE_SIZE)
	var player_tile_y = floor(targeted_enemy.position.y / TILE_SIZE)
	
	# List of adjacent tiles around the player (8 directions)
	var adjacent_tiles = [
		Vector2(player_tile_x + 1, player_tile_y),  # Right
		Vector2(player_tile_x - 1, player_tile_y),  # Left
		Vector2(player_tile_x, player_tile_y + 1),  # Down
		Vector2(player_tile_x, player_tile_y - 1),  # Up
		Vector2(player_tile_x + 1, player_tile_y + 1),  # Down-Right
		Vector2(player_tile_x - 1, player_tile_y + 1),  # Down-Left
		Vector2(player_tile_x + 1, player_tile_y - 1),  # Up-Right
		Vector2(player_tile_x - 1, player_tile_y - 1),  # Up-Left
	]
	
	var best_tile = null
	var best_distance = INF
	
	# Find the closest unoccupied adjacent tile
	for tile_coords in adjacent_tiles:
		var tile_center = Vector2(tile_coords.x * TILE_SIZE + TILE_SIZE/2, tile_coords.y * TILE_SIZE + TILE_SIZE/2)
		
		# Check if walkable (both center and feet)
		if not world.is_walkable(tile_center):
			continue
		
		# CRITICAL: Check feet position too
		var feet_offset = Vector2(0, TILE_SIZE / 2)
		var feet_position = tile_center + feet_offset
		var feet_tile_x = floor(feet_position.x / TILE_SIZE)
		var feet_tile_y = floor(feet_position.y / TILE_SIZE)
		var feet_tile_center = Vector2(feet_tile_x * TILE_SIZE + TILE_SIZE/2, feet_tile_y * TILE_SIZE + TILE_SIZE/2)
		if not world.is_walkable(feet_tile_center):
			continue
		
		# Check if occupied
		if is_tile_occupied_by_enemy(tile_center) or (player != null and tile_center.distance_to(player.position) < TILE_SIZE * 0.5):
			continue
		
		# Prefer tiles we're already closest to (minimize movement)
		var dist = position.distance_to(tile_center)
		if dist < best_distance:
			best_distance = dist
			best_tile = tile_center
	
	# If we found a good surrounding tile, move toward it
	if best_tile != null:
		target_position = best_tile
		is_moving = true
		last_move_time = Time.get_ticks_msec() / 1000.0

func find_path(start: Vector2, goal: Vector2) -> Array:
	"""Call the world's shared pathfinding function.
	This ensures orcs use identical pathfinding logic to the player."""
	if world != null and world.has_method("find_path"):
		return world.find_path(start, goal, self)
	return []

func _draw():
	# Draw red border around the sprite when targeted
	if is_targeted:
		# The targetable tile is the lower of the two tiles the sprite occupies
		var border_width = 2
		var rect_offset = Vector2(-TILE_SIZE/2, TILE_SIZE/2)  # Center horizontally, align with lower tile
		
		# Draw red outline around the tile containing the feet
		draw_line(rect_offset, rect_offset + Vector2(TILE_SIZE, 0), Color.RED, border_width)  # Top
		draw_line(rect_offset + Vector2(TILE_SIZE, 0), rect_offset + Vector2(TILE_SIZE, TILE_SIZE), Color.RED, border_width)  # Right
		draw_line(rect_offset + Vector2(TILE_SIZE, TILE_SIZE), rect_offset + Vector2(0, TILE_SIZE), Color.RED, border_width)  # Bottom
		draw_line(rect_offset, rect_offset + Vector2(0, TILE_SIZE), Color.RED, border_width)  # Left

func perform_attack():
	if targeted_enemy == null:
		return
	
	var damage = strength + randi_range(-2, 2)
	var target_health = targeted_enemy.get_meta("current_health")
	target_health -= damage
	targeted_enemy.set_meta("current_health", target_health)
	
	# Trigger health bar redraw
	if targeted_enemy.has_node("HealthBar"):
		var health_bar = targeted_enemy.get_node("HealthBar")
		health_bar.queue_redraw()
	
	# Check if target died
	if target_health <= 0:
		targeted_enemy.die()
		targeted_enemy = null

func die():
	# Create a dead body visual at the orc's position
	var dead_body = Node2D.new()
	dead_body.position = position + Vector2(0, TILE_SIZE/2)  # Position at the feet tile
	dead_body.z_index = 0  # On the ground, above terrain
	
	# Load and attach the dead body script
	var dead_body_script = load("res://scripts/dead_body.gd")
	dead_body.set_script(dead_body_script)
	
	# Add the dead body to the world node so it renders with terrain
	var parent = get_parent()
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			world.add_child(dead_body)
		else:
			# Fallback to parent if world not found
			parent.add_child(dead_body)
	
	
	# Remove the orc from the scene
	queue_free()


