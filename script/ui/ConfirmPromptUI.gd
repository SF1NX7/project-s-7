extends CanvasLayer
class_name ConfirmPromptUI

# ConfirmPromptUI v2
# Prettier Yes/No prompt.
# Runs while the game tree is paused (process_mode = ALWAYS), so player cannot move.
#
# Controls:
# - move_left / move_right / move_up / move_down: switch Да/Нет
# - action / ui_accept: confirm
# - ui_cancel: choose No

signal answered(result: bool)

@export_group("Layout")
@export var box_position: Vector2 = Vector2(140, 210)
@export var box_size: Vector2 = Vector2(360, 105)
@export var padding: int = 10

@export_group("Style")
@export var bg_color: Color = Color(0.08, 0.10, 0.08, 0.88)
@export var border_color: Color = Color(0.82, 0.66, 0.36, 1.0)
@export var border_width: int = 3
@export var corner_radius: int = 8
@export var normal_color: Color = Color(0.72, 0.72, 0.72, 1.0)
@export var selected_color: Color = Color(1.0, 0.92, 0.62, 1.0)

@export_group("Text")
@export var font: Font
@export var question_font_size: int = 30
@export var option_font_size: int = 28
@export var selected_prefix: String = "▶ "
@export var unselected_prefix: String = "  "

var _panel: Panel = null
var _label: RichTextLabel = null

var _question: String = ""
var _yes_text: String = "Да"
var _no_text: String = "Нет"
var _selected_yes: bool = true
var _active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_build_ui()
	visible = false
	set_process_input(false)


func ask(question: String, yes_text: String = "Да", no_text: String = "Нет") -> bool:
	_question = question
	_yes_text = yes_text
	_no_text = no_text
	_selected_yes = true
	_active = true

	_update_text()

	visible = true
	set_process_input(true)

	var result: bool = await answered

	_active = false
	set_process_input(false)
	visible = false

	return result


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") or event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		_selected_yes = not _selected_yes
		_update_text()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		emit_signal("answered", _selected_yes)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		emit_signal("answered", false)
		get_viewport().set_input_as_handled()
		return


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.position = box_position
	_panel.size = box_size
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	_panel.add_theme_stylebox_override("panel", style)

	_label = RichTextLabel.new()
	_label.position = Vector2(float(padding), float(padding))
	_label.size = box_size - Vector2(float(padding * 2), float(padding * 2))
	_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_label.bbcode_enabled = true
	_label.fit_content = false
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font != null:
		_label.add_theme_font_override("normal_font", font)
		_label.add_theme_font_override("bold_font", font)
	_panel.add_child(_label)


func _update_text() -> void:
	if _label == null:
		return

	var yes_prefix: String = selected_prefix if _selected_yes else unselected_prefix
	var no_prefix: String = selected_prefix if not _selected_yes else unselected_prefix

	var yes_hex: String = selected_color.to_html(false) if _selected_yes else normal_color.to_html(false)
	var no_hex: String = selected_color.to_html(false) if not _selected_yes else normal_color.to_html(false)

	var text: String = ""
	text += "[center][font_size=%d][b]%s[/b][/font_size][/center]\n" % [question_font_size, _question]
	text += "[center][font_size=%d]" % option_font_size
	text += "[color=#%s]%s%s[/color]     " % [yes_hex, yes_prefix, _yes_text]
	text += "[color=#%s]%s%s[/color]" % [no_hex, no_prefix, _no_text]
	text += "[/font_size][/center]"

	_label.text = text
