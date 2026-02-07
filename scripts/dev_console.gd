extends CanvasLayer

signal command_submitted(command: String)

const MAX_LOG_LINES = 8

var panel: PanelContainer
var log_label: Label
var input_line: LineEdit
var log_lines: Array = []

func _ready():
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	build_ui()

func build_ui():
	panel = PanelContainer.new()
	panel.name = "DevConsolePanel"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.anchor_left = 0.02
	panel.anchor_top = 0.02
	panel.anchor_right = 0.58
	panel.anchor_bottom = 0.25
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var margin = MarginContainer.new()
	margin.process_mode = Node.PROCESS_MODE_ALWAYS
	margin.anchor_left = 0
	margin.anchor_top = 0
	margin.anchor_right = 1
	margin.anchor_bottom = 1
	margin.offset_left = 8
	margin.offset_top = 8
	margin.offset_right = -8
	margin.offset_bottom = -8
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title = Label.new()
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	title.text = "Dev Console"
	vbox.add_child(title)

	log_label = Label.new()
	log_label.process_mode = Node.PROCESS_MODE_ALWAYS
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.text = "Type 'spawn orc' or 'spawn troll'"
	vbox.add_child(log_label)

	input_line = LineEdit.new()
	input_line.placeholder_text = "Command..."
	input_line.process_mode = Node.PROCESS_MODE_ALWAYS
	input_line.focus_mode = Control.FOCUS_ALL
	input_line.text_submitted.connect(_on_text_submitted)
	vbox.add_child(input_line)

func toggle():
	visible = not visible
	get_tree().paused = visible
	if visible:
		if input_line:
			input_line.grab_focus()
			input_line.select_all()
	else:
		if input_line:
			input_line.release_focus()

func append_log(line: String):
	log_lines.append(line)
	if log_lines.size() > MAX_LOG_LINES:
		log_lines.remove_at(0)
	log_label.text = "\n".join(log_lines)

func _on_text_submitted(text: String):
	var trimmed = text.strip_edges()
	if trimmed == "":
		return
	append_log("> " + trimmed)
	input_line.clear()
	emit_signal("command_submitted", trimmed)

func _unhandled_input(event):
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			toggle()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
