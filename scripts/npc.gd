extends CharacterBody2D

const TILE_SIZE = 32
const FEET_OFFSET = Vector2(0, TILE_SIZE / 2)

@export var town_center: Vector2 = Vector2.ZERO
@export var town_radius: float = 320.0
@export var move_speed: float = 70.0
@export var min_idle_time := 0.8
@export var max_idle_time := 2.5
@export var move_chance := 0.5
@export var npc_name := "Gregor"
@export var persona := "A quiet local who knows the town well."
@export var greeting := "Hello there."
@export var memory_summary := ""
@export var town_name := ""

var target_position: Vector2 = Vector2.ZERO
var world: Node = null
var is_talking := false
var is_moving := false
var current_direction = Vector2.DOWN
var idle_timer := 0.0
var speech_node: Node2D = null
var health_bar = null
var thinking_node: Node2D = null

class SpeechText extends Node2D:
	var text := ""
	var lifetime := 0.0
	var max_lifetime := 2.5
	var font_size := 16
	var outline_size := 2
	var fade_out_time := 0.35
	var max_width := 260.0

	func _process(delta):
		lifetime += delta
		if lifetime >= max_lifetime:
			queue_free()
			return
		queue_redraw()

	func _draw():
		if text == "":
			return
		var font = ThemeDB.fallback_font
		var viewport = get_viewport()
		if viewport:
			max_width = min(max_width, viewport.get_visible_rect().size.x * 0.45)
		var alpha = 1.0
		if lifetime > max_lifetime - fade_out_time:
			alpha = clamp((max_lifetime - lifetime) / fade_out_time, 0.0, 1.0)
		var lines = _wrap_lines(text, font, max_width, font_size)
		var line_height = font.get_height(font_size) + 2
		var total_height = line_height * lines.size()
		var y = -total_height
		for line in lines:
			var line_size = font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var draw_pos = Vector2(-line_size.x * 0.5, y)
			for offset in [Vector2(-outline_size, -outline_size), Vector2(outline_size, -outline_size), Vector2(-outline_size, outline_size), Vector2(outline_size, outline_size)]:
				draw_string(font, draw_pos + offset, line, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, alpha))
			draw_string(font, draw_pos, line, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, alpha))
			y += line_height

	func _wrap_lines(raw_text: String, font: Font, width: float, size: int) -> Array:
		var words = raw_text.split(" ", false)
		var lines: Array = []
		var current = ""
		for word in words:
			var candidate = word if current == "" else current + " " + word
			var candidate_width = font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if candidate_width <= width or current == "":
				current = candidate
				continue
			lines.append(current)
			current = word
		if current != "":
			lines.append(current)
		return lines

class ThinkingDots extends Node2D:
	var lifetime := 0.0
	var dot_spacing := 6.0
	var dot_radius := 2.0
	var bob_amplitude := 2.0
	var bob_speed := 6.0
	var color := Color(1, 1, 1, 1)

	func _process(delta):
		lifetime += delta
		queue_redraw()

	func _draw():
		var base_y = sin(lifetime * bob_speed) * bob_amplitude
		for i in range(3):
			var x = (i - 1) * dot_spacing
			var y = base_y + sin(lifetime * bob_speed + i * 0.6) * 0.5
			draw_circle(Vector2(x, y), dot_radius, color)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	world = get_world_node()
	add_to_group("npcs")
	global_position = snap_to_tile_center(global_position)
	target_position = global_position
	create_player_animations()
	animated_sprite.offset = Vector2(0, 8)
	set_meta("max_health", 100)
	set_meta("current_health", 100)
	var health_bar_scene = preload("res://scenes/health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	add_child(health_bar)
	update_animation(current_direction, false)
	queue_redraw()

func _physics_process(_delta):
	if is_talking:
		velocity = Vector2.ZERO
		_snap_to_tile_if_needed()
		return
	idle_timer = max(0.0, idle_timer - _delta)
	if not is_moving:
		_snap_to_tile_if_needed()
		if idle_timer <= 0.0:
			pick_next_tile()
		return
	update_animation(current_direction, true)
	var to_target = target_position - global_position
	if to_target.length() <= move_speed * _delta:
		global_position = target_position
		is_moving = false
		idle_timer = randf_range(min_idle_time, max_idle_time)
		update_animation(current_direction, false)
		return
	global_position += to_target.normalized() * move_speed * _delta

func pick_next_tile():
	if randf() > move_chance:
		idle_timer = randf_range(min_idle_time, max_idle_time)
		is_moving = false
		return
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	# Shuffle directions for more natural wandering
	for i in range(directions.size() - 1, 0, -1):
		var j = randi_range(0, i)
		var temp = directions[i]
		directions[i] = directions[j]
		directions[j] = temp
	for dir in directions:
		var candidate = snap_to_tile_center(global_position + dir * TILE_SIZE)
		if town_center != Vector2.ZERO and candidate.distance_to(town_center) > town_radius:
			continue
		if not is_walkable_for_npc(candidate):
			continue
		if is_tile_occupied_by_actor(candidate) or is_tile_reserved_by_actor(candidate):
			continue
		current_direction = dir
		target_position = candidate
		is_moving = true
		return
	# Fallback: stay in place
	target_position = snap_to_tile_center(global_position)
	is_moving = false
	update_animation(current_direction, false)

func snap_to_tile_center(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2,
		floor(pos.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2
	)

func _snap_to_tile_if_needed():
	var snapped = snap_to_tile_center(global_position)
	if global_position.distance_to(snapped) > 0.1:
		global_position = snapped

func is_walkable_for_npc(target_position: Vector2) -> bool:
	if world == null:
		return true
	var target_feet = target_position + FEET_OFFSET
	var from_feet = global_position + FEET_OFFSET
	if world.has_method("is_walkable_for_actor"):
		return world.is_walkable_for_actor(target_feet, from_feet, null, true, true)
	if world.has_method("is_walkable"):
		return world.is_walkable(target_feet)
	return true

func is_tile_occupied_by_actor(tile_pos: Vector2) -> bool:
	var parent = get_parent()
	if parent == null:
		return false
	for child in parent.get_children():
		if child == self:
			continue
		if not (child is CharacterBody2D):
			continue
		if not (child.is_in_group("enemies") or child.is_in_group("npcs") or child.name == "Player"):
			continue
		if child.position.distance_to(tile_pos) < TILE_SIZE:
			return true
	return false

func is_tile_reserved_by_actor(tile_pos: Vector2) -> bool:
	var parent = get_parent()
	if parent == null:
		return false
	for child in parent.get_children():
		if child == self:
			continue
		if not (child is CharacterBody2D):
			continue
		if not (child.is_in_group("enemies") or child.is_in_group("npcs") or child.name == "Player"):
			continue
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

func get_world_node() -> Node:
	var parent = get_parent()
	if parent:
		if parent.name == "World":
			return parent
		var world_node = parent.get_node_or_null("World")
		if world_node:
			return world_node
	return get_tree().get_root().find_child("World", true, false)

func set_talking(active: bool):
	is_talking = active
	if active:
		velocity = Vector2.ZERO
		_face_player()
		_snap_to_tile_if_needed()

func show_speech(text: String, duration: float = 2.5):
	var trimmed = text.strip_edges()
	if trimmed == "":
		return
	_face_player()
	if speech_node and is_instance_valid(speech_node):
		speech_node.queue_free()
		speech_node = null
	var bubble = SpeechText.new()
	bubble.text = trimmed
	bubble.max_lifetime = duration
	bubble.z_index = 4096
	bubble.z_as_relative = false
	var world_parent = get_parent() if get_parent() else self
	world_parent.add_child(bubble)
	bubble.global_position = global_position + Vector2(0, -56)
	speech_node = bubble

func set_thinking(active: bool):
	if active:
		if thinking_node and is_instance_valid(thinking_node):
			return
		var dots = ThinkingDots.new()
		dots.z_index = 4096
		dots.z_as_relative = false
		var world_parent = get_parent() if get_parent() else self
		world_parent.add_child(dots)
		dots.global_position = global_position + Vector2(0, -68)
		thinking_node = dots
		return
	if thinking_node and is_instance_valid(thinking_node):
		thinking_node.queue_free()
		thinking_node = null

func get_chat_profile() -> Dictionary:
	return {
		"name": npc_name,
		"persona": persona,
		"greeting": greeting,
		"memory": memory_summary,
		"town_name": town_name
	}

func _face_player():
	var player = get_tree().get_root().find_child("Player", true, false)
	if player == null:
		return
	var to_player = (player.global_position - global_position)
	if abs(to_player.x) > abs(to_player.y):
		current_direction = Vector2.RIGHT if to_player.x >= 0 else Vector2.LEFT
	else:
		current_direction = Vector2.DOWN if to_player.y >= 0 else Vector2.UP
	update_animation(current_direction, false)

func update_animation(direction: Vector2, walking: bool):
	var anim_name = "walk_" if walking else "idle_"
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

func create_player_animations():
	var sprite_frames = SpriteFrames.new()
	create_direction_animations(sprite_frames, "down", Vector2.DOWN)
	create_direction_animations(sprite_frames, "up", Vector2.UP)
	create_direction_animations(sprite_frames, "left", Vector2.LEFT)
	create_direction_animations(sprite_frames, "right", Vector2.RIGHT)
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle_down")

func create_direction_animations(sprite_frames: SpriteFrames, dir_name: String, dir_vector: Vector2):
	sprite_frames.add_animation("idle_" + dir_name)
	sprite_frames.set_animation_speed("idle_" + dir_name, 5.0)
	var idle_frame = create_character_frame(dir_vector, 1)
	sprite_frames.add_frame("idle_" + dir_name, idle_frame)
	sprite_frames.add_animation("walk_" + dir_name)
	sprite_frames.set_animation_speed("walk_" + dir_name, 12.0)
	sprite_frames.set_animation_loop("walk_" + dir_name, true)
	for frame_num in range(4):
		var walk_frame = create_character_frame(dir_vector, frame_num)
		sprite_frames.add_frame("walk_" + dir_name, walk_frame)

func create_character_frame(direction: Vector2, frame: int) -> ImageTexture:
	var img = Image.create(32, 64, false, Image.FORMAT_RGBA8)
	var skin = Color(0.95, 0.8, 0.6)
	var hair = Color(0.45, 0.45, 0.5)
	var leather = Color(0.2, 0.45, 0.35)
	var leather_dark = Color(0.15, 0.32, 0.25)
	var pants = Color(0.25, 0.2, 0.45)
	var beard = Color(0.65, 0.65, 0.7)
	var outline = Color(0.1, 0.1, 0.1)
	var metal = Color(0.7, 0.7, 0.75)
	var handle = Color(0.4, 0.3, 0.2)
	if direction == Vector2.UP:
		draw_character_back(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame)
	elif direction == Vector2.DOWN:
		draw_character_front(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame, beard)
	elif direction == Vector2.LEFT:
		draw_character_side(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame, true, beard)
	elif direction == Vector2.RIGHT:
		draw_character_side(img, skin, hair, leather, leather_dark, pants, outline, metal, handle, frame, false, beard)
	return ImageTexture.create_from_image(img)

func draw_character_front(img: Image, skin: Color, hair: Color, leather: Color, leather_dark: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int, beard: Color):
	for y in range(28, 36):
		for x in range(7, 25):
			img.set_pixel(x, y, leather)
	for y in range(28, 36):
		img.set_pixel(7, y, outline)
		img.set_pixel(24, y, outline)
	for x in range(7, 25):
		img.set_pixel(x, 28, outline)
		img.set_pixel(x, 35, outline)
	for y in range(12, 24):
		for x in range(9, 23):
			img.set_pixel(x, y, skin)
	for y in range(12, 24):
		img.set_pixel(8, y, outline)
		img.set_pixel(23, y, outline)
	for x in range(8, 24):
		img.set_pixel(x, 11, outline)
		img.set_pixel(x, 24, outline)
	for y in range(16, 19):
		img.set_pixel(12, y, outline)
		img.set_pixel(19, y, outline)
	# Long grey beard under the chin
	for y in range(24, 32):
		for x in range(10, 22):
			img.set_pixel(x, y, beard)
	for y in range(24, 32):
		img.set_pixel(9, y, outline)
		img.set_pixel(22, y, outline)
	for y in range(24, 28):
		for x in range(11, 21):
			img.set_pixel(x, y, skin)
		img.set_pixel(11, y, outline)
		img.set_pixel(20, y, outline)
	for y in range(28, 41):
		for x in range(7, 25):
			img.set_pixel(x, y, leather)
		img.set_pixel(7, y, outline)
		img.set_pixel(24, y, outline)
	for y in range(28, 41):
		for x in range(14, 18):
			img.set_pixel(x, y, leather_dark)
	for x in range(10, 22):
		img.set_pixel(x, 32, leather_dark)
		img.set_pixel(x, 36, leather_dark)
	var left_arm_offset = 0
	var right_arm_offset = 0
	if walk_frame == 1:
		left_arm_offset = -3
		right_arm_offset = 3
	elif walk_frame == 3:
		left_arm_offset = 3
		right_arm_offset = -3
	for y in range(max(30, 30 + left_arm_offset), min(40, 40 + left_arm_offset)):
		if y >= 0 and y < 64:
			for x in range(4, 8):
				img.set_pixel(x, y, skin)
			img.set_pixel(4, y, outline)
	for y in range(max(30, 30 + right_arm_offset), min(40, 40 + right_arm_offset)):
		if y >= 0 and y < 64:
			for x in range(24, 28):
				img.set_pixel(x, y, skin)
			img.set_pixel(27, y, outline)
	for y in range(41, 51):
		for x in range(9, 23):
			img.set_pixel(x, y, pants)
		img.set_pixel(9, y, outline)
		img.set_pixel(22, y, outline)
	var left_leg_offset = 0
	var right_leg_offset = 0
	if walk_frame == 1:
		left_leg_offset = 3
		right_leg_offset = -3
	elif walk_frame == 3:
		left_leg_offset = -3
		right_leg_offset = 3
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
	for y in range(max(51, 51 + left_leg_offset), min(63, 63 + left_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(8, y, outline)
	for y in range(max(48, 48 + right_leg_offset), min(63, 63 + right_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(23, y, outline)

func draw_character_back(img: Image, skin: Color, hair: Color, leather: Color, leather_dark: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int):
	for y in range(28, 36):
		for x in range(7, 25):
			img.set_pixel(x, y, leather)
	for y in range(28, 36):
		img.set_pixel(7, y, outline)
		img.set_pixel(24, y, outline)
	for x in range(7, 25):
		img.set_pixel(x, 28, outline)
		img.set_pixel(x, 35, outline)
	for y in range(12, 24):
		for x in range(9, 23):
			img.set_pixel(x, y, skin)
	for y in range(12, 24):
		img.set_pixel(8, y, outline)
		img.set_pixel(23, y, outline)
	for x in range(8, 24):
		img.set_pixel(x, 11, outline)
		img.set_pixel(x, 24, outline)
	for y in range(24, 28):
		for x in range(11, 21):
			img.set_pixel(x, y, skin)
		img.set_pixel(10, y, outline)
		img.set_pixel(21, y, outline)
	for y in range(28, 40):
		for x in range(7, 25):
			img.set_pixel(x, y, leather)
		img.set_pixel(6, y, outline)
		img.set_pixel(25, y, outline)
	for y in range(28, 40):
		img.set_pixel(14, y, leather_dark)
		img.set_pixel(17, y, leather_dark)
	for x in range(7, 25):
		img.set_pixel(x, 32, leather_dark)
		img.set_pixel(x, 36, leather_dark)
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
	for y in range(40, 48):
		for x in range(9, 23):
			img.set_pixel(x, y, pants)
		img.set_pixel(8, y, outline)
		img.set_pixel(23, y, outline)
	var left_leg_offset = 0
	var right_leg_offset = 0
	if walk_frame == 1:
		left_leg_offset = -4
		right_leg_offset = 4
	elif walk_frame == 3:
		left_leg_offset = 4
		right_leg_offset = -4
	for x in range(9, 16):
		for y in range(48, 56):
			var pixel_y = y + left_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, pants)
		var foot_y = 56 + left_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for foot_x in range(9, 16):
				for fy in range(foot_y, min(foot_y + 4, 64)):
					img.set_pixel(foot_x, fy, outline)
	for x in range(16, 23):
		for y in range(48, 56):
			var pixel_y = y + right_leg_offset
			if pixel_y >= 0 and pixel_y < 64:
				img.set_pixel(x, pixel_y, pants)
		var foot_y = 56 + right_leg_offset
		if foot_y >= 0 and foot_y < 64:
			for foot_x in range(16, 23):
				for fy in range(foot_y, min(foot_y + 4, 64)):
					img.set_pixel(foot_x, fy, outline)
	for y in range(max(48, 48 + left_leg_offset), min(60, 60 + left_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(8, y, outline)
	for y in range(max(48, 48 + right_leg_offset), min(60, 60 + right_leg_offset)):
		if y >= 0 and y < 64:
			img.set_pixel(22, y, outline)

func draw_character_side(img: Image, skin: Color, hair: Color, leather: Color, leather_dark: Color, pants: Color, outline: Color, metal: Color, handle: Color, walk_frame: int, flip_x: bool, beard: Color):
	var base_x = 16
	var dir = 1 if not flip_x else -1
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
	for y in range(12, 24):
		for dx in range(14):
			var x = base_x + (dx - 6) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, skin)
	# Long grey beard profile
	for y in range(24, 32):
		for dx in range(8):
			var x = base_x + (dx - 2) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, beard)
	for y in range(12, 24):
		var x = base_x + 8 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, outline)
		x = base_x - 6 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, outline)
	for dx in range(16):
		var x = base_x + (dx - 7) * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, 11, outline)
			img.set_pixel(x, 24, outline)
	var eye_x = base_x + 6 * dir
	if eye_x >= 0 and eye_x < 32:
		for y in range(18, 22):
			img.set_pixel(eye_x, y, outline)
	var nose_x = base_x + 6 * dir
	if nose_x >= 0 and nose_x < 32:
		img.set_pixel(nose_x, 21, Color(0.85, 0.7, 0.5))
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
	for y in range(32, 48):
		for dx in range(18):
			var x = base_x + (dx - 6) * dir
			if x >= 0 and x < 32:
				img.set_pixel(x, y, leather)
		var outline_x1 = base_x + 12 * dir
		var outline_x2 = base_x - 6 * dir
		if outline_x1 >= 0 and outline_x1 < 32:
			img.set_pixel(outline_x1, y, outline)
		if outline_x2 >= 0 and outline_x2 < 32:
			img.set_pixel(outline_x2, y, outline)
	for y in range(32, 48):
		var x = base_x + 4 * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, y, leather_dark)
	for dx in range(14):
		var x = base_x + (dx - 4) * dir
		if x >= 0 and x < 32:
			img.set_pixel(x, 34, leather_dark)
			img.set_pixel(x, 38, leather_dark)
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
	var front_leg_offset = 0
	var back_leg_offset = 0
	if walk_frame == 1:
		front_leg_offset = 8
		back_leg_offset = -8
	elif walk_frame == 3:
		front_leg_offset = -8
		back_leg_offset = 8
	for y in range(60, 64):
		var pixel_y = y + back_leg_offset
		if pixel_y >= 0 and pixel_y < 64:
			for dx in range(6):
				var x = base_x + (dx - 5) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, pixel_y, pants)
			var outline_x = base_x - 5 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, pixel_y, outline)
	for y in range(60, 64):
		var pixel_y = y + front_leg_offset
		if pixel_y >= 0 and pixel_y < 64:
			for dx in range(7):
				var x = base_x + (dx - 1) * dir
				if x >= 0 and x < 32:
					img.set_pixel(x, pixel_y, pants)
			var outline_x = base_x + 6 * dir
			if outline_x >= 0 and outline_x < 32:
				img.set_pixel(outline_x, pixel_y, outline)
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
