extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World helmet item

func _ready():
	super._ready()
	queue_redraw()
	# Allow equip without adjacency when dragging onto UI
	requires_adjacent = true

func _draw():
	# Simple helmet icon (metal gray)
	var metal = Color(0.7, 0.7, 0.75)
	var outline = Color(0.1, 0.1, 0.1)
	# Dome
	draw_rect(Rect2(6, 4, 20, 10), metal)
	draw_rect(Rect2(6, 4, 20, 10), outline, false, 1.0)
	# Rim
	draw_rect(Rect2(6, 12, 20, 4), metal)
	draw_rect(Rect2(6, 12, 20, 4), outline, false, 1.0)

func finish_drop():
	if try_equip_in_ui():
		return
	super.finish_drop()

func try_equip_in_ui() -> bool:
	var equip_menu = get_tree().get_root().find_child("EquipmentMenu", true, false)
	if equip_menu == null:
		return false
	if equip_menu.has_method("try_equip_helmet_from_world"):
		return equip_menu.try_equip_helmet_from_world(self)
	return false
