extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World helmet item

func _ready():
	super._ready()
	queue_redraw()
	# Allow equip without adjacency when dragging onto UI
	requires_adjacent = true

func _draw():
	# Shaded helmet icon (metal gray)
	var metal = Color(0.7, 0.7, 0.75)
	var highlight = Color(0.85, 0.85, 0.9)
	var shadow = Color(0.55, 0.55, 0.6)
	var outline = Color(0.1, 0.1, 0.1)

	# Dome base
	draw_rect(Rect2(6, 4, 20, 9), metal)
	# Highlight
	draw_rect(Rect2(8, 5, 6, 3), highlight)
	# Shadow band
	draw_rect(Rect2(6, 11, 20, 2), shadow)

	# Rim
	draw_rect(Rect2(5, 12, 22, 4), metal)
	# Rim highlight
	draw_rect(Rect2(7, 12, 6, 2), highlight)

	# Outline
	draw_rect(Rect2(6, 4, 20, 9), outline, false, 1.0)
	draw_rect(Rect2(5, 12, 22, 4), outline, false, 1.0)

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
