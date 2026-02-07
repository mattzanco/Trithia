extends CharacterBody2D

# Enemy base controller

const TILE_SIZE = 32
const DRAGGABLE_SCRIPT = preload("res://scripts/draggable_item.gd")
const MOVE_SPEED = 120.0  # Pixels per second
const WALK_DISTANCE = 3  # How many tiles to walk before changing direction
const COLLISION_RADIUS = 10.0  # Distance to check for collisions
const FEET_OFFSET = Vector2(0, TILE_SIZE / 2)

var animated_sprite: AnimatedSprite2D
var current_direction = Vector2.DOWN
var last_movement_direction = Vector2.ZERO  # Track actual movement direction to prevent flip-flopping

# Movement variables
var is_moving = false
var target_position = Vector2.ZERO
var player = null
var world = null

# AI State
enum AIState { IDLE, CHASE, SURROUND }
var current_state = AIState.IDLE
var last_player_tile = Vector2.ZERO

# Surround behavior timer
var surround_move_timer = 0.0
var surround_move_interval = 3.0  # Move to new position every 3 seconds

# Patrol behavior
var patrol_move_timer = 0.0
var patrol_move_interval = 1.5  # Average delay between patrol steps

# Position tracking to detect stuck/oscillating movement
var recent_positions = []
var max_position_history = 6
var stuck_check_timer = 0.0
var stuck_wait_timer = 0.0
var blacklisted_tiles = {}  # Tiles to avoid temporarily
var blacklist_duration = 3.0  # How long to avoid a tile

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
var has_weapon = true

# Door interaction / building chase
var is_humanoid = false
var last_known_player_building: Node = null
var last_known_player_door_tile: Vector2i = Vector2i.ZERO
var pathfinding_target_building: Node = null
var last_chase_goal: Vector2 = Vector2.ZERO

# Combat tuning
var attack_cooldown = 2.5  # Attacks slower than player
var detection_range = 700.0  # Detect player just before they become visible on screen

# Targeting system
var is_targeted = false

# Combat system
var targeted_enemy = null
var attack_timer = 0.0

# Visual identity
var enemy_name = "Enemy"
var skin_color = Color(0.4, 0.7, 0.4)
var dark_skin_color = Color(0.2, 0.5, 0.2)
var hair_color = Color(0.3, 0.2, 0.1)
var muscle_shadow_color = Color(0.25, 0.55, 0.25)
var pants_color = Color(0.5, 0.4, 0.3)
var outline_color = Color(0.1, 0.1, 0.1)
var metal_color = Color(0.7, 0.7, 0.75)
var handle_color = Color(0.4, 0.3, 0.2)

func configure_enemy():
	# Subclasses override to set stats and palette.
	return

func _ready():
	configure_enemy()
	
	# Get the AnimatedSprite2D node
	animated_sprite = $AnimatedSprite2D
	
	if animated_sprite == null:
		return
	
	# Get reference to the player and world for collision detection
	player = get_player_node()
	world = get_world_node()
	if player == null or world == null:
		return
	
	# Create animated sprite with walking animations
	create_orc_animations()
	add_to_group("enemies")
	
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
	set_process_input(true)

func get_player_node() -> Node:
	var parent = get_parent()
	if parent:
		var player_node = parent.find_child("Player", true, false)
		if player_node:
			return player_node
	return get_tree().get_root().find_child("Player", true, false)

func get_world_node() -> Node:
	var parent = get_parent()
	if parent:
		var world_node = parent.find_child("World", true, false)
		if world_node:
			return world_node
	return get_tree().get_root().find_child("World", true, false)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.shift_pressed:
		var mouse_pos = get_global_mouse_position()
		if get_pick_rect().has_point(mouse_pos):
			DRAGGABLE_SCRIPT.show_center_text(get_enemy_description(), self)
			get_viewport().set_input_as_handled()
			return

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
	
	var skin = skin_color
	var dark_skin = dark_skin_color
	var hair = hair_color
	var muscle = muscle_shadow_color
	var pants = pants_color
	var outline = outline_color
	var metal = metal_color
	var handle = handle_color
	
	if direction == Vector2.UP:
		draw_orc_back(img, skin, dark_skin, hair, muscle, pants, outline, metal, handle, frame)
	elif direction == Vector2.DOWN:
		draw_orc_front(img, skin, dark_skin, hair, muscle, pants, outline, metal, handle, frame)
	elif direction == Vector2.LEFT:
		draw_orc_side(img, skin, dark_skin, hair, muscle, pants, outline, metal, handle, frame, true)
	elif direction == Vector2.RIGHT:
		draw_orc_side(img, skin, dark_skin, hair, muscle, pants, outline, metal, handle, frame, false)
	
	var texture = ImageTexture.create_from_image(img)
	return texture

func get_pick_rect() -> Rect2:
	if animated_sprite and animated_sprite.sprite_frames:
		var anim_name = animated_sprite.animation
		if anim_name == "":
			anim_name = animated_sprite.sprite_frames.get_animation_names()[0] if animated_sprite.sprite_frames.get_animation_names().size() > 0 else ""
		if anim_name != "":
			var frame_tex = animated_sprite.sprite_frames.get_frame_texture(anim_name, 0)
			if frame_tex:
				var size = frame_tex.get_size()
				var top_left = animated_sprite.global_position + animated_sprite.offset - size / 2.0
				return Rect2(top_left, size)
	return Rect2(global_position + Vector2(-16, -56), Vector2(32, 64))

func get_enemy_description() -> String:
	return "%s\nHP: %d/%d\nSTR: %d  DEX: %d  INT: %d" % [enemy_name, current_health, max_health, strength, dexterity, intelligence]

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
	
	if has_weapon:
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
	
	if has_weapon:
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
				img.set_pixel(outline_x, y, outline)
	
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
	# Handle attack cooldown
	if attack_timer > 0.0:
		attack_timer -= delta
	
	# Handle surround move timer
	if surround_move_timer > 0.0:
		surround_move_timer -= delta

	# Validate references
	if player != null and not is_instance_valid(player):
		player = null
	if targeted_enemy != null and not is_instance_valid(targeted_enemy):
		targeted_enemy = null

	# Patrol timer
	if patrol_move_timer > 0.0:
		patrol_move_timer -= delta
	
	# Update blacklist timers
	var expired_tiles = []
	for tile in blacklisted_tiles.keys():
		blacklisted_tiles[tile] -= delta
		if blacklisted_tiles[tile] <= 0:
			expired_tiles.append(tile)
	for tile in expired_tiles:
		blacklisted_tiles.erase(tile)
	
	# Handle stuck wait timer
	if stuck_wait_timer > 0.0:
		stuck_wait_timer -= delta
		# Make sure we're playing idle animation while waiting
		if not is_moving:
			var dir_name = get_direction_name(current_direction)
			if animated_sprite != null and animated_sprite.sprite_frames != null:
				var anim_name = "idle_" + dir_name
				if animated_sprite.animation != anim_name:
					animated_sprite.play(anim_name)
		return  # Don't move while waiting after being stuck
	
	# Track position periodically to detect oscillation
	stuck_check_timer += delta
	if stuck_check_timer >= 0.2:  # Check very frequently - every 0.2 seconds
		stuck_check_timer = 0.0
		
		# Record current tile position
		var current_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
		recent_positions.append(current_tile)
		
		# Keep only recent history
		if recent_positions.size() > max_position_history:
			recent_positions.pop_front()
		
		# Check if we're oscillating between positions (more sensitive check)
		if recent_positions.size() >= 4:
			# Check for simple back-and-forth (A-B-A-B pattern)
			var last_four = recent_positions.slice(-4)
			if last_four[0] == last_four[2] and last_four[1] == last_four[3] and last_four[0] != last_four[1]:
				# Oscillating detected! Blacklist both tiles and stop
				blacklisted_tiles[last_four[0]] = blacklist_duration
				blacklisted_tiles[last_four[1]] = blacklist_duration
				is_moving = false
				stuck_wait_timer = randf_range(0.5, 1.0)
				recent_positions.clear()
				
				# Set idle animation
				var dir_name = get_direction_name(current_direction)
				if animated_sprite != null and animated_sprite.sprite_frames != null:
					var anim_name = "idle_" + dir_name
					if animated_sprite.animation != anim_name:
						animated_sprite.play(anim_name)
				
				print("[ENEMY] Detected oscillation between tiles, waiting...")
				return
	
	# Check if player is in detection range
	if player != null:
		var distance_to_player = position.distance_to(player.position)
		var player_building = get_player_building()
		if targeted_enemy != null and not can_detect_player():
			# Keep chasing if we last saw the player enter a building
			if last_known_player_building == null and player_building == null:
				targeted_enemy = null
				current_state = AIState.IDLE
		elif targeted_enemy == null:
			# Only detect new target if we don't have one
			if distance_to_player <= detection_range and can_detect_player():
				targeted_enemy = player
				current_state = AIState.CHASE
		# Update memory of where the player entered
		if targeted_enemy != null:
			update_last_known_player_building()
	
	# Update AI state based on distance to player
	if targeted_enemy != null:
		var distance_to_target = position.distance_to(targeted_enemy.position)
		var goal_position = targeted_enemy.position
		var goal_building = get_player_building()
		var enemy_building = get_current_building()
		pathfinding_target_building = null
		if goal_building != null:
			if enemy_building == goal_building:
				goal_position = targeted_enemy.position
				pathfinding_target_building = goal_building
			elif is_building_door_open(goal_building):
				# Door is open - go to the door first, then pursue inside
				if is_on_door_tile(goal_building):
					goal_position = get_door_entry_center(goal_building)
					if goal_position == Vector2.ZERO:
						goal_position = targeted_enemy.position
					pathfinding_target_building = goal_building
				else:
					goal_position = get_door_queue_center(goal_building)
					if goal_position == Vector2.ZERO:
						goal_position = get_door_wait_center(goal_building)
					if goal_position == Vector2.ZERO:
						goal_position = get_door_center(goal_building)
						if goal_position == Vector2.ZERO:
							goal_position = targeted_enemy.position
			else:
				# Door is closed - move to approach tile, open if humanoid and player was seen entering
				goal_position = get_door_queue_center(goal_building)
				if goal_position == Vector2.ZERO:
					goal_position = get_door_wait_center(goal_building)
				if goal_position == Vector2.ZERO:
					goal_position = get_door_approach_center(goal_building)
				if last_known_player_building == goal_building:
					try_open_building_door(goal_building)
				if goal_position == Vector2.ZERO:
					goal_position = get_door_center(goal_building)
				if goal_position == Vector2.ZERO:
					goal_position = targeted_enemy.position
		elif enemy_building != null:
			# Player is outside, enemy is inside - exit through the door
			pathfinding_target_building = enemy_building
			if is_building_door_open(enemy_building):
				if is_on_door_tile(enemy_building):
					pathfinding_target_building = null
					goal_position = get_exit_queue_center(enemy_building)
					if goal_position == Vector2.ZERO:
						goal_position = get_door_exit_center(enemy_building)
						if goal_position == Vector2.ZERO:
							goal_position = targeted_enemy.position
				else:
					goal_position = get_door_center(enemy_building)
					if goal_position == Vector2.ZERO:
						goal_position = targeted_enemy.position
			else:
				# Door closed: move to interior entry tile and open when adjacent
				goal_position = get_door_entry_center(enemy_building)
				if can_open_doors() and is_near_door(enemy_building):
					try_open_building_door(enemy_building)
				if goal_position == Vector2.ZERO:
					goal_position = get_door_center(enemy_building)
					if goal_position == Vector2.ZERO:
						goal_position = targeted_enemy.position
		var goal_tile = Vector2(floor(goal_position.x / TILE_SIZE), floor(goal_position.y / TILE_SIZE))
		last_chase_goal = goal_position
		
		# Check if we're adjacent to the player (within 1.5 tiles)
		if distance_to_target < TILE_SIZE * 1.5 and enemy_building == goal_building and (goal_building == null or not is_on_door_tile(goal_building)):
			# Enter SURROUND state
			if current_state != AIState.SURROUND:
				current_state = AIState.SURROUND
				surround_move_timer = randf_range(1.0, 3.0)  # Random initial delay
			
			# Attack if cooldown is ready
			if attack_timer <= 0.0:
				perform_attack()
				attack_timer = attack_cooldown
			
			# Occasionally move to a different adjacent tile while surrounding
			if not is_moving:
				# Check if it's time to reposition
				if surround_move_timer <= 0.0:
					# Try to move to a different adjacent tile
					if try_surround_reposition():
						surround_move_timer = surround_move_interval + randf_range(-0.5, 0.5)
					else:
						# Couldn't find new position, try again soon
						surround_move_timer = 1.0
				
				# Play idle animation
				var dir_name = get_direction_name(current_direction)
				if animated_sprite != null and animated_sprite.sprite_frames != null:
					var anim_name = "idle_" + dir_name
					if animated_sprite.animation != anim_name:
						animated_sprite.play(anim_name)
		else:
			# Player is far - enter CHASE state
			if current_state != AIState.CHASE:
				current_state = AIState.CHASE
			
			# If player moved to a new tile OR we're not moving, try to move toward player
			if goal_tile != last_player_tile or not is_moving:
				last_player_tile = goal_tile
				
				# Only recalculate when we're not currently moving
				if not is_moving:
					if not move_toward_target_with_path(goal_position):
						if goal_position == targeted_enemy.position or (goal_building != null and enemy_building == goal_building):
							find_and_move_to_nearest_adjacent_tile()
						if not is_moving:
							try_step_toward(goal_position)
						if not is_moving:
							play_idle_animation()
	else:
		# No target - IDLE state
		current_state = AIState.IDLE
		if not is_moving and patrol_move_timer <= 0.0:
			# Random patrol step
			var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			dirs.shuffle()
			for dir in dirs:
				var next_tile = position + dir * TILE_SIZE
				if not is_walkable_for_enemy(next_tile):
					continue
				if is_tile_occupied_by_enemy(next_tile) or is_tile_reserved_by_enemy(next_tile):
					continue
				target_position = next_tile
				is_moving = true
				current_direction = dir
				last_movement_direction = dir
				break
			patrol_move_timer = randf_range(0.8, 2.0)
		
		if not is_moving:
			var dir_name = get_direction_name(current_direction)
			if animated_sprite != null and animated_sprite.sprite_frames != null:
				var anim_name = "idle_" + dir_name
				if animated_sprite.animation != anim_name:
					animated_sprite.play(anim_name)
	
	# Handle movement
	if is_moving:
		# Stalled movement: target equals current position
		if position.distance_to(target_position) <= 0.1:
			is_moving = false
			if current_state == AIState.CHASE and targeted_enemy != null and last_chase_goal != Vector2.ZERO:
				if not move_toward_target_with_path(last_chase_goal):
					find_and_move_to_nearest_adjacent_tile()
				if not is_moving:
					try_step_toward(last_chase_goal)
			if not is_moving:
				play_idle_animation()
			return
		var direction = (target_position - position).normalized()
		var distance = position.distance_to(target_position)
		
		# Check if feet are currently on water during movement - abort if so
		if world != null and world.has_method("get_terrain_type_from_noise"):
			var feet_pos = position + FEET_OFFSET
			var feet_tile_x = int(floor(feet_pos.x / TILE_SIZE))
			var feet_tile_y = int(floor(feet_pos.y / TILE_SIZE))
			var feet_terrain = world.get_terrain_type_from_noise(feet_tile_x, feet_tile_y)
			
			if feet_terrain == "water":
				# Stop immediately and snap back to last valid tile
				var my_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
				var my_tile_center = Vector2(my_tile.x * TILE_SIZE + TILE_SIZE/2, my_tile.y * TILE_SIZE + TILE_SIZE/2)
				
				# Find nearest non-water tile based on feet position
				var escape_dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
				for dir in escape_dirs:
					var escape_tile_pos = Vector2(my_tile.x + dir.x, my_tile.y + dir.y)
					var escape_center = Vector2(escape_tile_pos.x * TILE_SIZE + TILE_SIZE/2, escape_tile_pos.y * TILE_SIZE + TILE_SIZE/2)
					var escape_feet = escape_center + FEET_OFFSET
					var escape_feet_x = int(floor(escape_feet.x / TILE_SIZE))
					var escape_feet_y = int(floor(escape_feet.y / TILE_SIZE))
					var escape_feet_terrain = world.get_terrain_type_from_noise(escape_feet_x, escape_feet_y)
					if escape_feet_terrain != "water":
						position = escape_center
						break
				
				is_moving = false
				return
		
		if distance < MOVE_SPEED * delta:
			# Check if target tile feet position is still valid before snapping
			var target_valid = true
			
			# Check feet walkability
			if world != null and world.has_method("get_terrain_type_from_noise"):
				var target_feet = target_position + FEET_OFFSET
				var target_feet_x = int(floor(target_feet.x / TILE_SIZE))
				var target_feet_y = int(floor(target_feet.y / TILE_SIZE))
				var target_feet_terrain = world.get_terrain_type_from_noise(target_feet_x, target_feet_y)
				if target_feet_terrain == "water":
					target_valid = false
			
			# Check if player is on the target tile
			if target_valid and player != null and target_position.distance_to(player.position) < TILE_SIZE * 0.6:
				target_valid = false
			
			# Check if another enemy is on the target tile
			if target_valid and is_tile_occupied_by_enemy(target_position):
				target_valid = false

			# Check if another enemy is already moving to the target tile
			if target_valid and is_tile_reserved_by_enemy(target_position):
				target_valid = false

			# Check building walkability
			if target_valid and not is_walkable_for_enemy(target_position):
				target_valid = false
			
			if target_valid:
				# Snap to target position
				position = target_position
				is_moving = false
				
				# If we just reached a tile and player moved, immediately pursue
				if current_state == AIState.CHASE and targeted_enemy != null:
					var chase_goal = targeted_enemy.position
					var chase_building = get_player_building()
					var chase_enemy_building = get_current_building()
					pathfinding_target_building = null
					if chase_building != null:
						if chase_enemy_building == chase_building:
							chase_goal = targeted_enemy.position
							pathfinding_target_building = chase_building
						elif is_building_door_open(chase_building):
							if is_on_door_tile(chase_building):
								chase_goal = get_door_entry_center(chase_building)
								if chase_goal == Vector2.ZERO:
									chase_goal = targeted_enemy.position
								pathfinding_target_building = chase_building
							else:
								chase_goal = get_door_queue_center(chase_building)
								if chase_goal == Vector2.ZERO:
									chase_goal = get_door_wait_center(chase_building)
								if chase_goal == Vector2.ZERO:
									chase_goal = get_door_center(chase_building)
									if chase_goal == Vector2.ZERO:
										chase_goal = targeted_enemy.position
						else:
							chase_goal = get_door_queue_center(chase_building)
							if chase_goal == Vector2.ZERO:
								chase_goal = get_door_wait_center(chase_building)
							if chase_goal == Vector2.ZERO:
								chase_goal = get_door_approach_center(chase_building)
							if last_known_player_building == chase_building:
								try_open_building_door(chase_building)
							if chase_goal == Vector2.ZERO:
								chase_goal = get_door_center(chase_building)
					elif chase_enemy_building != null:
						pathfinding_target_building = chase_enemy_building
						if is_building_door_open(chase_enemy_building):
							if is_on_door_tile(chase_enemy_building):
								pathfinding_target_building = null
								chase_goal = get_exit_queue_center(chase_enemy_building)
								if chase_goal == Vector2.ZERO:
									chase_goal = get_door_exit_center(chase_enemy_building)
									if chase_goal == Vector2.ZERO:
										chase_goal = targeted_enemy.position
							else:
								chase_goal = get_door_center(chase_enemy_building)
								if chase_goal == Vector2.ZERO:
									chase_goal = targeted_enemy.position
						else:
							chase_goal = get_door_entry_center(chase_enemy_building)
							if can_open_doors() and is_near_door(chase_enemy_building):
								try_open_building_door(chase_enemy_building)
							if chase_goal == Vector2.ZERO:
								chase_goal = get_door_center(chase_enemy_building)
								if chase_goal == Vector2.ZERO:
									chase_goal = targeted_enemy.position
					var chase_tile = Vector2(floor(chase_goal.x / TILE_SIZE), floor(chase_goal.y / TILE_SIZE))
					last_chase_goal = chase_goal
					if chase_tile != last_player_tile:
						last_player_tile = chase_tile
						if not move_toward_target_with_path(chase_goal):
							if chase_goal == targeted_enemy.position or (chase_building != null and chase_enemy_building == chase_building):
								find_and_move_to_nearest_adjacent_tile()
							if not is_moving:
								try_step_toward(chase_goal)
							if not is_moving:
								play_idle_animation()
			else:
				# Target tile became invalid - snap back to current tile and stop
				var my_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
				position = Vector2(my_tile.x * TILE_SIZE + TILE_SIZE/2, my_tile.y * TILE_SIZE + TILE_SIZE/2)
				is_moving = false
		else:
			# Check next position's feet before moving
			var next_pos = position + direction * MOVE_SPEED * delta
			if world != null and world.has_method("get_terrain_type_from_noise"):
				var next_feet = next_pos + FEET_OFFSET
				var next_feet_x = int(floor(next_feet.x / TILE_SIZE))
				var next_feet_y = int(floor(next_feet.y / TILE_SIZE))
				var next_feet_terrain = world.get_terrain_type_from_noise(next_feet_x, next_feet_y)
				if next_feet_terrain == "water":
					# About to move onto water - stop and snap to current tile
					var my_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
					position = Vector2(my_tile.x * TILE_SIZE + TILE_SIZE/2, my_tile.y * TILE_SIZE + TILE_SIZE/2)
					is_moving = false
					return
			
			# Move smoothly towards target
			position = next_pos
		
		# Update animation while moving
		var dir_name = get_direction_name(current_direction)
		if animated_sprite != null and animated_sprite.sprite_frames != null:
			var anim_name = "walk_" + dir_name
			if animated_sprite.animation != anim_name:
				animated_sprite.play(anim_name)
	else:
		# Not moving - check if feet are on water and need to escape
		if world != null and world.has_method("get_terrain_type_from_noise"):
			var feet_pos = position + FEET_OFFSET
			var feet_tile_x = int(floor(feet_pos.x / TILE_SIZE))
			var feet_tile_y = int(floor(feet_pos.y / TILE_SIZE))
			var feet_terrain = world.get_terrain_type_from_noise(feet_tile_x, feet_tile_y)
			
			if feet_terrain == "water":
				# Feet are on water! Find nearest walkable tile and move there immediately
				var my_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
				var escape_dirs = [
					Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT
				]
				
				for dir in escape_dirs:
					var escape_tile_pos = Vector2(my_tile.x + dir.x, my_tile.y + dir.y)
					var escape_tile_center = Vector2(escape_tile_pos.x * TILE_SIZE + TILE_SIZE/2, escape_tile_pos.y * TILE_SIZE + TILE_SIZE/2)
					var escape_feet = escape_tile_center + FEET_OFFSET
					var escape_feet_x = int(floor(escape_feet.x / TILE_SIZE))
					var escape_feet_y = int(floor(escape_feet.y / TILE_SIZE))
					var escape_feet_terrain = world.get_terrain_type_from_noise(escape_feet_x, escape_feet_y)
					
					if escape_feet_terrain != "water":
						# Teleport to safety
						position = escape_tile_center
						break
	
	# Update z_index only when not using Y-sorting
	var parent = get_parent()
	if not (parent is Node2D and parent.y_sort_enabled):
		z_index = clampi(int(position.y / 10) + 1000, 0, 10000)


func find_and_move_to_nearest_adjacent_tile():
	"""Find the nearest adjacent tile to the player and move toward it."""
	if targeted_enemy == null or world == null:
		return
	
	var player_tile = Vector2(floor(targeted_enemy.position.x / TILE_SIZE), floor(targeted_enemy.position.y / TILE_SIZE))
	var my_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
	
	# List all 4 adjacent tiles around the player (cardinal only)
	var adjacent_tiles = [
		Vector2(player_tile.x + 1, player_tile.y),  # Right
		Vector2(player_tile.x - 1, player_tile.y),  # Left
		Vector2(player_tile.x, player_tile.y + 1),  # Down
		Vector2(player_tile.x, player_tile.y - 1)   # Up
	]
	
	# Find the shortest valid path to any adjacent tile
	var best_path: Array = []
	var best_path_len = INF
	for tile_coords in adjacent_tiles:
		# Skip blacklisted tiles
		if blacklisted_tiles.has(tile_coords):
			continue
		var tile_center = Vector2(tile_coords.x * TILE_SIZE + TILE_SIZE/2, tile_coords.y * TILE_SIZE + TILE_SIZE/2)
		if not is_walkable_for_enemy(tile_center):
			continue
		if is_tile_occupied_by_enemy(tile_center) or is_tile_reserved_by_enemy(tile_center):
			continue
		var path = find_path(Vector2(my_tile.x * TILE_SIZE + TILE_SIZE/2, my_tile.y * TILE_SIZE + TILE_SIZE/2), tile_center)
		if path.size() <= 1:
			continue
		if path.size() < best_path_len:
			best_path = path
			best_path_len = path.size()

	if best_path.size() <= 1:
		return
	var next_step = best_path[1]
	if not is_walkable_for_enemy(next_step):
		return
	if player != null and next_step.distance_to(player.position) < TILE_SIZE * 0.6:
		return
	if is_tile_occupied_by_enemy(next_step) or is_tile_reserved_by_enemy(next_step):
		return
	var dx = sign(next_step.x - position.x)
	var dy = sign(next_step.y - position.y)
	current_direction = calculate_direction(int(dx), int(dy))
	last_movement_direction = Vector2(dx, dy)
	target_position = next_step
	is_moving = true
	return

func try_surround_reposition() -> bool:
	"""Try to move to a different adjacent tile around the player while in SURROUND state.
	Returns true if a new position was found and movement initiated."""
	if targeted_enemy == null or world == null:
		return false
	
	var player_tile = Vector2(floor(targeted_enemy.position.x / TILE_SIZE), floor(targeted_enemy.position.y / TILE_SIZE))
	var my_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
	
	# List all 4 adjacent tiles around the player (cardinal only)
	var adjacent_tiles = [
		Vector2(player_tile.x + 1, player_tile.y),  # Right
		Vector2(player_tile.x - 1, player_tile.y),  # Left
		Vector2(player_tile.x, player_tile.y + 1),  # Down
		Vector2(player_tile.x, player_tile.y - 1)   # Up
	]
	
	# Shuffle to add randomness
	adjacent_tiles.shuffle()
	
	# Find a valid adjacent tile that's not our current position
	var candidates = []
	for tile_coords in adjacent_tiles:
		var tile_center = Vector2(tile_coords.x * TILE_SIZE + TILE_SIZE/2, tile_coords.y * TILE_SIZE + TILE_SIZE/2)
		
		# Skip if this is our current tile
		if tile_coords == my_tile:
			continue
		
		# Check feet position (32 pixels below center) to prevent visual water walking
		var feet_pos = tile_center + FEET_OFFSET
		var feet_tile_x = int(floor(feet_pos.x / TILE_SIZE))
		var feet_tile_y = int(floor(feet_pos.y / TILE_SIZE))
		
		# Check if feet would be on water
		if world.has_method("get_terrain_type_from_noise"):
			var feet_terrain = world.get_terrain_type_from_noise(feet_tile_x, feet_tile_y)
			if feet_terrain == "water":
				continue

		if not is_walkable_for_enemy(tile_center):
			continue
		
		# Check if occupied by another enemy
		if is_tile_occupied_by_enemy(tile_center):
			continue
		if is_tile_reserved_by_enemy(tile_center):
			continue
		
		candidates.append(tile_center)

	# Prefer the nearest open adjacent tile
	if candidates.is_empty():
		return false
	
	candidates.sort_custom(func(a, b): return position.distance_to(a) < position.distance_to(b))
	for tile_center in candidates:
		# This tile is valid - move to it if we can path there
		if position.distance_to(tile_center) <= TILE_SIZE * 1.1:
			# Directly adjacent, just move there
			target_position = tile_center
			is_moving = true
			
			# Update facing direction toward player
			var dir_to_player = (targeted_enemy.position - position).normalized()
			if abs(dir_to_player.x) > abs(dir_to_player.y):
				current_direction = Vector2(sign(dir_to_player.x), 0)
			else:
				current_direction = Vector2(0, sign(dir_to_player.y))
			
			return true
		else:
			# Path toward the open adjacent tile
			if move_toward_target_with_path(tile_center):
				return true
	
	return false

func is_walkable_for_enemy(target_position: Vector2) -> bool:
	if world == null:
		return true
	var target_feet = target_position + FEET_OFFSET
	var from_feet = position + FEET_OFFSET
	var inside_building = get_current_building()
	if inside_building == null and pathfinding_target_building != null:
		if is_on_door_tile(pathfinding_target_building):
			inside_building = pathfinding_target_building
	if inside_building != null and is_on_door_tile(inside_building) and is_building_door_open(inside_building):
		# Only clear interior context if the target is outside the door tile
		if world != null and world.has_method("get_tile_coords"):
			var target_tile = world.get_tile_coords(target_feet)
			var entry = get_building_entry(inside_building)
			if not entry.is_empty():
				var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
				if target_tile == door_tile:
					inside_building = null
	# Prevent entering building interior from roof edge unless through the door
	if world.has_method("get_building_for_tile") and world.has_method("get_tile_coords"):
		var target_tile = world.get_tile_coords(target_feet)
		var entry = world.get_building_for_tile(target_tile)
		if not entry.is_empty():
			var target_building = entry.get("building", null)
			var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
			if inside_building == null or inside_building != target_building:
				if target_tile == door_tile and is_building_door_open(target_building):
					pass
				elif world.has_method("is_tile_in_building_interior") and world.is_tile_in_building_interior(target_tile, entry.get("rect", Rect2i())):
					return false
	if world.has_method("is_walkable_for_actor"):
		return world.is_walkable_for_actor(target_feet, from_feet, inside_building, true, true)
	if world.has_method("is_walkable"):
		return world.is_walkable(target_feet)
	return true

func get_current_building() -> Node:
	if world == null or not world.has_method("get_building_for_tile"):
		return null
	var feet = position + FEET_OFFSET
	var tile = Vector2i(int(floor(feet.x / TILE_SIZE)), int(floor(feet.y / TILE_SIZE)))
	var entry = world.get_building_for_tile(tile)
	if entry.is_empty():
		return null
	# Treat roof edge as outside
	if world.has_method("is_tile_on_building_roof_edge") and world.is_tile_on_building_roof_edge(tile, entry.get("rect", Rect2i())):
		return null
	return entry.get("building", null)

func can_detect_player() -> bool:
	if player == null or world == null:
		return false
	if not world.has_method("get_building_entry_for_node"):
		return true
	var player_building = get_player_building()
	if player_building == null:
		return true
	var enemy_building = get_current_building()
	if enemy_building != null and enemy_building == player_building:
		return true
	var entry = world.get_building_entry_for_node(player_building)
	if entry.is_empty():
		return true
	if world.has_method("is_building_door_open"):
		return world.is_building_door_open(entry)
	if player_building.has_method("is_door_open"):
		return player_building.is_door_open()
	if player_building.has_method("get"):
		return bool(player_building.get("door_open"))
	return true

func can_open_doors() -> bool:
	return is_humanoid

func get_player_building() -> Node:
	if world == null or player == null:
		return null
	if not world.has_method("get_building_for_tile") or not world.has_method("get_tile_coords"):
		return null
	var player_body_tile = world.get_tile_coords(player.position)
	var player_feet = player.position + FEET_OFFSET
	var player_feet_tile = world.get_tile_coords(player_feet)
	var entry = world.get_building_for_tile(player_feet_tile)
	if entry.is_empty():
		return null
	# If player is on the roof edge (top row), treat as outside
	if world.has_method("is_tile_on_building_roof_edge") and world.is_tile_on_building_roof_edge(player_body_tile, entry.get("rect", Rect2i())):
		return null
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	if player_feet_tile == door_tile:
		return entry.get("building", null)
	if world.has_method("is_tile_in_building_interior") and world.is_tile_in_building_interior(player_feet_tile, entry.get("rect", Rect2i())):
		return entry.get("building", null)
	return null

func get_building_entry(building: Node) -> Dictionary:
	if world == null or building == null:
		return {}
	if world.has_method("get_building_entry_for_node"):
		return world.get_building_entry_for_node(building)
	return {}

func get_pathfinding_building() -> Node:
	if pathfinding_target_building == null:
		return null
	if get_current_building() == pathfinding_target_building:
		return pathfinding_target_building
	if is_on_door_tile(pathfinding_target_building):
		return pathfinding_target_building
	return null

func is_building_door_open(building: Node) -> bool:
	if building == null:
		return false
	if world != null and world.has_method("get_building_entry_for_node") and world.has_method("is_building_door_open"):
		var entry = world.get_building_entry_for_node(building)
		if not entry.is_empty():
			return world.is_building_door_open(entry)
	if building.has_method("is_door_open"):
		return building.is_door_open()
	if building.has_method("get"):
		return bool(building.get("door_open"))
	return false

func update_last_known_player_building():
	if not can_detect_player():
		return
	var building = get_player_building()
	if building == null:
		last_known_player_building = null
		last_known_player_door_tile = Vector2i.ZERO
		return
	last_known_player_building = building
	var entry = get_building_entry(building)
	if not entry.is_empty():
		last_known_player_door_tile = entry.get("door", Vector2i.ZERO)

func get_door_body_tile(building: Node) -> Vector2i:
	var entry = get_building_entry(building)
	if entry.is_empty():
		return Vector2i.ZERO
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	# Body tile sits one tile above the feet tile
	return Vector2i(door_tile.x, door_tile.y - 1)

func get_door_center(building: Node) -> Vector2:
	var door_body_tile = get_door_body_tile(building)
	if door_body_tile == Vector2i.ZERO:
		return Vector2.ZERO
	return Vector2(door_body_tile.x * TILE_SIZE + TILE_SIZE / 2, door_body_tile.y * TILE_SIZE + TILE_SIZE / 2)

func get_door_approach_center(building: Node) -> Vector2:
	var entry = get_building_entry(building)
	if entry.is_empty():
		return Vector2.ZERO
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	# Outside approach for body tiles is the door tile itself
	var approach_tile = Vector2i(door_tile.x, door_tile.y)
	return Vector2(approach_tile.x * TILE_SIZE + TILE_SIZE / 2, approach_tile.y * TILE_SIZE + TILE_SIZE / 2)

func get_door_entry_center(building: Node) -> Vector2:
	var door_body_tile = get_door_body_tile(building)
	if door_body_tile == Vector2i.ZERO:
		return Vector2.ZERO
	var entry_tile = Vector2i(door_body_tile.x, door_body_tile.y - 1)
	return Vector2(entry_tile.x * TILE_SIZE + TILE_SIZE / 2, entry_tile.y * TILE_SIZE + TILE_SIZE / 2)

func get_door_exit_center(building: Node) -> Vector2:
	var entry = get_building_entry(building)
	if entry.is_empty():
		return Vector2.ZERO
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	var exit_tile = Vector2i(door_tile.x, door_tile.y)
	return Vector2(exit_tile.x * TILE_SIZE + TILE_SIZE / 2, exit_tile.y * TILE_SIZE + TILE_SIZE / 2)

func get_exit_queue_center(building: Node, max_depth: int = 8) -> Vector2:
	var entry = get_building_entry(building)
	if entry.is_empty():
		return Vector2.ZERO
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	# Queue forms outside the door along +Y (below the door)
	var exit_center = Vector2(door_tile.x * TILE_SIZE + TILE_SIZE / 2, door_tile.y * TILE_SIZE + TILE_SIZE / 2)
	if is_walkable_outside(exit_center) and not is_tile_occupied_by_enemy(exit_center) and not is_tile_reserved_by_enemy(exit_center):
		return exit_center
	for i in range(1, max_depth + 1):
		var queue_tile = Vector2i(door_tile.x, door_tile.y + i)
		var queue_center = Vector2(queue_tile.x * TILE_SIZE + TILE_SIZE / 2, queue_tile.y * TILE_SIZE + TILE_SIZE / 2)
		if not is_walkable_outside(queue_center):
			continue
		if is_tile_occupied_by_enemy(queue_center):
			continue
		if is_tile_reserved_by_enemy(queue_center):
			continue
		return queue_center
	return Vector2.ZERO

func is_near_door(building: Node, max_distance: float = TILE_SIZE * 1.1) -> bool:
	var door_center = get_door_center(building)
	if door_center == Vector2.ZERO:
		return false
	return position.distance_to(door_center) <= max_distance

func is_on_door_tile(building: Node) -> bool:
	if world == null or building == null:
		return false
	var entry = get_building_entry(building)
	if entry.is_empty():
		return false
	if not world.has_method("get_tile_coords"):
		return false
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	var feet = position + FEET_OFFSET
	var my_tile = world.get_tile_coords(feet)
	return my_tile == door_tile

func is_walkable_outside(tile_center: Vector2) -> bool:
	if world == null:
		return true
	var target_feet = tile_center + FEET_OFFSET
	var from_feet = position + FEET_OFFSET
	if world.has_method("is_walkable_for_actor"):
		return world.is_walkable_for_actor(target_feet, from_feet, null, false, true)
	if world.has_method("is_walkable"):
		return world.is_walkable(target_feet)
	return true

func get_door_queue_center(building: Node, max_depth: int = 8) -> Vector2:
	var entry = get_building_entry(building)
	if entry.is_empty():
		return Vector2.ZERO
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	# Queue forms outside the door along +Y (below the door)
	var door_center = get_door_center(building)
	if is_walkable_outside(door_center) and not is_tile_occupied_by_enemy(door_center) and not is_tile_reserved_by_enemy(door_center):
		return door_center
	for i in range(0, max_depth + 1):
		var queue_tile = Vector2i(door_tile.x, door_tile.y + i)
		var queue_center = Vector2(queue_tile.x * TILE_SIZE + TILE_SIZE / 2, queue_tile.y * TILE_SIZE + TILE_SIZE / 2)
		if not is_walkable_outside(queue_center):
			continue
		if is_tile_occupied_by_enemy(queue_center):
			continue
		if is_tile_reserved_by_enemy(queue_center):
			continue
		return queue_center
	return Vector2.ZERO

func get_door_wait_center(building: Node, max_offset: int = 4) -> Vector2:
	var entry = get_building_entry(building)
	if entry.is_empty():
		return Vector2.ZERO
	var door_tile: Vector2i = entry.get("door", Vector2i.ZERO)
	# Search nearby outside tiles to wait without stacking
	for dy in range(0, max_offset + 1):
		for dx in range(-max_offset, max_offset + 1):
			var wait_tile = Vector2i(door_tile.x + dx, door_tile.y + dy)
			var wait_center = Vector2(wait_tile.x * TILE_SIZE + TILE_SIZE / 2, wait_tile.y * TILE_SIZE + TILE_SIZE / 2)
			if not is_walkable_outside(wait_center):
				continue
			if is_tile_occupied_by_enemy(wait_center):
				continue
			if is_tile_reserved_by_enemy(wait_center):
				continue
			return wait_center
	return Vector2.ZERO

func try_open_building_door(building: Node) -> bool:
	if not can_open_doors():
		return false
	if building == null:
		return false
	if is_building_door_open(building):
		return false
	var door_center = get_door_center(building)
	if door_center == Vector2.ZERO:
		return false
	if position.distance_to(door_center) > TILE_SIZE * 1.1:
		return false
	if building.has_method("open_door"):
		building.open_door()
		return true
	if building.has_method("set"):
		building.set("door_open", true)
		if building.has_method("update_layers"):
			building.update_layers()
		return true
	return false

func move_out_of_town():
	if world == null:
		return
	if not world.has_method("get_town_radius_world"):
		return
	var town_center = Vector2.ZERO
	if world.has_method("get_town_centers"):
		var centers = world.get_town_centers()
		if centers.is_empty():
			return
		var nearest = centers[0]
		var best_dist = position.distance_to(nearest)
		for center in centers:
			var dist = position.distance_to(center)
			if dist < best_dist:
				best_dist = dist
				nearest = center
		town_center = nearest
	elif world.has_method("get_town_center"):
		town_center = world.get_town_center()
	else:
		return
	var radius = world.get_town_radius_world()
	var base_dir = (position - town_center).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var directions = [
		base_dir,
		base_dir.rotated(deg_to_rad(45)),
		base_dir.rotated(deg_to_rad(-45)),
		base_dir.rotated(deg_to_rad(90)),
		base_dir.rotated(deg_to_rad(-90))
	]
	for dir in directions:
		var target = town_center + dir * (radius + TILE_SIZE * 2)
		var snapped = Vector2(
			floor(target.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2,
			floor(target.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2
		)
		if world.has_method("is_walkable") and not world.is_walkable(snapped):
			continue
		target_position = snapped
		is_moving = true
		current_direction = Vector2(sign(dir.x), 0) if abs(dir.x) > abs(dir.y) else Vector2(0, sign(dir.y))
		return


func calculate_direction(dx: int, dy: int) -> Vector2:
	# Cardinal-only movement
	if dx != 0:
		return Vector2(dx, 0)
	if dy != 0:
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

func play_idle_animation():
	var dir_name = get_direction_name(current_direction)
	if animated_sprite != null and animated_sprite.sprite_frames != null:
		var anim_name = "idle_" + dir_name
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)

func try_step_toward(goal_position: Vector2, max_extra_distance: float = TILE_SIZE) -> bool:
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var best_dir = Vector2.ZERO
	var best_dist = INF
	var current_dist = position.distance_to(goal_position)
	for dir in dirs:
		var next_tile = position + dir * TILE_SIZE
		if not is_walkable_for_enemy(next_tile):
			continue
		if is_tile_occupied_by_enemy(next_tile) or is_tile_reserved_by_enemy(next_tile):
			continue
		if player != null and next_tile.distance_to(player.position) < TILE_SIZE * 0.6:
			continue
		var dist = next_tile.distance_to(goal_position)
		if dist <= current_dist + max_extra_distance and dist < best_dist:
			best_dist = dist
			best_dir = dir
	if best_dir == Vector2.ZERO:
		return false
	var target = position + best_dir * TILE_SIZE
	current_direction = best_dir
	last_movement_direction = best_dir
	target_position = target
	is_moving = true
	return true

func is_tile_occupied_by_enemy(tile_pos: Vector2) -> bool:
	"""Check if a tile is occupied by another enemy (not this enemy)"""
	var parent = get_parent()
	if parent == null:
		return false
	
	# Get all children of the parent that are enemies
	for child in parent.get_children():
		if child is CharacterBody2D and child != self and child.is_in_group("enemies"):
			# This is another enemy - check if it's on this tile
			if child.position.distance_to(tile_pos) < TILE_SIZE:
				return true
	
	return false

func is_tile_reserved_by_enemy(tile_pos: Vector2) -> bool:
	"""Check if another enemy is already moving to this tile."""
	var parent = get_parent()
	if parent == null:
		return false
	for child in parent.get_children():
		if child is CharacterBody2D and child != self and child.is_in_group("enemies"):
			if not child.has_method("get"):
				continue
			var other_moving = bool(child.get("is_moving"))
			if not other_moving:
				continue
			var other_target = child.get("target_position")
			if typeof(other_target) == TYPE_VECTOR2:
				if other_target.distance_to(tile_pos) < 1.0:
					return true
	return false

func find_path(start: Vector2, goal: Vector2) -> Array:
	"""Call the world's shared pathfinding function.
	This ensures enemies use identical pathfinding logic to the player."""
	if world != null and world.has_method("find_path"):
		return world.find_path(start, goal, self)
	return []

func move_toward_target_with_path(goal_position: Vector2) -> bool:
	if world == null:
		return false
	var my_tile = Vector2(floor(position.x / TILE_SIZE), floor(position.y / TILE_SIZE))
	var start_center = Vector2(my_tile.x * TILE_SIZE + TILE_SIZE/2, my_tile.y * TILE_SIZE + TILE_SIZE/2)
	var goal_tile = Vector2(floor(goal_position.x / TILE_SIZE), floor(goal_position.y / TILE_SIZE))
	var goal_center = Vector2(goal_tile.x * TILE_SIZE + TILE_SIZE/2, goal_tile.y * TILE_SIZE + TILE_SIZE/2)
	if player != null:
		var player_tile = Vector2(floor(player.position.x / TILE_SIZE), floor(player.position.y / TILE_SIZE))
		if goal_tile == player_tile:
			# Don't path directly onto the player's tile
			return false
	var path = find_path(start_center, goal_center)
	if path.size() <= 1:
		return false
	# Safeguard: reject paths that include unwalkable building walls
	for i in range(1, path.size()):
		if not is_walkable_for_enemy(path[i]):
			return false
	var next_step = path[1]
	if not is_walkable_for_enemy(next_step):
		return false
	if player != null and next_step.distance_to(player.position) < TILE_SIZE * 0.6:
		return false
	if is_tile_occupied_by_enemy(next_step) or is_tile_reserved_by_enemy(next_step):
		return false
	var dx = sign(next_step.x - position.x)
	var dy = sign(next_step.y - position.y)
	current_direction = calculate_direction(int(dx), int(dy))
	last_movement_direction = Vector2(dx, dy)
	target_position = next_step
	is_moving = true
	return true

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
	
	# Roll to hit - base 30% hit chance modified by dexterity
	var hit_chance = 30 + (dexterity * 1)  # Each point of dexterity adds 1% hit chance
	var hit_roll = randi_range(1, 100)
	
	if hit_roll > hit_chance:
		# Miss!
		print("[ENEMY ATTACK] Missed! (rolled ", hit_roll, " vs ", hit_chance, "% hit chance)")
		create_miss_effect(targeted_enemy.position)
		return
	
	# Hit! Calculate damage based on strength with variance
	# Base damage = strength * 2, with +/- 20% variance
	var base_damage = strength * 2
	var variance = randi_range(-20, 20) / 100.0  # -20% to +20%
	var damage = max(1, int(base_damage * (1.0 + variance)))  # Minimum 1 damage
	var defense = 0
	if targeted_enemy and targeted_enemy.has_method("get_total_defense"):
		defense = int(targeted_enemy.get_total_defense())
	if defense > 0:
		damage = max(1, damage - defense)
	
	var target_health = targeted_enemy.get_meta("current_health")
	target_health -= damage
	targeted_enemy.set_meta("current_health", target_health)
	
	print("[ENEMY ATTACK] Hit! Dealt ", damage, " damage to player. HP: ", target_health, "/", targeted_enemy.get_meta("max_health"))
	
	# Create blood effect with damage number
	create_blood_effect(targeted_enemy.position, damage)
	
	# Trigger health bar redraw
	if targeted_enemy.has_node("HealthBar"):
		var health_bar = targeted_enemy.get_node("HealthBar")
		health_bar.queue_redraw()
	
	# Check if target died
	if target_health <= 0:
		targeted_enemy.die()
		targeted_enemy = null

func die():
	# Create a dead body visual at the enemy's position
	var dead_body = Area2D.new()
	dead_body.position = position + Vector2(0, TILE_SIZE/2)  # Position at the feet tile
	dead_body.z_index = 0  # On the ground, above terrain
	
	# Load and attach the dead body script
	var dead_body_script = load("res://scripts/dead_body.gd")
	dead_body.set_script(dead_body_script)
	if enemy_name == "Orc":
		dead_body.set_meta("is_orc_body", true)
	elif enemy_name == "Troll":
		dead_body.set_meta("is_troll_body", true)
	
	# Add the dead body to the world node so it renders with terrain
	var parent = get_parent()
	if parent:
		var world = parent.get_node_or_null("World")
		if world:
			world.add_child(dead_body)
		else:
			# Fallback to parent if world not found
			parent.add_child(dead_body)
	else:
		# Avoid leaking if no parent is available
		dead_body.queue_free()
	
	# Remove the enemy from the scene
	queue_free()

func create_miss_effect(target_pos: Vector2):
	"""Create a smoke puff effect for a missed attack"""
	var CombatEffects = load("res://scripts/combat_effects.gd")
	var parent = get_parent()
	if parent:
		# Offset down by one tile to appear over the collision tile
		var effect_pos = target_pos + Vector2(0, 32)
		CombatEffects.create_miss_effect(parent, effect_pos)

func create_blood_effect(target_pos: Vector2, damage: int = 0):
	"""Create a blood spurt effect for a successful hit"""
	var CombatEffects = load("res://scripts/combat_effects.gd")
	var parent = get_parent()
	if parent:
		# Offset down by one tile to appear over the collision tile
		var effect_pos = target_pos + Vector2(0, 32)
		CombatEffects.create_blood_effect(parent, effect_pos, damage)
