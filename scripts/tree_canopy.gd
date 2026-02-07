extends Node2D

const TILE_SIZE = 32

@export var leaf_color := Color(0.2, 0.5, 0.2)
@export var leaf_dark := Color(0.12, 0.35, 0.12)
@export var outline_color := Color(0.1, 0.1, 0.1)

func _ready():
	z_as_relative = true
	z_index = 2
	queue_redraw()

func _draw():
	# Canopy centered on this node's position.
	var canopy_center = Vector2(0, 0)
	var canopy_radius = 22.0
	draw_circle(canopy_center, canopy_radius, leaf_color)
	# Clustered leaf blobs.
	draw_circle(canopy_center + Vector2(-10, -4), 12.0, leaf_color)
	draw_circle(canopy_center + Vector2(10, -3), 11.0, leaf_color)
	draw_circle(canopy_center + Vector2(0, 6), 13.0, leaf_color)
	# Darker lower arc for depth.
	draw_circle(canopy_center + Vector2(0, 8), canopy_radius - 7.0, leaf_dark)
	# Simple highlight.
	draw_circle(canopy_center + Vector2(-6, -8), 7.0, leaf_dark.lerp(leaf_color, 0.5))
	draw_arc(canopy_center, canopy_radius, 0, TAU, 18, outline_color, 1.0)
