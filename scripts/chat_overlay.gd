extends CanvasLayer

signal conversation_closed(npc)
signal input_state_changed(active: bool)

@export var llm_url := "http://127.0.0.1:8080/v1/chat/completions"
@export var model_name := "local"
@export var max_tokens := 120
@export var temperature := 0.7
@export var request_timeout_sec := 6.0

var active_npc: Node = null
var conversation_messages: Array = []
var http_request: HTTPRequest
var last_user_text := ""
var conversation_active := false
var input_open := false

const AUTO_TALK_DISTANCE := 48.0

enum ChatMode {
	GLOBAL,
	NPC
}

var mode := ChatMode.GLOBAL

@onready var panel: PanelContainer = $Panel
@onready var npc_name_label: Label = $Panel/VBox/NpcName
@onready var history: RichTextLabel = $Panel/VBox/Scroll/History
@onready var input: LineEdit = $Panel/VBox/InputRow/Line
@onready var input_row: HBoxContainer = $Panel/VBox/InputRow
@onready var send_button: Button = $Panel/VBox/InputRow/SendButton
@onready var close_button: Button = $Panel/VBox/InputRow/CloseButton

func _ready():
	panel.visible = true
	input_row.visible = false
	input.editable = false
	npc_name_label.text = "Chat"
	http_request = HTTPRequest.new()
	http_request.timeout = request_timeout_sec
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	send_button.pressed.connect(_on_send_pressed)
	close_button.pressed.connect(_on_close_pressed)
	input.text_submitted.connect(_on_input_submitted)

func _unhandled_input(event):
	if not panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if conversation_active:
				close()
			elif input_open:
				close_input()
			get_viewport().set_input_as_handled()
			return

func start_conversation(npc: Node):
	active_npc = npc
	conversation_messages.clear()
	conversation_active = true
	mode = ChatMode.NPC
	panel.visible = true
	input.text = ""
	open_input()
	var profile = _get_npc_profile()
	npc_name_label.text = profile["name"]
	if active_npc and active_npc.has_method("set_talking"):
		active_npc.set_talking(true)
	if profile["greeting"] != "":
		_append_line(profile["name"], profile["greeting"])
		conversation_messages.append({"role": "assistant", "content": profile["greeting"]})

func close():
	var closed_npc = active_npc
	active_npc = null
	conversation_active = false
	mode = ChatMode.GLOBAL
	npc_name_label.text = "Chat"
	close_input()
	emit_signal("conversation_closed", closed_npc)

func _on_close_pressed():
	if conversation_active:
		close()
	else:
		close_input()

func _on_send_pressed():
	_submit_line(input.text)

func _on_input_submitted(text: String):
	_submit_line(text)

func _submit_line(text: String):
	var trimmed = text.strip_edges()
	if trimmed == "":
		return
	if mode == ChatMode.GLOBAL:
		var npc = _get_nearest_npc_for_auto_chat()
		if npc != null:
			start_conversation(npc)
			_submit_npc_line(trimmed)
			return
		_append_line("You", trimmed)
		input.text = ""
		close_input()
		return
	if active_npc == null:
		return
	_submit_npc_line(trimmed)

func _submit_npc_line(trimmed: String):
	last_user_text = trimmed
	_append_line("You", trimmed)
	conversation_messages.append({"role": "user", "content": trimmed})
	input.text = ""
	input.editable = false
	send_button.disabled = true
	_request_response(trimmed)

func _request_response(_user_text: String):
	var profile = _get_npc_profile()
	var payload = {
		"model": model_name,
		"messages": _build_messages(profile),
		"temperature": temperature,
		"max_tokens": max_tokens
	}
	var body = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	var err = http_request.request(llm_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_handle_llm_failure("I am not sure what to say right now.")

func _on_request_completed(_result, response_code, _headers, body):
	if not panel.visible or active_npc == null:
		return
	input.editable = true
	send_button.disabled = false
	if response_code < 200 or response_code >= 300:
		_handle_llm_failure("I am not sure what to say right now.")
		return
	var text = body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_handle_llm_failure("I do not have words for that just now.")
		return
	var reply = _extract_reply(parsed)
	if reply == "":
		_handle_llm_failure("I do not have words for that just now.")
		return
	var profile = _get_npc_profile()
	_append_line(profile["name"], reply)
	conversation_messages.append({"role": "assistant", "content": reply})

func _handle_llm_failure(fallback: String):
	input.editable = true
	send_button.disabled = false
	var profile = _get_npc_profile()
	var reply = fallback
	if last_user_text != "":
		reply = _local_fallback_reply(profile, last_user_text)
	_append_line(profile["name"], reply)
	conversation_messages.append({"role": "assistant", "content": reply})

func _build_messages(profile: Dictionary) -> Array:
	var messages: Array = []
	messages.append({"role": "system", "content": _build_system_prompt(profile)})
	var history_slice = conversation_messages
	if history_slice.size() > 6:
		history_slice = history_slice.slice(history_slice.size() - 6, history_slice.size())
	for item in history_slice:
		messages.append(item)
	return messages

func _build_system_prompt(profile: Dictionary) -> String:
	var memory_text = profile["memory"] if profile["memory"] != "" else "None."
	return "You are %s, an NPC in the game Trithia. Persona: %s Memory: %s Speak in 1-3 sentences. Stay in-world. Do not mention being an AI, model, or external tools." % [profile["name"], profile["persona"], memory_text]

func _extract_reply(data: Dictionary) -> String:
	if data.has("choices") and data.choices.size() > 0:
		var choice = data.choices[0]
		if choice.has("message") and choice.message.has("content"):
			return str(choice.message.content).strip_edges()
		if choice.has("text"):
			return str(choice.text).strip_edges()
	return ""

func _append_line(speaker: String, text: String):
	history.append_text("[b]%s:[/b] %s\n" % [speaker, text])
	history.scroll_to_line(history.get_line_count())

func _get_nearest_npc_for_auto_chat() -> Node:
	var player = _get_player_node()
	if player and player.has_method("get_nearest_npc"):
		return player.get_nearest_npc()
	var nearest = null
	var nearest_dist = AUTO_TALK_DISTANCE
	var player_pos = player.global_position if player else Vector2.ZERO
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc == null:
			continue
		var dist = player_pos.distance_to(npc.global_position)
		if dist <= nearest_dist:
			nearest = npc
			nearest_dist = dist
	return nearest

func _get_player_node() -> Node:
	return get_tree().get_root().find_child("Player", true, false)

func open_input():
	if input_open:
		input.grab_focus()
		return
	if conversation_active:
		mode = ChatMode.NPC
	else:
		mode = ChatMode.GLOBAL
	input_open = true
	input_row.visible = true
	input.editable = true
	send_button.disabled = false
	close_button.disabled = false
	input.grab_focus()
	emit_signal("input_state_changed", true)

func close_input():
	if not input_open:
		return
	input_open = false
	input.text = ""
	input.editable = false
	send_button.disabled = true
	close_button.disabled = true
	input_row.visible = false
	input.release_focus()
	emit_signal("input_state_changed", false)

func is_conversation_active() -> bool:
	return conversation_active

func is_input_open() -> bool:
	return input_open

func _get_npc_profile() -> Dictionary:
	var profile = {"name": "NPC", "persona": "", "greeting": "", "memory": ""}
	if active_npc and active_npc.has_method("get_chat_profile"):
		var npc_profile = active_npc.get_chat_profile()
		if npc_profile.has("name"):
			profile["name"] = str(npc_profile["name"])
		if npc_profile.has("persona"):
			profile["persona"] = str(npc_profile["persona"])
		if npc_profile.has("greeting"):
			profile["greeting"] = str(npc_profile["greeting"])
		if npc_profile.has("memory"):
			profile["memory"] = str(npc_profile["memory"])
	return profile

func _local_fallback_reply(profile: Dictionary, user_text: String) -> String:
	var text = user_text.to_lower()
	if text.find("village") >= 0 or text.find("town") >= 0 or text.find("place") >= 0 or text.find("where am i") >= 0:
		return "People just call it the town. It is small, but safe enough if you keep to the roads."
	if text.find("name") >= 0:
		return "My name is %s." % profile["name"]
	if text.find("who") >= 0 and text.find("you") >= 0:
		return "I am %s. %s" % [profile["name"], profile["persona"]]
	if text.find("hello") >= 0 or text.find("hi") >= 0 or text.find("hey") >= 0:
		return "Hello. How can I help?"
	if text.find("job") >= 0 or text.find("work") >= 0:
		return "I keep busy around town. Nothing too exciting."
	if text.find("quest") >= 0 or text.find("task") >= 0:
		return "No official work, but the roads get rough after dark. Keep your gear ready."
	if text.find("rumor") >= 0 or text.find("news") >= 0:
		return "Folks say something stirs out in the woods, but no one agrees on what."
	if text.find("help") >= 0:
		return "If you need directions, ask about the town." 
	if text.ends_with("?"):
		return "I do not know the answer, but I can tell you about the town or the roads."
	return "I am not sure, but I can try to help if you ask about the town."
