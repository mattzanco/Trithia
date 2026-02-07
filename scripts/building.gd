extends Node2D

const TILE_SIZE = 32

@export var size_tiles: Vector2i = Vector2i(3, 3)
@export var wall_color := Color(0.6, 0.55, 0.45)
@export var roof_color := Color(0.35, 0.2, 0.15)
@export var door_color := Color(0.25, 0.15, 0.1)
@export var outline_color := Color(0.12, 0.1, 0.08)

var world: Node = null
var player: Node = null
var building_rect := Rect2i()
var door_tile := Vector2i.ZERO
var is_player_inside = false
var door_open = false
var base_layer: Node2D = null
var roof_layer: Node2D = null
const DOOR_INTERACT_DISTANCE = 48.0

func _ready():
	world = get_world_node()
	player = get_player_node()
	setup_building_tiles()
	ensure_collision_body()
	ensure_layers()
	update_layers()

func _process(_delta):
	if player == null:
		player = get_player_node()
	if world == null:
		world = get_world_node()
	if player == null or world == null:
		return
	var player_feet = player.position + Vector2(0, TILE_SIZE / 2)
	var player_tile = get_tile_coords(player_feet)
	var inside_rect = is_tile_in_interior(player_tile, building_rect)
	if player_tile == door_tile:
		if world.has_method("set_player_inside_building"):
			world.set_player_inside_building(self)
			inside_rect = true
	if world.has_method("clear_player_inside_building") and world.player_inside_building == self and not inside_rect:
		world.clear_player_inside_building(self)
	var next_inside = world.player_inside_building == self
	if next_inside != is_player_inside:
		is_player_inside = next_inside
		update_layers()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if player == null:
			player = get_player_node()
		if player == null:
			return
		var click_position = get_global_mouse_position()
		var click_tile = get_tile_coords(click_position)
		if click_tile != door_tile:
			return
		if player.position.distance_to(click_position) > DOOR_INTERACT_DISTANCE:
			return
		if not door_open and is_player_on_door_tile(player):
			return
		door_open = not door_open
		update_layers()
		get_viewport().set_input_as_handled()

func _exit_tree():
	if world and world.has_method("remove_building"):
		world.remove_building(self)

func setup_building_tiles():
	var tile_pos = get_tile_coords(global_position)
	building_rect = Rect2i(tile_pos, size_tiles)
	door_tile = Vector2i(tile_pos.x + int(size_tiles.x / 2), tile_pos.y + size_tiles.y - 1)
	if world and world.has_method("add_building"):
		world.add_building(self, building_rect, door_tile)
	update_layers()

func ensure_collision_body():
	var body = get_node_or_null("CollisionBody")
	if body == null:
		body = StaticBody2D.new()
		body.name = "CollisionBody"
		add_child(body)
	var shape_node = body.get_node_or_null("CollisionShape2D")
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		body.add_child(shape_node)
	var rect = RectangleShape2D.new()
	var size_px = Vector2(size_tiles.x * TILE_SIZE, size_tiles.y * TILE_SIZE)
	rect.size = size_px
	shape_node.shape = rect
	shape_node.position = size_px / 2.0

func ensure_layers():
	if base_layer == null:
		base_layer = Node2D.new()
		base_layer.name = "BaseLayer"
		var base_script = load("res://scripts/building_base.gd")
		base_layer.set_script(base_script)
		add_child(base_layer)
	if roof_layer == null:
		roof_layer = Node2D.new()
		roof_layer.name = "RoofLayer"
		var roof_script = load("res://scripts/building_roof.gd")
		roof_layer.set_script(roof_script)
		add_child(roof_layer)

func update_layers():
	if base_layer == null or roof_layer == null:
		return
	base_layer.set("size_tiles", size_tiles)
	base_layer.set("wall_color", wall_color)
	base_layer.set("door_color", door_color)
	base_layer.set("outline_color", outline_color)
	base_layer.set("is_player_inside", is_player_inside)
	base_layer.set("door_open", door_open)
	roof_layer.set("size_tiles", size_tiles)
	roof_layer.set("roof_color", roof_color)
	roof_layer.set("is_player_inside", is_player_inside)
	base_layer.queue_redraw()
	roof_layer.queue_redraw()
	base_layer.z_as_relative = true
	roof_layer.z_as_relative = true
	base_layer.z_index = 0
	roof_layer.z_index = 1

func get_tile_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_position.x / TILE_SIZE)), int(floor(world_position.y / TILE_SIZE)))

func is_tile_in_rect(tile: Vector2i, rect: Rect2i) -> bool:
	return tile.x >= rect.position.x and tile.x < rect.position.x + rect.size.x and tile.y >= rect.position.y and tile.y < rect.position.y + rect.size.y

func is_tile_in_interior(tile: Vector2i, rect: Rect2i) -> bool:
	return tile.x >= rect.position.x and tile.x < rect.position.x + rect.size.x and tile.y >= rect.position.y + 1 and tile.y < rect.position.y + rect.size.y

func is_player_on_door_tile(player_node: Node) -> bool:
	if player_node == null:
		return false
	var player_feet = player_node.position + Vector2(0, TILE_SIZE / 2)
	return get_tile_coords(player_feet) == door_tile

func is_door_open() -> bool:
	return door_open

func open_door():
	if door_open:
		return
	door_open = true
	update_layers()

func close_door():
	if not door_open:
		return
	door_open = false
	update_layers()

func get_world_node() -> Node:
	var parent = get_parent()
	if parent:
		if parent.name == "World":
			return parent
		var world_node = parent.get_node_or_null("World")
		if world_node:
			return world_node
	return get_tree().get_root().find_child("World", true, false)

func get_player_node() -> Node:
	var parent = get_parent()
	if parent:
		var player_node = parent.get_node_or_null("Player")
		if player_node:
			return player_node
	return get_tree().get_root().find_child("Player", true, false)
