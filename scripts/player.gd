extends CharacterBody2D

# Player controller for grid-based movement (like Tibia)

const TILE_SIZE = 32
const MOVE_SPEED = 200.0  # Pixels per second

var is_moving = false
var target_position = Vector2.ZERO
var path_queue = []  # Queue of positions to move through

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var current_direction = Vector2.DOWN  # Track current facing direction
var last_input_direction = Vector2.ZERO  # Track previous frame's input direction
var last_path_direction = Vector2.ZERO  # Track previous pathfinding step's direction
var orc_reference: Node = null  # Cache orc reference

# Health system
var max_health = 100
var current_health = 100
var health_bar = null

# Stats system
var max_mp = 50
var current_mp = 50
var strength = 10
var intelligence = 10
var dexterity = 10
var speed = 8

# Targeting system
var targeted_enemy = null  # Reference to the currently targeted enemy

# Combat system
var attack_cooldown = 1.5  # Seconds between attacks
var attack_timer = 0.0  # Current attack cooldown timer

func _ready():
	# Create animated sprite with walking animations
	create_player_animations()
	
	# Position sprite offset so feet are lower in the tile
	animated_sprite.offset = Vector2(0, 8)
	
	# Start at center of tile (0,0) to align with world tiles
	position = Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	target_position = position
	
	# Start with idle animation
	animated_sprite.play("idle_down")
	
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

func _process(_delta):
	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= _delta
	
	# Auto-attack targeted enemy if in range
	if targeted_enemy != null and attack_timer <= 0:
		var distance_to_target = position.distance_to(targeted_enemy.position)
		# Check if target is adjacent (within 1.5 tiles)
		if distance_to_target < TILE_SIZE * 1.5:
			perform_attack(targeted_enemy)
			attack_timer = attack_cooldown
	
	# Look for orc reference if we don't have it yet
	if orc_reference == null:
		var parent = get_parent()
		if parent:
			orc_reference = parent.find_child("Orc", true, false)
			if orc_reference:
				print("[PLAYER] Orc reference found in _process: ", orc_reference.name)

func create_player_animations():
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
	var idle_frame = create_character_frame(dir_vector, 1)  # Use middle frame for idle
	sprite_frames.add_frame("idle_" + dir_name, idle_frame)
	
	# Create walk animation (4 frames for smooth walk cycle)
	sprite_frames.add_animation("walk_" + dir_name)
	sprite_frames.set_animation_speed("walk_" + dir_name, 12.0)
	sprite_frames.set_animation_loop("walk_" + dir_name, true)
	
	for frame_num in range(4):
		var walk_frame = create_character_frame(dir_vector, frame_num)
		sprite_frames.add_frame("walk_" + dir_name, walk_frame)

func create_character_frame(direction: Vector2, frame: int) -> ImageTexture:
	# Create a 32x64 pixel art character (2 tiles tall, positioned on bottom tile)
	var img = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	
	# Define colors
	var skin = Color(0.95, 0.8, 0.6)  # Skin tone
	var hair = Color(0.3, 0.2, 0.1)   # Brown hair
	var leather = Color(0.55, 0.35, 0.2)  # Leather brown
	var leather_dark = Color(0.4, 0.25, 0.15)  # Dark leather
	var pants = Color(0.3, 0.3, 0.4)  # Gray pants
	var outline = Color(0.1, 0.1, 0.1)  # Dark outline
	var metal = Color(0.7, 0.7, 0.75)  # Sword blade
	var handle = Color(0.4, 0.3, 0.2)  # Sword handle
	
	# Determine if this is a walking frame (frame 0 and 2 are standing, 1 and 3 are walking)
	var is_walking = (frame == 1 or frame == 3)
	
	# Draw character based on direction
	if direction == Vector2.UP:
		draw_character_back(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame)
	elif direction == Vector2.DOWN:
		draw_character_front(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame)
	elif direction == Vector2.LEFT:
		draw_character_side(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame, true)
	elif direction == Vector2.RIGHT:
		draw_character_side(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame, false)
	
	# Create texture from image
	var texture = ImageTexture.create_from_image(img)
	return texture

func draw_character_front(img: Image, skin: Color, hair: Color, leather: Color, leather_dark: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int):
	# Front-facing character (32x64 - 2 tiles tall)
	# walk_frame 0,2 = standing, 1,3 = walking with opposite legs
	
	# Upper body/chest (rows 24-31) - moved down to start below the head/neck
	for y in range(28, 36):
		for x in range(7, 25):
			img.set_pixel(x, y, leather)
	for y in range(28, 36):
		img.set_pixel(7, y, outline)
		img.set_pixel(24, y, outline)
	for x in range(7, 25):
		img.set_pixel(x, 28, outline)
		img.set_pixel(x, 35, outline)
	
	# Head (rows 12-23) - bald head, no helmet
	for y in range(12, 24):
		for x in range(9, 23):
			img.set_pixel(x, y, skin)
	
	# Head outline
	for y in range(12, 24):
		img.set_pixel(8, y, outline)
		img.set_pixel(23, y, outline)
	for x in range(8, 24):
		img.set_pixel(x, 11, outline)
		img.set_pixel(x, 24, outline)
	
	# Eyes (rows 16-18)
	for y in range(16, 19):
		img.set_pixel(12, y, outline)  # Left eye
		img.set_pixel(19, y, outline)  # Right eye
	
	# Neck (rows 24-27)
	for y in range(24, 28):
		for x in range(11, 21):
			img.set_pixel(x, y, skin)
		img.set_pixel(11, y, outline)
		img.set_pixel(20, y, outline)
	
	# Body/Leather Armor (rows 28-40)
	for y in range(28, 41):
		for x in range(7, 25):
			img.set_pixel(x, y, leather)
		img.set_pixel(7, y, outline)
		img.set_pixel(24, y, outline)
	
	# Armor details (straps and stitching)
	for y in range(28, 41):
		for x in range(14, 18):
			img.set_pixel(x, y, leather_dark)
	# Horizontal straps
	for x in range(10, 22):
		img.set_pixel(x, 32, leather_dark)
		img.set_pixel(x, 36, leather_dark)
	
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
	
	# Right arm (holding sword)
	for y in range(max(30, 30 + right_arm_offset), min(40, 40 + right_arm_offset)):
		if y >= 0 and y < 64:
			for x in range(24, 28):
				img.set_pixel(x, y, skin)
			img.set_pixel(27, y, outline)
	
	# Sword in right hand
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
	
	# Pants (rows 41-50)
	for y in range(41, 51):
		for x in range(9, 23):
			img.set_pixel(x, y, pants)
		img.set_pixel(9, y, outline)
		img.set_pixel(22, y, outline)
	
	# Legs with animation (rows 51-62)
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
		for y in range(51, 59):
			var pixel_y = y + left_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, pants)
		var foot_y = 59 + left_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for fy in range(foot_y, min(foot_y + 4, 64)):
				img.set_pixel(9, fy, outline)
				img.set_pixel(10, fy, outline)
				img.set_pixel(11, fy, outline)
				img.set_pixel(12, fy, outline)
				img.set_pixel(13, fy, outline)
				img.set_pixel(14, fy, outline)
				img.set_pixel(15, fy, outline)
	
	# Right leg
	for x in range(16, 23):
		for y in range(51, 59):
			var pixel_y = y + right_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, pants)
		var foot_y = 59 + right_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for fy in range(foot_y, min(foot_y + 4, 64)):
				img.set_pixel(16, fy, outline)
				img.set_pixel(17, fy, outline)
				img.set_pixel(18, fy, outline)
				img.set_pixel(19, fy, outline)
				img.set_pixel(20, fy, outline)
				img.set_pixel(21, fy, outline)
				img.set_pixel(22, fy, outline)
	
	# Leg outlines
	for y in range(max(51, 51 + left_leg_offset), min(63, 63 + left_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(8, y, outline)
	for y in range(max(48, 48 + right_leg_offset), min(63, 63 + right_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(23, y, outline)

func draw_character_back(img: Image, skin: Color, hair: Color, leather: Color, leather_dark: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int):
	# Back-facing character (32x64 - scaled 2x horizontal, 4x vertical)
	# walk_frame determines leg position: 0,2 = standing, 1,3 = walking
	
	# Upper body/chest (rows 28-35) - moved down to start below the head/neck
	for y in range(28, 36):
		for x in range(7, 25):
			img.set_pixel(x, y, leather)
	for y in range(28, 36):
		img.set_pixel(7, y, outline)
		img.set_pixel(24, y, outline)
	for x in range(7, 25):
		img.set_pixel(x, 28, outline)
		img.set_pixel(x, 35, outline)
	
	# Head/bald head (rows 12-23) - no helmet
	for y in range(12, 24):
		for x in range(9, 23):
			img.set_pixel(x, y, skin)
	# Head outline
	for y in range(12, 24):
		img.set_pixel(8, y, outline)
		img.set_pixel(23, y, outline)
	for x in range(8, 24):
		img.set_pixel(x, 11, outline)
		img.set_pixel(x, 24, outline)
	
	# Neck - rows 24-27
	for y in range(24, 28):  # Extended to fill gap
		for x in range(11, 21):  # Fill from 11 to 20
			img.set_pixel(x, y, skin)
		img.set_pixel(10, y, outline)
		img.set_pixel(21, y, outline)
	
	# Body/Leather Armor - rows 28-39
	for y in range(28, 40):  # 7-10 → 28-40
		for x in range(7, 25):  # Fill from 7 to 24 to connect with outline
			img.set_pixel(x, y, leather)
		img.set_pixel(6, y, outline)  # 3 → 6
		img.set_pixel(25, y, outline)  # Right outline
	
	# Armor details - vertical straps
	for y in range(28, 40):  # 7-10 → 28-40
		img.set_pixel(14, y, leather_dark)  # 7 → 14
		img.set_pixel(17, y, leather_dark)  # Adjusted for new width
	# Horizontal straps
	for x in range(7, 25):
		img.set_pixel(x, 32, leather_dark)
		img.set_pixel(x, 36, leather_dark)
	
	# Arms with animation (visible from back)
	var left_arm_offset = 0
	var right_arm_offset = 0
	if walk_frame == 1:
		left_arm_offset = 4  # 1 → 4
		right_arm_offset = -4  # -1 → -4
	elif walk_frame == 3:
		left_arm_offset = -4  # -1 → -4
		right_arm_offset = 4  # 1 → 4
	
	for y in range(max(32, 32 + left_arm_offset), min(44, 44 + left_arm_offset)):  # 8-11 → 32-44
		if y >= 0 and y < 64:
			img.set_pixel(6, y, skin)  # 3 → 6
			img.set_pixel(5, y, skin)  # Fill gap
			img.set_pixel(4, y, outline)  # 2 → 4
	
	for y in range(max(32, 32 + right_arm_offset), min(44, 44 + right_arm_offset)):  # 8-11 → 32-44
		if y >= 0 and y < 64:
			img.set_pixel(24, y, skin)  # 12 → 24
			img.set_pixel(25, y, skin)  # Fill gap
			img.set_pixel(26, y, outline)  # 13 → 26
	
	# Pants - rows 40-47
	for y in range(40, 48):  # 10-12 → 40-48
		for x in range(9, 23):  # Fill from 9 to 22 to connect with outline
			img.set_pixel(x, y, pants)
		img.set_pixel(8, y, outline)  # 4 → 8
		img.set_pixel(23, y, outline)  # Right outline
	
	# Sword tip behind right shoulder (animated)
	var sword_tip_offset = 0
	if walk_frame == 1:
		sword_tip_offset = -2  # Sword tip moves up
	elif walk_frame == 3:
		sword_tip_offset = 2  # Sword tip moves down
	
	# Sword blade tip (rows 18-26, behind shoulder)
	for y in range(max(0, 18 + sword_tip_offset), min(64, 27 + sword_tip_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(24, y, metal)  # Behind right shoulder
	# Blade outline
	for y in range(max(0, 18 + sword_tip_offset), min(64, 27 + sword_tip_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(25, y, outline)
	
	# Legs with animation
	var left_leg_offset = 0
	var right_leg_offset = 0
	if walk_frame == 1:
		left_leg_offset = -4  # -1 → -4
		right_leg_offset = 4  # 1 → 4
	elif walk_frame == 3:
		left_leg_offset = 4  # 1 → 4
		right_leg_offset = -4  # -1 → -4
	
	# Left leg - rows 48-55
	for x in range(9, 16):  # Fill from 9 to connect
		for y in range(48, 56):  # 12-14 → 48-56
			var pixel_y = y + left_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, pants)
		var foot_y = 56 + left_leg_offset  # 14 → 56
		if foot_y >= 0 and foot_y < 64:
			for foot_x in range(9, 16):  # Extend
				for fy in range(foot_y, min(foot_y + 4, 64)):  # Add foot height
					img.set_pixel(foot_x, fy, outline)
	
	# Right leg - rows 48-55
	for x in range(16, 23):  # Extend to 23
		for y in range(48, 56):  # 12-14 → 48-56
			var pixel_y = y + right_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, pants)
		var foot_y = 56 + right_leg_offset  # 14 → 56
		if foot_y >= 0 and foot_y < 64:
			for foot_x in range(16, 23):  # Extend
				for fy in range(foot_y, min(foot_y + 4, 64)):  # Add foot height
					img.set_pixel(foot_x, fy, outline)
	
	# Leg outlines
	for y in range(max(48, 48 + left_leg_offset), min(60, 60 + left_leg_offset)):  # 12-15 → 48-60
		if y >= 0 and y < 64:
			img.set_pixel(8, y, outline)  # 4 → 8
	for y in range(max(48, 48 + right_leg_offset), min(60, 60 + right_leg_offset)):  # 12-15 → 48-60
		if y >= 0 and y < 64:
			img.set_pixel(22, y, outline)  # 11 → 22

func create_orc_frame(direction: Vector2, frame: int) -> ImageTexture:
	# Create a 32x64 pixel orc character (similar to player but green-skinned and no armor)
	var img = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	
	# Define colors for orc
	var green_skin = Color(0.4, 0.7, 0.4)  # Green skin
	var dark_green = Color(0.2, 0.5, 0.2)  # Darker green for details
	var hair = Color(0.3, 0.2, 0.1)  # Brown hair
	var muscle_shadow = Color(0.25, 0.55, 0.25)  # Shadow for muscles
	var pants = Color(0.5, 0.4, 0.3)  # Leather loincloth/simple pants
	var outline = Color(0, 0, 0)  # Pure black outline
	var metal = Color(0.7, 0.7, 0.75)  # Weapon blade
	var handle = Color(0.4, 0.3, 0.2)  # Weapon handle
	
	# Draw orc based on direction
	if direction == Vector2.UP:
		draw_orc_back(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame)
	elif direction == Vector2.DOWN:
		draw_orc_front(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame)
	elif direction == Vector2.LEFT:
		draw_orc_side(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame, true)
	elif direction == Vector2.RIGHT:
		draw_orc_side(img, green_skin, dark_green, hair, muscle_shadow, pants, outline, metal, handle, frame, false)
	
	# Create texture from image
	var texture = ImageTexture.create_from_image(img)
	return texture

func draw_orc_front(img: Image, skin: Color, dark_skin: Color, hair: Color, muscle: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int):
	# Front-facing orc (32x64 - 2 tiles tall)
	# Similar to player but no helmet, more muscular, and green
	
	# Head (rows 12-23)
	for y in range(12, 24):
		for x in range(9, 23):
			img.set_pixel(x, y, skin)
		img.set_pixel(9, y, outline)
		img.set_pixel(22, y, outline)
	# Top of head outline (row 11, solid and wide)
	for x in range(7, 26):
		img.set_pixel(x, 11, outline)
	
	# Eyes (rows 16-18)
	for y in range(16, 19):
		img.set_pixel(12, y, outline)  # Left eye
		img.set_pixel(19, y, outline)  # Right eye
	
	# Tusks - simple vertical lines for orc character (rows 18-22)
	img.set_pixel(10, 19, outline)  # Left tusk
	img.set_pixel(10, 20, outline)
	img.set_pixel(21, 19, outline)  # Right tusk
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
	# Top of head outline (row 11, solid and wide)
	for x in range(7, 26):
		img.set_pixel(x, 11, outline)
	
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
	# Top of head outline (row 11, solid and wide)
	for dx in range(18):
		var x = base_x + (dx - 8) * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, 11, outline)
	
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
			# Add black outline at the bottom of the foot
			if pixel_y == 63:
				for dx in range(6):
					var x = base_x + (dx - 5) * dir
					if x >= 0 and x < 32:
						img.set_pixel(x, pixel_y, outline)

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
			# Add black outline at the bottom of the foot
			if y == 63:
				for dx in range(7):
					var x = base_x + (dx - 1) * dir
					if x >= 0 and x < 32:
						img.set_pixel(x, y, outline)

func draw_character_side(img: Image, skin: Color, hair: Color, leather: Color, leather_dark: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int, flip_x: bool):
	# Side-facing character (32x64 - scaled 2x horizontal, 4x vertical)
	# walk_frame determines leg position: 0,2 = standing, 1,3 = walking
	
	var base_x = 16  # Center of 32-pixel width
	var dir = 1 if not flip_x else -1
	
	# Upper body/chest (rows 32-39) - moved below neck to avoid overlap
	for y in range(32, 40):
		for dx in range(18):
			var x = base_x + (dx - 9) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, leather)
	for y in range(32, 40):
		var x = base_x + 9 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, outline)
		x = base_x - 9 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, outline)
	for dx in range(18):
		var x = base_x + (dx - 9) * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, 32, outline)
			img.set_pixel(x, 39, outline)
	
	# Head (rows 12-23) - bald head, no helmet
	for y in range(12, 24):
		for dx in range(14):  # Match front width
			var x = base_x + (dx - 6) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, skin)
	
	# Head outline - sides
	for y in range(12, 24):
		var x = base_x + 8 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, outline)
		x = base_x - 6 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, outline)
	
	# Top and bottom outline
	for dx in range(16):  # Fill top and bottom completely from -6 to 8
		var x = base_x + (dx - 7) * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, 11, outline)
			img.set_pixel(x, 24, outline)
	
	# Eye - rows 18-21
	var eye_x = base_x + 6 * dir
	if eye_x >= 0 and eye_x < 32:
		for y in range(18, 22):
			img.set_pixel(eye_x, y, outline)
	
	# Nose - row 21
	var nose_x = base_x + 6 * dir
	if nose_x >= 0 and nose_x < 32:
		img.set_pixel(nose_x, 21, Color(0.85, 0.7, 0.5))
	
	# Neck - rows 24-31 (extended to connect with body)
	for y in range(24, 32):
		for dx in range(10):  # Match front proportions
			var x = base_x + (dx - 4) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, skin)
		var outline_x1 = base_x + 6 * dir
		var outline_x2 = base_x - 4 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	
	# Body - rows 32-47
	for y in range(32, 48):
		for dx in range(18):  # Match front width (7-24 = 17 pixels)
			var x = base_x + (dx - 6) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, leather)
		var outline_x1 = base_x + 12 * dir
		var outline_x2 = base_x - 6 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	
	# Armor detail - vertical strap
	for y in range(32, 48):  # 27-39 → 32-48
		var x = base_x + 4 * dir  # 2 → 4
		if x >= 0 and x < 32:
			img.set_pixel(x, y, leather_dark)
	# Horizontal straps
	for dx in range(14):
		var x = base_x + (dx - 4) * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, 34, leather_dark)
			img.set_pixel(x, 38, leather_dark)
	
	# Front arm
	var front_arm_offset = 0
	if walk_frame == 1:
		front_arm_offset = -12  # -3 → -12
	elif walk_frame == 3:
		front_arm_offset = 12  # 3 → 12
	
	var arm_x = base_x + 10 * dir  # 5 → 10
	for y in range(max(36, 36 + front_arm_offset), min(48, 48 + front_arm_offset)):  # 30-38 → 36-48
		if y >= 0 and y < 64 and arm_x >= 0 and arm_x < 32:
			for dx in range(4):  # More width
				var x = arm_x + dx * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, y, skin)
			var outline_x = arm_x + 4 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, y, outline)
	
	# Sword (held in front arm with up/down movement)
	var sword_x = base_x + 14 * dir
	var sword_offset = 0
	if walk_frame == 1:
		sword_offset = -5  # Sword moves up more visibly
	elif walk_frame == 3:
		sword_offset = 5  # Sword moves down more visibly
	
	# Handle
	for y in range(max(44, 44 + sword_offset), min(50, 50 + sword_offset)):
		if y >= 0 and y < 64 and sword_x >= 0 and sword_x < 32:
			img.set_pixel(sword_x, y, handle)
	
	# Blade (pointing up-forward)
	for y in range(max(26, 26 + sword_offset), min(44, 44 + sword_offset)):
		if y >= 0 and y < 64 and sword_x >= 0 and sword_x < 32:
			img.set_pixel(sword_x, y, metal)
			var blade_x2 = sword_x + dir
			if blade_x2 >= 0 and blade_x2 < 32 and y < 43:
				img.set_pixel(blade_x2, y, metal)
	
	# Blade outlines (move with sword)
	var blade_outline_x = sword_x - dir
	for y in range(max(26, 26 + sword_offset), min(44, 44 + sword_offset)):
		if y >= 0 and y < 64 and blade_outline_x >= 0 and blade_outline_x < 32:
			img.set_pixel(blade_outline_x, y, outline)
	
	# Sword tip (moves with sword)
	var tip_y = max(0, 24 + sword_offset)
	if tip_y >= 0 and tip_y < 64:
		if sword_x >= 0 and sword_x < 32:
			img.set_pixel(sword_x, tip_y, outline)
		var tip_x2 = sword_x + dir
		if tip_x2 >= 0 and tip_x2 < 32:
			img.set_pixel(tip_x2, tip_y, outline)
		# Left outline at tip
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
		# Outline at gap row
		var gap_outline_x = sword_x - dir
		if gap_outline_x >= 0 and gap_outline_x < 32:
			img.set_pixel(gap_outline_x, gap_y, outline)
	
	# Pants - rows 48-59
	for y in range(48, 60):
		for dx in range(14):  # Match front width (9-22 = 13 pixels)
			var x = base_x + (dx - 4) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, pants)
		var outline_x1 = base_x + 10 * dir
		var outline_x2 = base_x - 4 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	
	# Legs with pronounced animation
	var front_leg_offset = 0
	var back_leg_offset = 0
	
	if walk_frame == 0:
		front_leg_offset = 0
		back_leg_offset = 0
	elif walk_frame == 1:
		front_leg_offset = 8  # 4 → 8 (scaled proportionally)
		back_leg_offset = -8  # -4 → -8
	elif walk_frame == 2:
		front_leg_offset = 0
		back_leg_offset = 0
	elif walk_frame == 3:
		front_leg_offset = -8  # -4 → -8
		back_leg_offset = 8  # 4 → 8
	
	# Back leg - rows 60-63
	for y in range(60, 64):  # Fill to bottom
		var pixel_y = y + back_leg_offset
		if pixel_y >= 0 and pixel_y < 64:
			for dx in range(6):  # Widen to match pants better
				var x = base_x + (dx - 5) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, pixel_y, pants)
			var outline_x = base_x - 5 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, pixel_y, outline)
	
	# Front leg - rows 60-63
	for y in range(60, 64):
		var pixel_y = y + front_leg_offset
		if pixel_y >= 0 and pixel_y < 64:
			for dx in range(7):  # Widen to match pants
				var x = base_x + (dx - 1) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, pixel_y, pants)
			var outline_x = base_x + 6 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, pixel_y, outline)
	
	# Feet (at bottom of canvas)
	var back_foot_start = min(60, 60 + back_leg_offset)
	var back_foot_end = min(64, 64 + back_leg_offset)
	for y in range(max(0, back_foot_start), back_foot_end):
		if y >= 0 and y < 64:
			for dx in range(6):
				var x = base_x + (dx - 5) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, y, outline)
	
	var front_foot_start = min(60, 60 + front_leg_offset)
	var front_foot_end = min(64, 64 + front_leg_offset)
	for y in range(max(0, front_foot_start), front_foot_end):
		if y >= 0 and y < 64:
			for dx in range(7):
				var x = base_x + (dx - 1) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, y, outline)

func _input(event):
	# Handle click-to-move
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_moving:
			var click_position = get_global_mouse_position()
			move_to_position(click_position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var click_position = get_global_mouse_position()
			handle_target_click(click_position)
			get_viewport().set_input_as_handled()

func handle_target_click(click_position: Vector2):
	# Convert click position to tile center
	var clicked_tile_x = floor(click_position.x / TILE_SIZE)
	var clicked_tile_y = floor(click_position.y / TILE_SIZE)
	var clicked_tile_center = Vector2(clicked_tile_x * TILE_SIZE + TILE_SIZE/2, clicked_tile_y * TILE_SIZE + TILE_SIZE/2)
	
	# Check if there's an enemy on this tile
	if orc_reference == null:
		var parent = get_parent()
		if parent:
			orc_reference = parent.find_child("Orc", true, false)
	
	if orc_reference != null:
		# The targetable tile is the lower of the two tiles the sprite occupies
		var orc_targetable_tile = orc_reference.position + Vector2(0, TILE_SIZE/2)
		var orc_targetable_tile_x = floor(orc_targetable_tile.x / TILE_SIZE)
		var orc_targetable_tile_y = floor(orc_targetable_tile.y / TILE_SIZE)
		var orc_targetable_tile_center = Vector2(orc_targetable_tile_x * TILE_SIZE + TILE_SIZE/2, orc_targetable_tile_y * TILE_SIZE + TILE_SIZE/2)
		
		# If clicking on orc's targetable tile
		if clicked_tile_center == orc_targetable_tile_center:
			# Toggle targeting
			if targeted_enemy == orc_reference:
				# Untarget
				targeted_enemy = null
				orc_reference.is_targeted = false
				print("[TARGET] Untargeted enemy")
			else:
				# Target
				targeted_enemy = orc_reference
				orc_reference.is_targeted = true
				print("[TARGET] Targeted enemy at ", orc_reference.position)
			
			# Notify orc to redraw
			orc_reference.queue_redraw()

func perform_attack(target: Node):
	# Calculate damage based on strength and some randomness
	var damage = strength + randi_range(-2, 2)
	
	# Apply damage to target
	if target.has_meta("current_health"):
		var current_hp = target.get_meta("current_health")
		var new_hp = max(0, current_hp - damage)
		target.set_meta("current_health", new_hp)
		target.current_health = new_hp
		
		print("[ATTACK] Dealt ", damage, " damage to ", target.name, ". HP: ", new_hp, "/", target.get_meta("max_health"))
		
		# Update target's health bar
		if target.has_node("HealthBar"):
			target.get_node("HealthBar").queue_redraw()
		
		# Check if enemy died
		if new_hp <= 0 and target.has_method("die"):
			target.die()

func move_to_position(target: Vector2):
	# Convert click position to tile coordinates (where we want feet to land)
	var clicked_tile_x = floor(target.x / TILE_SIZE)
	var clicked_tile_y = floor(target.y / TILE_SIZE)
	var clicked_tile_center = Vector2(clicked_tile_x * TILE_SIZE + TILE_SIZE/2, clicked_tile_y * TILE_SIZE + TILE_SIZE/2)
	
	print("[MOVE_TO] Clicked at world pos ", target, " (tile: ", clicked_tile_x, ",", clicked_tile_y, ") center: ", clicked_tile_center)
	
	var parent = get_parent()
	if not parent:
		print("[MOVE_TO] ERROR: No parent!")
		return
	
	var world = parent.get_node_or_null("World")
	
	# Check if clicked tile is walkable
	if world and world.has_method("is_walkable"):
		if not world.is_walkable(clicked_tile_center):
			print("[MOVE_TO] Target tile not walkable")
			return  # Can't walk there
	
	# Check if position is occupied by another entity
	if is_position_occupied(clicked_tile_center):
		print("[COLLISION] Target tile occupied at ", clicked_tile_center, ", cannot move")
		return  # Can't walk there, occupied
	else:
		print("[PATHFIND] Target tile at ", clicked_tile_center, " is free, proceeding with pathfinding")
	
	# Get current tile
	var current_tile_x = floor(position.x / TILE_SIZE)
	var current_tile_y = floor(position.y / TILE_SIZE)
	var current_tile_center = Vector2(current_tile_x * TILE_SIZE + TILE_SIZE/2, current_tile_y * TILE_SIZE + TILE_SIZE/2)
	
	# Player center needs to be one tile above where feet will land
	var target_player_tile_y = clicked_tile_y - 1
	var target_tile_center = Vector2(clicked_tile_x * TILE_SIZE + TILE_SIZE/2, target_player_tile_y * TILE_SIZE + TILE_SIZE/2)
	
	# If clicking on current tile, do nothing (don't change facing)
	if current_tile_center == target_tile_center:
		print("[MOVE_TO] Already at target tile")
		return
	
	# Find path using A* pathfinding
	var path = find_path(current_tile_center, target_tile_center)
	
	if path.size() > 1:
		# Remove first position (current position)
		path.remove_at(0)
		path_queue = path
		print("[MOVE_TO] Path found with ", path.size(), " waypoints")
		# Start moving to first waypoint
		process_next_path_step()
	elif path.size() == 1 and current_tile_center == target_tile_center:
		# Already at destination
		print("[MOVE_TO] Already at destination")
		return
	elif path.size() == 0:
		# No path found - try direct movement if adjacent
		var dist = current_tile_center.distance_to(target_tile_center)
		if dist <= TILE_SIZE * 1.5:  # Adjacent tile (including diagonal)
			print("[MOVE_TO] Direct movement to adjacent tile")
			path_queue = [target_tile_center]
			process_next_path_step()
		else:
			print("[MOVE_TO] No path found and target not adjacent")
	else:
		print("[MOVE_TO] Unexpected path size: ", path.size())

func find_path(start: Vector2, goal: Vector2) -> Array:
	var parent = get_parent()
	if not parent:
		print("[PATHFIND] ERROR: No parent!")
		return []
	
	var world = parent.get_node_or_null("World")
	
	# If no world or clicked on current tile, return empty path
	if not world:
		print("[PATHFIND] ERROR: No world found!")
		return []
	
	if start == goal:
		print("[PATHFIND] Start equals goal, returning empty path")
		return []
	
	# Check if goal is walkable (apply feet offset)
	if world.has_method("is_walkable"):
		var feet_offset = Vector2(0, TILE_SIZE / 2)
		var goal_feet = goal + feet_offset
		var goal_tile_x = floor(goal_feet.x / TILE_SIZE)
		var goal_tile_y = floor(goal_feet.y / TILE_SIZE)
		var goal_tile_center = Vector2(goal_tile_x * TILE_SIZE + TILE_SIZE/2, goal_tile_y * TILE_SIZE + TILE_SIZE/2)
		if not world.is_walkable(goal_tile_center):
			print("[PATHFIND] Goal is not walkable")
			return []
	
	# A* pathfinding
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: heuristic(start, goal)}
	var closed_set = {}  # Track visited nodes for efficiency
	var iterations = 0
	var max_iterations = 50000  # Increased limit for longer paths
	
	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		# Find node with lowest f_score (with tiebreaker for better paths)
		var current = open_set[0]
		var current_f = f_score.get(current, INF)
		var current_h = heuristic(current, goal)
		for node in open_set:
			var node_f = f_score.get(node, INF)
			if node_f < current_f:
				current = node
				current_f = node_f
				current_h = heuristic(node, goal)
			elif abs(node_f - current_f) < 0.01:  # Tie-breaking: prefer node closer to goal
				var node_h = heuristic(node, goal)
				if node_h < current_h:
					current = node
					current_f = node_f
					current_h = node_h
		
		# Reached goal
		if current == goal:
			return reconstruct_path(came_from, current)
		
		open_set.erase(current)
		closed_set[current] = true
		
		# Check all neighbors (8 directions)
		var neighbors = get_neighbors(current)
		for neighbor in neighbors:
			# Skip if already fully evaluated
			if neighbor in closed_set:
				continue
			
			# Skip if not walkable (apply feet offset)
			if world and world.has_method("is_walkable"):
				var feet_offset = Vector2(0, TILE_SIZE / 2)
				var feet_position = neighbor + feet_offset
				var tile_x = floor(feet_position.x / TILE_SIZE)
				var tile_y = floor(feet_position.y / TILE_SIZE)
				var tile_center = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
				
				if not world.is_walkable(tile_center):
					continue
			
			# Skip if occupied by entity (strict check - only exact tile)
			if is_position_occupied_strict(neighbor):
				continue
			
			# Calculate tentative g_score
			var tentative_g = g_score.get(current, INF) + current.distance_to(neighbor)
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				# Prefer diagonal movement by reducing its effective cost
				var move_dir = (neighbor - current).normalized()
				var is_diagonal = abs(move_dir.x) > 0.5 and abs(move_dir.y) > 0.5
				var diagonal_bonus = -3.0 if is_diagonal else 0.0
				f_score[neighbor] = tentative_g + heuristic(neighbor, goal) + diagonal_bonus
				
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	# No path found
	if iterations >= max_iterations:
		print("Pathfinding exceeded max iterations (", max_iterations, "). Path may be too complex.")
	else:
		print("No path found from ", start, " to ", goal)
	return []

func get_neighbors(tile_center: Vector2) -> Array:
	var neighbors = []
	var world = get_parent().get_node_or_null("World")
	
	# Get center tile coordinates
	var tile_x = floor(tile_center.x / TILE_SIZE)
	var tile_y = floor(tile_center.y / TILE_SIZE)
	
	# 8 directions (interleave cardinal and diagonal for fair evaluation)
	var directions = [
		Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),  
		Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)
	]
	
	for dir in directions:
		var neighbor_x = tile_x + dir.x
		var neighbor_y = tile_y + dir.y
		var neighbor_center = Vector2(neighbor_x * TILE_SIZE + TILE_SIZE/2, neighbor_y * TILE_SIZE + TILE_SIZE/2)
		
		# Check all neighbors - walkability is already enforced in main loop
		neighbors.append(neighbor_center)
	
	return neighbors

func heuristic(a: Vector2, b: Vector2) -> float:
	# Diagonal distance heuristic (Chebyshev/Octile distance)
	var dx = abs(a.x - b.x) / TILE_SIZE
	var dy = abs(a.y - b.y) / TILE_SIZE
	# Cost: D * max(dx, dy) + (D2 - D) * min(dx, dy)
	# where D = cost of cardinal move, D2 = cost of diagonal move
	# For us: D = TILE_SIZE, D2 = sqrt(2) * TILE_SIZE
	var D = TILE_SIZE
	var D2 = sqrt(2) * TILE_SIZE
	return D * max(dx, dy) + (D2 - D) * min(dx, dy)

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while current in came_from:
		current = came_from[current]
		path.insert(0, current)
	return path

func process_next_path_step():
	if path_queue.size() > 0 and not is_moving:
		var next_tile = path_queue[0]
		path_queue.remove_at(0)
		
		# Verify tile is still walkable before moving (with feet offset)
		var parent = get_parent()
		if not parent:
			print("[PATHSTEP] ERROR: No parent!")
			path_queue.clear()
			return
		
		var world = parent.get_node_or_null("World")
		if world and world.has_method("is_walkable"):
			var feet_offset = Vector2(0, TILE_SIZE / 2)
			var feet_position = next_tile + feet_offset
			var tile_x = floor(feet_position.x / TILE_SIZE)
			var tile_y = floor(feet_position.y / TILE_SIZE)
			var tile_center = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
			
			if not world.is_walkable(tile_center):
				# Path is blocked, clear queue and stop
				print("[PATHSTEP] Next tile is no longer walkable")
				path_queue.clear()
				return
		
		# Check if the next position is occupied by another entity
		if is_position_occupied(next_tile):
			var tile_x = floor(next_tile.x / TILE_SIZE)
			var tile_y = floor(next_tile.y / TILE_SIZE)
			print("[PATHSTEP] Path blocked by entity at tile (", tile_x, ",", tile_y, ")")
			# Path is blocked by an entity, clear queue and stop
			path_queue.clear()
			return
		
		# Calculate direction to next tile
		var raw_direction = next_tile - position
		var dx = sign(raw_direction.x)
		var dy = sign(raw_direction.y)
		
		# Calculate the tile offset for this step
		var tile_offset = Vector2(dx, dy)
		
		# Detect if direction changed from last step
		var direction_changed = (tile_offset != last_path_direction)
		
		var new_direction = current_direction
		
		# Only change facing if the direction actually changed
		if direction_changed:
			# Simple facing logic: face the direction of movement
			# If moving diagonally, prefer the component that's not backwards
			var facing_h = Vector2(dx, 0) if dx != 0 else Vector2.ZERO
			var facing_v = Vector2(0, dy) if dy != 0 else Vector2.ZERO
			
			# Determine which direction to face based on movement
			if facing_h != Vector2.ZERO and facing_v != Vector2.ZERO:
				# Diagonal movement - pick the component that's not backwards
				var h_is_backwards = (facing_h == -current_direction)
				var v_is_backwards = (facing_v == -current_direction)
				
				if h_is_backwards and not v_is_backwards:
					new_direction = facing_v
				elif v_is_backwards and not h_is_backwards:
					new_direction = facing_h
				else:
					# Both forward or both backward - prefer based on current facing
					if current_direction.x != 0:
						new_direction = facing_v
					else:
						new_direction = facing_h
			elif facing_h != Vector2.ZERO:
				# Pure horizontal movement
				new_direction = facing_h
			elif facing_v != Vector2.ZERO:
				# Pure vertical movement
				new_direction = facing_v
		
		current_direction = new_direction
		last_path_direction = tile_offset
		
		# Set target and start moving
		target_position = next_tile
		is_moving = true

func _physics_process(delta):
	# Check for keyboard input first - if any keyboard input, cancel pathfinding
	var input_dir = Vector2.ZERO
	
	# Support diagonal movement with keyboard
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	
	# If keyboard input detected, cancel click-to-move pathfinding
	if input_dir != Vector2.ZERO:
		path_queue.clear()
	
	if is_moving:
		# Smoothly move towards target position
		var direction = (target_position - position).normalized()
		var distance = position.distance_to(target_position)
		
		# Play walking animation
		update_animation(current_direction, true)
		
		if distance < MOVE_SPEED * delta:
			# Snap to target when close enough
			position = target_position
			var tile_x = floor(position.x / TILE_SIZE)
			var tile_y = floor(position.y / TILE_SIZE)
			print("[MOVE_COMPLETE] Snapped to tile (", tile_x, ",", tile_y, ") at pos ", position)
			is_moving = false
			# Process next step in path
			process_next_path_step()
			# If no more path, switch to idle
			if not is_moving:
				update_animation(current_direction, false)
		else:
			# Move smoothly towards target
			position += direction * MOVE_SPEED * delta
	else:
		# Check for keyboard input when not moving
		# input_dir already calculated above
		
		if input_dir != Vector2.ZERO:
			# Check if Control is held - just change facing without moving
			if Input.is_key_pressed(KEY_CTRL):
				# Normalize for diagonal detection
				input_dir = input_dir.normalized()
				
				# Update facing direction
				if abs(input_dir.x) > abs(input_dir.y):
					current_direction = Vector2.RIGHT if input_dir.x > 0 else Vector2.LEFT
				else:
					current_direction = Vector2.DOWN if input_dir.y > 0 else Vector2.UP
				
				# Update to idle animation in new direction
				update_animation(current_direction, false)
			else:
				# Normal movement
				# Calculate tile offset for diagonal detection
				var tile_offset = Vector2(sign(input_dir.x), sign(input_dir.y))
				
				# Detect if input changed from last frame
				var input_changed = (tile_offset != last_input_direction)
				
				var new_direction = current_direction
				
				# Only change facing if the input actually changed
				if input_changed:
					# Simple facing logic: face the direction of the input
					# If pressing multiple keys, prefer the one that's not backwards
					var facing_h = Vector2(tile_offset.x, 0) if tile_offset.x != 0 else Vector2.ZERO
					var facing_v = Vector2(0, tile_offset.y) if tile_offset.y != 0 else Vector2.ZERO
					
					# Determine which direction to face based on input
					if facing_h != Vector2.ZERO and facing_v != Vector2.ZERO:
						# Diagonal input - pick the component that's not backwards
						var h_is_backwards = (facing_h == -current_direction)
						var v_is_backwards = (facing_v == -current_direction)
						
						if h_is_backwards and not v_is_backwards:
							new_direction = facing_v
						elif v_is_backwards and not h_is_backwards:
							new_direction = facing_h
						else:
							# Both forward or both backward - prefer based on current facing
							if current_direction.x != 0:
								new_direction = facing_v
							else:
								new_direction = facing_h
					elif facing_h != Vector2.ZERO:
						# Pure horizontal input
						new_direction = facing_h
					elif facing_v != Vector2.ZERO:
						# Pure vertical input
						new_direction = facing_v
				
				current_direction = new_direction
				last_input_direction = tile_offset
				
				# Calculate next tile position using integer offsets
				var next_position = position + tile_offset * TILE_SIZE
				
				# Check if the next tile is walkable (check the tile below for feet)
				var world = get_parent().get_node_or_null("World")
				var feet_offset = Vector2(0, TILE_SIZE / 2)
				var can_move = false
				
				if world and world.has_method("is_walkable"):
					# For vertical sprite, check the tile below the character center
					var feet_position = next_position + feet_offset
					# Snap to tile center for lookup
					var tile_x = floor(feet_position.x / TILE_SIZE)
					var tile_y = floor(feet_position.y / TILE_SIZE)
					var tile_center = Vector2(tile_x * TILE_SIZE + TILE_SIZE/2, tile_y * TILE_SIZE + TILE_SIZE/2)
					
					can_move = world.is_walkable(tile_center)
					
					# For diagonal movement, also check that at least one adjacent tile is walkable
					# This prevents cutting corners through walls/water
				
				# Also check for entity collision
				if can_move and is_position_occupied(next_position):
					var tile_x = floor(next_position.x / TILE_SIZE)
					var tile_y = floor(next_position.y / TILE_SIZE)
					print("[KEYBOARD_MOVE] Blocked by entity at tile (", tile_x, ",", tile_y, ")")
					can_move = false
				
				if can_move:
					# Only update facing direction when movement is confirmed
					current_direction = new_direction
					target_position = next_position
					is_moving = true
	var world = get_parent().get_node_or_null("World")
	if world and world.has_method("update_world"):
		world.update_world(global_position)
	
	# Update z_index based on y position to ensure proper layering
	# Clamp to valid range to avoid exceeding Godot's z_index limits
	z_index = clampi(int(position.y / 10) + 1000, 0, 10000)

func update_animation(direction: Vector2, walking: bool):
	var anim_name = "walk_" if walking else "idle_"
	
	# Cardinal directions only
	if direction == Vector2.UP:
		anim_name += "up"
	elif direction == Vector2.DOWN:
		anim_name += "down"
	elif direction == Vector2.LEFT:
		anim_name += "left"
	elif direction == Vector2.RIGHT:
		anim_name += "right"
	
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func is_position_occupied(target_position: Vector2) -> bool:
	# Check if any entity occupies this position
	# Use the cached orc reference
	if orc_reference == null:
		# Try to find it again
		var parent = get_parent()
		if parent:
			orc_reference = parent.find_child("Orc", true, false)
	
	if orc_reference != null:
		var distance = target_position.distance_to(orc_reference.position)
		# Prevent occupying same tile - use stricter collision
		var is_colliding = distance < TILE_SIZE
		print("[COLLISION CHECK] Target: ", target_position, " vs Orc: ", orc_reference.position, " Distance: ", distance, " Threshold: ", TILE_SIZE, " BLOCKED: ", is_colliding)
		return is_colliding
	else:
		print("[COLLISION] WARNING: Orc reference still not found!")
		return false
	
	return false

func is_position_occupied_strict(target_position: Vector2) -> bool:
	# Strict collision check for pathfinding - only block the exact tile
	# This prevents pathfinding from getting stuck in a constrained search space
	if orc_reference == null:
		var parent = get_parent()
		if parent:
			orc_reference = parent.find_child("Orc", true, false)
	
	if orc_reference != null:
		var distance = target_position.distance_to(orc_reference.position)
		# Only block if very close (same tile, with small tolerance)
		var is_colliding = distance < 5.0
		return is_colliding
	
	return false

func die():
	# Player died - show game over screen
	print("[PLAYER_DIE] Player died at position ", position)
	
	# Get the main scene to show game over UI
	var main = get_parent()
	if main and main.has_method("show_game_over"):
		main.show_game_over()
	
	# For now, just remove the player
	queue_free()
