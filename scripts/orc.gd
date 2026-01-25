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
var chase_update_interval = 1.0  # Update chase path every 1.0 second (was 0.5)
var patrol_update_interval = 2.0  # Update patrol direction every 2 seconds
var chase_path = []  # Path to follow when chasing
var chase_path_index = 0  # Current index in the path
var last_player_position = Vector2.ZERO  # Track player position for smart path updates
var last_path_direction = Vector2.ZERO  # Track direction to avoid flashing during movement
var move_direction = Vector2.DOWN  # Direction to move on current step

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
	
	print("Orc _ready() called")
	print("Orc position: ", position)
	print("Orc animated_sprite node: ", animated_sprite)
	print("Orc parent: ", get_parent())
	
	if animated_sprite == null:
		print("ERROR: AnimatedSprite2D node not found!")
		return
	
	# Get reference to the player and world for collision detection
	var parent = get_parent()
	if parent:
		player = parent.find_child("Player", true, false)
		world = parent.find_child("World", true, false)
		print("Orc found Player: ", player)
		print("Orc found World: ", world)
	else:
		print("ERROR: Orc has no parent!")
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
	
	print("Orc position after snapping: ", position)
	
	target_position = position
	current_direction = Vector2.DOWN
	
	# Start with idle animation
	if animated_sprite.sprite_frames != null:
		animated_sprite.play("idle_down")
		print("Orc animation started")
	else:
		print("ERROR: sprite_frames is null after create_orc_animations!")
	
	# Initialize targeted_enemy to the player
	targeted_enemy = null  # Will be set when detecting player
	
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
	# Update direction change timer
	direction_change_timer += delta
	
	# Handle attack cooldown
	if attack_timer > 0.0:
		attack_timer -= delta
	
	# Check if player is in detection range
	var player_just_detected = false
	if player != null and targeted_enemy == null:
		var distance_to_player = position.distance_to(player.position)
		if distance_to_player <= detection_range:
			targeted_enemy = player
			player_just_detected = true
			print("[ORC_AGGRO] Orc detected Player at distance ", distance_to_player)
		else:
			print("[ORC_DETECT] Player at distance ", distance_to_player, " > detection_range ", detection_range)
	elif targeted_enemy != null:
		print("[ORC_HAS_TARGET] Already have target")
	else:
		print("[ORC_NO_PLAYER] Player reference is null")
	# If we have a target, try to attack if adjacent
	if targeted_enemy != null:
		var distance_to_target = position.distance_to(targeted_enemy.position)
		if distance_to_target < TILE_SIZE * 1.5:
			# Player is adjacent, perform attack
			if attack_timer <= 0.0:
				perform_attack()
				attack_timer = attack_cooldown
	
	# Decide when to recalculate path
	if (direction_change_timer >= chase_update_interval or player_just_detected) and targeted_enemy != null:
		direction_change_timer = 0.0
		
		# Only try to move if we're at a tile center (or just detected)
		if position.distance_to(target_position) < 1.0 or player_just_detected:
			# Skip pathfinding if player is very far away - use fallback instead
			var distance_to_player = position.distance_to(targeted_enemy.position)
			if distance_to_player <= TILE_SIZE * 30:
				# Recalculate path if player has moved significantly or just detected
				var player_movement = targeted_enemy.position.distance_to(last_player_position)
				if player_movement > TILE_SIZE * 0.8 or chase_path.size() == 0 or player_just_detected:
					# Calculate path to target - snap target to tile center first
					var target_tile_x = round(targeted_enemy.position.x / TILE_SIZE)
					var target_tile_y = round(targeted_enemy.position.y / TILE_SIZE)
					var target_tile_center = Vector2(target_tile_x * TILE_SIZE + TILE_SIZE/2, target_tile_y * TILE_SIZE + TILE_SIZE/2)
					
					chase_path = find_path(position, target_tile_center)
					chase_path_index = 0
					last_player_position = targeted_enemy.position
					
					print("[ORC_PATHFINDING] Found path with ", chase_path.size(), " waypoints from ", position, " to ", targeted_enemy.position)
					
					# Don't remove the first element here - let process_orc_next_path_step handle it
					# This prevents double-removal of waypoints
					
					# Skip the starting position if it's in the path
					if chase_path.size() > 0 and chase_path[0].distance_to(position) < TILE_SIZE * 0.1:
						chase_path.pop_front()
						print("[ORC_PATHFINDING] Removed starting position from path, now have ", chase_path.size(), " waypoints")
					
					# Immediately start following the new path
					if chase_path.size() > 0 and not is_moving:
						process_orc_next_path_step()
	
	# Move toward target if we have one
	if is_moving:
		# Smoothly move towards target position
		var direction = (target_position - position).normalized()
		var distance = position.distance_to(target_position)
		
		if distance < MOVE_SPEED * delta:
			# Snap to target when close enough
			position = target_position
			var tile_x = floor(position.x / TILE_SIZE)
			var tile_y = floor(position.y / TILE_SIZE)
			print("[ORC_MOVE_COMPLETE] Snapped to tile (", tile_x, ",", tile_y, ") at pos ", position)
			is_moving = false
			# Process next step in path
			process_orc_next_path_step()
		else:
			# Move smoothly towards target
			position += direction * MOVE_SPEED * delta
		
		# Update animation while moving
		var dir_name = get_direction_name(current_direction)
		if animated_sprite != null and animated_sprite.sprite_frames != null:
			var anim_name = "walk_" + dir_name
			if animated_sprite.animation != anim_name:
				animated_sprite.play(anim_name)
	else:
		# Not moving - check if we're in attack range or try to move to next waypoint
		if targeted_enemy != null:
			var distance_to_target = position.distance_to(targeted_enemy.position)
			# If adjacent to target, play idle animation (we're attacking)
			if distance_to_target < TILE_SIZE * 1.5:
				var dir_name = get_direction_name(current_direction)
				if animated_sprite != null and animated_sprite.sprite_frames != null:
					var anim_name = "idle_" + dir_name
					if animated_sprite.animation != anim_name:
						animated_sprite.play(anim_name)
			# If we have no path, move directly toward the player as fallback
			elif chase_path.size() == 0:
				var direction_to_player = (targeted_enemy.position - position).normalized()
				
				# Find the best direction, with strong preference for current direction
				var best_direction = Vector2.DOWN
				var best_dot = -2.0
				
				# Check 8 directions (4 cardinal + 4 diagonal) for better pathfinding
				var directions_to_check = [
					Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
					Vector2.UP + Vector2.LEFT, Vector2.UP + Vector2.RIGHT,
					Vector2.DOWN + Vector2.LEFT, Vector2.DOWN + Vector2.RIGHT
				]
				
				for dir in directions_to_check:
					var dot = direction_to_player.dot(dir)
					# Strong hysteresis: prefer current direction to reduce jitter
					var adjusted_dot = dot
					if dir.normalized() == current_direction:
						# Large bonus for continuing in same direction
						adjusted_dot += 0.4
					elif dir.x != 0 and dir.y != 0:  # Diagonal direction
						# Penalty for diagonals to prefer straighter paths
						adjusted_dot -= 0.2
					
					if adjusted_dot > best_dot:
						best_dot = adjusted_dot
						best_direction = dir
				
				var next_tile = position + best_direction.normalized() * TILE_SIZE
				
				# Check if the next tile is walkable
				var can_move = true
				if world != null and world.has_method("is_walkable"):
					var feet_tile = next_tile + Vector2(0, TILE_SIZE / 2)
					if not world.is_walkable(feet_tile):
						print("[ORC_UNWALKABLE] Tile at ", next_tile, " is not walkable")
						can_move = false
				
				# Check if the next tile is occupied by the player
				if can_move and player != null and next_tile.distance_to(player.position) < TILE_SIZE:
					# Player is on that tile, can't move there
					print("[ORC_BLOCKED] Player blocking tile at ", next_tile)
					can_move = false
				
				if can_move:
					# Snap to tile center to ensure proper grid alignment
					var tile_x = floor(next_tile.x / TILE_SIZE)
					var tile_y = floor(next_tile.y / TILE_SIZE)
					target_position = Vector2(tile_x * TILE_SIZE + TILE_SIZE / 2, tile_y * TILE_SIZE + TILE_SIZE / 2)
					# For diagonal movement, convert to cardinal direction for animation
					var dx = sign(best_direction.x)
					var dy = sign(best_direction.y)
					current_direction = calculate_direction(int(dx), int(dy))
					is_moving = true
					print("[ORC_FALLBACK] Moving directly toward player at direction ", get_direction_name(current_direction))
			else:
				process_orc_next_path_step()
		else:
			# Idle animation
			var dir_name = get_direction_name(current_direction)
			if animated_sprite != null and animated_sprite.sprite_frames != null:
				var anim_name = "idle_" + dir_name
				if animated_sprite.animation != anim_name:
					animated_sprite.play(anim_name)
	
	# Update z_index based on y position to ensure proper layering during diagonal movement
	# Clamp to valid range to avoid exceeding Godot's z_index limits
	z_index = clampi(int(position.y / 10) + 1000, 0, 10000)


func process_orc_next_path_step():
	"""Process the next step in the orc's chase path.
	This mirrors the player's process_next_path_step() logic to ensure
	consistent movement and animation behavior."""
	print("[ORC_STEP] process_orc_next_path_step called. Path size: ", chase_path.size(), ", targeted_enemy: ", targeted_enemy != null)
	
	if targeted_enemy == null or chase_path.size() == 0:
		print("[ORC_STEP] Early return - no enemy or empty path")
		return
	
	# Get next waypoint
	var next_waypoint = chase_path[0]
	print("[ORC_STEP] Next waypoint: ", next_waypoint, " Current position: ", position)
	
	# Calculate movement direction
	var raw_direction = next_waypoint - position
	var dx = sign(raw_direction.x)
	var dy = sign(raw_direction.y)
	var tile_offset = Vector2(dx, dy)
	
	print("[ORC_STEP] raw_direction: ", raw_direction, " dx: ", dx, " dy: ", dy, " tile_offset: ", tile_offset)
	
	# Only update direction if it actually changed from the last step
	if tile_offset != last_path_direction:
		# Direction changed - calculate new facing
		var new_direction = calculate_direction(int(dx), int(dy))
		current_direction = new_direction
		last_path_direction = tile_offset
		print("[ORC_DIRECTION_CHANGE] New direction: ", get_direction_name(new_direction), " from tile_offset: ", tile_offset)
	
	# Set target and begin movement
	target_position = next_waypoint
	is_moving = true
	chase_path_index = 0
	chase_path.pop_front()  # Remove the waypoint we're moving to
	
	var tile_x = floor(next_waypoint.x / TILE_SIZE)
	var tile_y = floor(next_waypoint.y / TILE_SIZE)
	print("[ORC_PATH_STEP] Moving to waypoint tile (", tile_x, ",", tile_y, ") with ", chase_path.size(), " waypoints remaining")


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

func find_path(start: Vector2, goal: Vector2) -> Array:
	print("[FIND_PATH] Called with start: ", start, " goal: ", goal)
	
	if start == goal:
		print("[FIND_PATH] Start == goal, returning empty path")
		return []
	
	# Check if goal is walkable
	if world and world.has_method("is_walkable"):
		var feet_offset = Vector2(0, TILE_SIZE / 2)
		var goal_feet = goal + feet_offset
		if not world.is_walkable(goal_feet):
			print("[FIND_PATH] Goal not walkable at ", goal_feet)
			return []
	
	# A* pathfinding
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: heuristic(start, goal)}
	var closed_set = {}
	var iterations = 0
	var max_iterations = 5000  # Reduced to improve performance - use fallback for long paths
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		# Find node with lowest f_score
		var current = open_set[0]
		var current_f = f_score.get(current, INF)
		for node in open_set:
			var node_f = f_score.get(node, INF)
			if node_f < current_f:
				current = node
				current_f = node_f
		
		# Reached goal
		if current == goal:
			var path = reconstruct_path(came_from, current)
			print("[FIND_PATH] Found path with ", path.size(), " nodes after ", iterations, " iterations")
			return path
		
		open_set.erase(current)
		closed_set[current] = true
		
		# Check all neighbors
		var neighbors = get_neighbors(current)
		for neighbor in neighbors:
			if neighbor in closed_set:
				continue
			
			# Check walkability
			if world and world.has_method("is_walkable"):
				var feet_offset = Vector2(0, TILE_SIZE / 2)
				var feet_position = neighbor + feet_offset
				if not world.is_walkable(feet_position):
					continue
			
			# Check if player is occupying this tile
			if player != null and neighbor.distance_to(player.position) < TILE_SIZE:
				continue
			
			# Calculate tentative g_score
			var tentative_g = g_score.get(current, INF) + current.distance_to(neighbor)
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + heuristic(neighbor, goal)
				
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	print("[FIND_PATH] No path found after ", iterations, " iterations. open_set size: ", open_set.size())
	return []

func get_neighbors(tile_center: Vector2) -> Array:
	var neighbors = []
	var tile_x = floor(tile_center.x / TILE_SIZE)
	var tile_y = floor(tile_center.y / TILE_SIZE)
	
	var directions = [
		Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)
	]
	
	for dir in directions:
		var neighbor_x = tile_x + dir.x
		var neighbor_y = tile_y + dir.y
		var neighbor_center = Vector2(neighbor_x * TILE_SIZE + TILE_SIZE/2, neighbor_y * TILE_SIZE + TILE_SIZE/2)
		neighbors.append(neighbor_center)
	
	return neighbors

func heuristic(a: Vector2, b: Vector2) -> float:
	var dx = abs(a.x - b.x) / TILE_SIZE
	var dy = abs(a.y - b.y) / TILE_SIZE
	var D = TILE_SIZE
	var D2 = sqrt(2) * TILE_SIZE
	return D * max(dx, dy) + (D2 - D) * min(dx, dy)

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while current in came_from:
		current = came_from[current]
		path.insert(0, current)
	return path

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
	
	print("[ORC_ATTACK] Orc dealt ", damage, " damage to Player. HP: ", target_health, "/", targeted_enemy.get_meta("max_health"))
	
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
	
	print("[ORC_DIE] Orc died at position ", position)
	
	# Remove the orc from the scene
	queue_free()


