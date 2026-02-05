extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World club item

func _ready():
	super._ready()
	queue_redraw()
	requires_adjacent = true
	pick_rect_offset = -pick_rect_size / 2.0

func _input(event):
	super._input(event)

func _draw():
	var texture = get_club_texture()
	if texture:
		draw_texture(texture, -texture.get_size() / 2.0)

func get_item_description() -> String:
	return "Club\nA simple wooden weapon."

static var _club_texture: Texture2D = null

static func get_club_texture() -> Texture2D:
	if _club_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var wood = Color(0.55, 0.38, 0.22)
		var dark = Color(0.35, 0.22, 0.12)
		var highlight = Color(0.65, 0.45, 0.25)
		# Handle
		for y in range(10, 26):
			img.set_pixel(15, y, dark)
			img.set_pixel(16, y, wood)
		# Head
		for y in range(6, 12):
			for x in range(10, 22):
				img.set_pixel(x, y, wood)
		# Highlight
		for y in range(7, 10):
			for x in range(12, 16):
				img.set_pixel(x, y, highlight)
		_club_texture = ImageTexture.create_from_image(img)
	return _club_texture

func get_shared_texture() -> Texture2D:
	return get_club_texture()

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
	if equip_menu.has_method("try_equip_club_from_world"):
		return equip_menu.try_equip_club_from_world(self)
	return false

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false
	var hovered = viewport.gui_get_hovered_control()
	return hovered != null
