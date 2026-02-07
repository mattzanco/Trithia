extends Node2D

const TRUNK_SCRIPT = preload("res://scripts/tree_trunk.gd")
const CANOPY_SCRIPT = preload("res://scripts/tree_canopy.gd")

func _ready():
	create_layers()

func create_layers():
	var trunk = Node2D.new()
	trunk.name = "Trunk"
	trunk.set_script(TRUNK_SCRIPT)
	trunk.z_as_relative = true
	trunk.z_index = 0
	add_child(trunk)

	var canopy = Node2D.new()
	canopy.name = "Canopy"
	canopy.set_script(CANOPY_SCRIPT)
	canopy.z_as_relative = true
	canopy.z_index = 3
	add_child(canopy)
