extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World meat item

func _ready():
	super._ready()
	queue_redraw()
	requires_adjacent = true
	pick_rect_offset = -pick_rect_size / 2.0

func _input(event):
	super._input(event)

func _draw():
	var texture = get_meat_texture()
	if texture:
		draw_texture(texture, -texture.get_size() / 2.0)

func get_item_description() -> String:
	return "Meat\nRestores health over time."

static var _meat_texture: Texture2D = null

static func get_meat_texture() -> Texture2D:
	if _meat_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var meat = Color(0.7, 0.3, 0.3)
		var fat = Color(0.85, 0.75, 0.65)
		var dark = Color(0.5, 0.2, 0.2)
		# Meat body
		for y in range(10, 22):
			for x in range(9, 23):
				img.set_pixel(x, y, meat)
		# Fat cap
		for y in range(10, 13):
			for x in range(11, 21):
				img.set_pixel(x, y, fat)
		# Outline/shadow
		for x in range(9, 23):
			img.set_pixel(x, 21, dark)
		for y in range(10, 22):
			img.set_pixel(9, y, dark)
			img.set_pixel(22, y, dark)
		_meat_texture = ImageTexture.create_from_image(img)
	return _meat_texture

func get_shared_texture() -> Texture2D:
	return get_meat_texture()

func finish_drop():
	if try_equip_in_ui():
		return
	if is_mouse_over_ui():
		global_position = original_position
		return
	super.finish_drop()

func try_equip_in_ui() -> bool:
	var equip_menu = get_tree().get_root().find_child("EquipmentMenu", true, false)
	if equip_menu == null:
		return false
	if equip_menu.has_method("try_store_meat_from_world"):
		return equip_menu.try_store_meat_from_world(self)
	return false

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false
	var hovered = viewport.gui_get_hovered_control()
	return hovered != null
