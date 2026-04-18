extends CanvasLayer
class_name DialogueUI

# DialogueUI v3 (robust + typewriter)
# - Finds DialogueBox / Portrait / DialogueText even if you rearrange nodes
# - Typewriter reveal (printed text) with skip/advance on E
# Controls:
# - Press E (action) or Enter/Space (ui_accept) to:
#   * finish current line instantly (if still typing)
#   * otherwise go to next line / close

@export_group("Nodes (optional overrides)")
@export var dialogue_box_path: NodePath
@export var portrait_path: NodePath
@export var dialogue_text_path: NodePath

@export_group("Typewriter")
@export var chars_per_second: float = 40.0
@export var start_fully_revealed: bool = false

var is_active: bool = false
signal finished

var _lines: Array[String] = []
var _index: int = 0

var _typing: bool = false
var _char_accum: float = 0.0

@onready var dialogue_box: Control = _get_node_or_find(dialogue_box_path, "DialogueBox") as Control
@onready var portrait: TextureRect = _get_node_or_find(portrait_path, "Portrait") as TextureRect
@onready var dialogue_text: RichTextLabel = _get_text_node()

func _ready() -> void:
	visible = false
	if dialogue_box != null:
		dialogue_box.visible = false

	set_process(false)
	set_process_input(false)

	if dialogue_text != null:
		dialogue_text.bbcode_enabled = true
		# Make sure we control reveal.
		dialogue_text.visible_characters = -1


func start_dialogue(lines: Array[String], portrait_tex: Texture2D = null) -> void:
	if lines.is_empty():
		return

	_lines = lines
	_index = 0
	is_active = true

	visible = true
	if dialogue_box != null:
		dialogue_box.visible = true

	if portrait != null:
		portrait.texture = portrait_tex

	set_process_input(true)
	set_process(true)

	_show_current_line()


func _process(delta: float) -> void:
	if not is_active:
		return
	if dialogue_text == null:
		return
	if not _typing:
		return

	var total := dialogue_text.get_total_character_count()
	if total <= 0:
		_typing = false
		return

	_char_accum += chars_per_second * delta
	var step := int(_char_accum)
	if step <= 0:
		return
	_char_accum -= step

	var cur := dialogue_text.visible_characters
	if cur < 0:
		cur = 0

	cur += step
	if cur >= total:
		dialogue_text.visible_characters = -1  # show all
		_typing = false
	else:
		dialogue_text.visible_characters = cur


func _input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("action"):
		_on_accept()
		get_viewport().set_input_as_handled()


func _on_accept() -> void:
	if dialogue_text == null:
		_advance()
		return

	# If typing, finish instantly
	if _typing:
		dialogue_text.visible_characters = -1
		_typing = false
		return

	# Otherwise, go next
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	_show_current_line()


func _show_current_line() -> void:
	if dialogue_text == null:
		return

	dialogue_text.bbcode_enabled = true
	dialogue_text.text = _lines[_index]

	_char_accum = 0.0

	if start_fully_revealed:
		dialogue_text.visible_characters = -1
		_typing = false
	else:
		dialogue_text.visible_characters = 0
		_typing = true


func _close() -> void:
	is_active = false
	_typing = false
	set_process(false)
	set_process_input(false)

	if dialogue_box != null:
		dialogue_box.visible = false
	visible = false

	emit_signal("finished")


# -------- helpers --------

func _get_node_or_find(path: NodePath, fallback_name: String) -> Node:
	if path != NodePath(""):
		var n := get_node_or_null(path)
		if n != null:
			return n
	return find_child(fallback_name, true, false)


func _get_text_node() -> RichTextLabel:
	if dialogue_text_path != NodePath(""):
		var n := get_node_or_null(dialogue_text_path)
		if n is RichTextLabel:
			return n

	var n1 := find_child("DialogueText", true, false)
	if n1 is RichTextLabel:
		return n1

	var n2 := find_child("Dialogue", true, false)
	if n2 is RichTextLabel:
		return n2

	return _find_first_richtext(self)


func _find_first_richtext(root: Node) -> RichTextLabel:
	for ch in root.get_children():
		if ch is RichTextLabel:
			return ch
		var sub := _find_first_richtext(ch)
		if sub != null:
			return sub
	return null
