extends CanvasLayer
signal finished
@onready var dialogue_box: Control = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/DialogueText
@onready var portrait: TextureRect = $DialogueBox/Portrait

var dialogue_lines: Array[String] = []
var current_line: int = 0
var is_active: bool = false

@export var typing_speed: float = 0.03
var typing_tween: Tween


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

	portrait.texture = portrait_texture

	visible = true
	dialogue_box.visible = true
	set_process_input(true)

	show_line()


func _input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("ui_accept"):
		# Если сейчас печатается — допечатать сразу
		if is_typing():
			finish_typing()
		else:
			next_line()

		get_viewport().set_input_as_handled()


func next_line() -> void:
	current_line += 1
	if current_line >= dialogue_lines.size():
		end_dialogue()
		return

	show_line()


func end_dialogue() -> void:
	is_active = false
	dialogue_lines = []
	current_line = 0

	if typing_tween:
		typing_tween.kill()
		typing_tween = null

	dialogue_text.text = ""
	dialogue_box.visible = false
	visible = false
	set_process_input(false)
	finished.emit() 


func show_line() -> void:
	if typing_tween:
		typing_tween.kill()

	dialogue_text.text = dialogue_lines[current_line]
	dialogue_text.visible_characters = 0

	var target: int = dialogue_text.text.length()
	var t: float = float(target) * typing_speed

	typing_tween = create_tween()
	typing_tween.tween_property(dialogue_text, "visible_characters", target, t)


func is_typing() -> bool:
	return dialogue_text.visible_characters >= 0 and dialogue_text.visible_characters < dialogue_text.text.length()


func finish_typing() -> void:
	if typing_tween:
		typing_tween.kill()
		typing_tween = null
	dialogue_text.visible_characters = dialogue_text.text.length()
