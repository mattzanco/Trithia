extends CharacterBody2D

const TILE_SIZE = 32

@export var town_center: Vector2 = Vector2.ZERO
@export var town_radius: float = 320.0
@export var move_speed: float = 60.0
@export var skin_color := Color(0.85, 0.7, 0.55)
@export var outfit_color := Color(0.2, 0.35, 0.5)
@export var outline_color := Color(0.1, 0.1, 0.1)

var target_position: Vector2 = Vector2.ZERO
var world: Node = null

func _ready():
	world = get_world_node()
	pick_new_target()
	queue_redraw()

func _physics_process(_delta):
	if target_position == Vector2.ZERO:
		pick_new_target()
		return
	var to_target = target_position - global_position
	if to_target.length() < 4.0:
		pick_new_target()
		velocity = Vector2.ZERO
		return
	velocity = to_target.normalized() * move_speed
	move_and_slide()

func pick_new_target():
	for i in range(20):
		var angle = randf() * TAU
		var dist = randf() * (town_radius - TILE_SIZE * 2)
		var pos = town_center + Vector2(cos(angle), sin(angle)) * dist
		var snapped = Vector2(
			floor(pos.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2,
			floor(pos.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2
		)
		if world and world.has_method("is_walkable") and not world.is_walkable(snapped):
			continue
		target_position = snapped
		return
	# Fallback to center if no target found
	target_position = town_center

func get_world_node() -> Node:
	var parent = get_parent()
	if parent:
		if parent.name == "World":
			return parent
		var world_node = parent.get_node_or_null("World")
		if world_node:
			return world_node
	return get_tree().get_root().find_child("World", true, false)

func _draw():
	# Simple NPC body (head + torso)
	var head_rect = Rect2(Vector2(-6, -18), Vector2(12, 12))
	var body_rect = Rect2(Vector2(-7, -6), Vector2(14, 16))
	draw_rect(head_rect, skin_color)
	draw_rect(head_rect, outline_color, false, 1.0)
	draw_rect(body_rect, outfit_color)
	draw_rect(body_rect, outline_color, false, 1.0)
