extends CanvasLayer

@onready var dialogue_box = $DialogueBox
@onready var dialogue_text = $DialogueBox/DialogueText
@onready var portrait = $DialogueBox/Portrait

var dialogue_lines: Array[String] = []
var current_line: int = 0
var is_active: bool = false

func _ready() -> void:
	visible = false
	dialogue_box.visible = false
	set_process_input(false)

func start_dialogue(lines: Array[String], portrait_texture: Texture2D) -> void:
	if lines.is_empty():
		return

	dialogue_lines = lines
	current_line = 0
	is_active = true

	visible = true
	dialogue_box.visible = true
	dialogue_text.text = dialogue_lines[current_line]
	portrait.texture = portrait_texture

	set_process_input(true)

func _input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("ui_accept"):
		next_line()
		get_viewport().set_input_as_handled()

func next_line() -> void:
	current_line += 1

	if current_line >= dialogue_lines.size():
		end_dialogue()
		return

	dialogue_text.text = dialogue_lines[current_line]

func end_dialogue() -> void:
	is_active = false
	dialogue_lines.clear()
	current_line = 0

	dialogue_text.text = ""
	dialogue_box.visible = false
	visible = false

	set_process_input(false)
