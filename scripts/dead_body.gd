extends "res://scripts/draggable_item.gd"

# Visual representation of a dead orc with container functionality

var container_window: Control = null
var container_slots: Array = []
var container_items: Array = []
var is_container_open = false

func _ready():
	super._ready()
	# Initialize 8-slot container
	for i in range(8):
		container_items.append(null)
	# Dead bodies don't need to be draggable
	requires_adjacent = true
	queue_redraw()

func _input(event):
	# Handle right-click to open container BEFORE parent drag handling
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		if get_pick_rect().has_point(mouse_pos) and can_player_drag():
			toggle_container()
			get_viewport().set_input_as_handled()
			return
	
	# Let parent handle dragging
	super._input(event)

func toggle_container():
	if container_window == null:
		create_container_window()
	container_window.visible = !container_window.visible
	is_container_open = container_window.visible

func create_container_window():
	var root = get_tree().root
	var equip_menu = root.find_child("EquipmentMenu", true, false)
	if equip_menu == null:
		return
	
	container_window = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.35, 0.3, 0.25, 1)
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 6
	container_window.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	container_window.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	# Title bar with close button
	var title_bar = HBoxContainer.new()
	title_bar.set_meta("is_title_bar", true)
	title_bar.set_meta("body_ref", self)
	vbox.add_child(title_bar)
	
	var title = Label.new()
	title.text = "Dead Body"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.9, 0.85, 0.75, 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(20, 20)
	close_button.modulate = Color(0.9, 0.85, 0.75, 1)
	close_button.pressed.connect(func(): container_window.visible = false)
	title_bar.add_child(close_button)
	
	# Grid for items
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)
	
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.14, 0.12, 0.1, 1)
	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.border_color = Color(0.5, 0.4, 0.3, 1)
	slot_style.corner_radius_top_left = 3
	slot_style.corner_radius_top_right = 3
	slot_style.corner_radius_bottom_right = 3
	slot_style.corner_radius_bottom_left = 3
	
	# Create 8 slots
	for i in range(8):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(32, 32)
		slot.add_theme_stylebox_override("panel", slot_style)
		grid.add_child(slot)
		container_slots.append(slot)
	
	equip_menu.add_child(container_window)
	container_window.visible = false
	container_window.position = Vector2(200, 100)
	container_window.custom_minimum_size = Vector2(160, 120)
	container_window.set_meta("is_body_container", true)
	container_window.set_meta("body_ref", self)

func _exit_tree():
	if container_window and is_instance_valid(container_window):
		container_window.queue_free()
		container_window = null

func _draw():
	# Draw a dead orc lying sideways (pale green) centered in tile
	var dead_color = Color(0.6, 0.8, 0.6)  # Pale green
	var outline_color = Color(0.3, 0.4, 0.3)  # Dark green outline
	var blood_color = Color(0.8, 0.1, 0.1, 0.6)
	
	# Head (lying on its side)
	draw_rect(Rect2(8, 8, 12, 12), dead_color)
	draw_rect(Rect2(7, 7, 14, 14), outline_color, false, 1.0)
	
	# X eyes (death symbol) on the side of head
	draw_line(Vector2(10, 10), Vector2(12, 12), Color.BLACK, 1.5)
	draw_line(Vector2(12, 10), Vector2(10, 12), Color.BLACK, 1.5)
	
	# Body (torso lying horizontal)
	draw_rect(Rect2(-8, 11, 18, 10), dead_color)
	draw_rect(Rect2(-9, 10, 20, 12), outline_color, false, 1.0)
	
	# Left arm (extended up from body)
	draw_line(Vector2(-8, 11), Vector2(-12, 6), dead_color, 3.0)
	draw_line(Vector2(-8, 11), Vector2(-12, 6), outline_color, 1.0)
	
	# Right arm (under body)
	draw_line(Vector2(10, 16), Vector2(14, 20), dead_color, 3.0)
	draw_line(Vector2(10, 16), Vector2(14, 20), outline_color, 1.0)
	
	# Legs (extended to the right, lying down)
	draw_line(Vector2(10, 13), Vector2(16, 12), dead_color, 3.0)
	draw_line(Vector2(10, 13), Vector2(16, 12), outline_color, 1.0)
	draw_line(Vector2(10, 17), Vector2(16, 18), dead_color, 3.0)
	draw_line(Vector2(10, 17), Vector2(16, 18), outline_color, 1.0)
	
	# Blood pool under the body
	draw_circle(Vector2(0, 18), 2.0, blood_color)
	draw_circle(Vector2(5, 19), 1.5, blood_color)
	draw_circle(Vector2(-5, 17), 1.5, blood_color)


