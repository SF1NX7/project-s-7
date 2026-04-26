extends Area2D
class_name InspectHotspot

# Universal invisible interaction zone.
# Use it as a separate scene/node over barrels, shelves, wells, signs, etc.
#
# Recommended tree:
# InspectHotspot (Area2D) <- this script
#   CollisionShape2D
#
# In Inspector:
# - message_lines: text shown when player presses E
# - one_time: if true, message is shown only once during current scene run
# - repeat_message_lines: optional text after it was already inspected

@export_group("Text")
@export_multiline var message_lines: Array[String] = [
	"Здесь ничего интересного."
]
@export_multiline var repeat_message_lines: Array[String] = []

@export_group("Behavior")
@export var one_time: bool = false
@export var inspected: bool = false

@export_group("Dialogue")
@export var portrait: Texture2D
@export var line_font_size: int = 36
@export var center_text: bool = true


func interact(_player: Node = null) -> void:
	var lines: Array[String] = []

	if inspected and one_time:
		if repeat_message_lines.is_empty():
			return
		lines = _format_lines(repeat_message_lines)
	else:
		lines = _format_lines(message_lines)
		inspected = true

	if lines.is_empty():
		return

	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		push_warning("InspectHotspot: DialogueUI with start_dialogue() was not found.")
		return

	dlg.call("start_dialogue", lines, portrait)


func _format_lines(source: Array[String]) -> Array[String]:
	var out: Array[String] = []

	for raw_line in source:
		var text: String = str(raw_line).strip_edges()
		if text == "":
			continue

		if line_font_size > 0:
			text = "[font_size=%d]%s[/font_size]" % [line_font_size, text]

		if center_text:
			text = "[center]%s[/center]" % text

		out.append(text)

	return out


func _find_dialogue_ui() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var dlg: Node = scene.find_child("DialogueUI", true, false)
		if dlg != null:
			return dlg

	return get_tree().root.find_child("DialogueUI", true, false)
