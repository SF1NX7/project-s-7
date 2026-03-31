extends CanvasLayer

@onready var dialogue_box = get_node_or_null("DialogueBox")
@onready var dialogue_text = get_node_or_null("DialogueBox/DialogueText")
@onready var portrait_rect = get_node_or_null("DialogueBox/Portrait")

var lines: Array[String] = []
var current_line: int = 0
var is_active: bool = false
var typing_speed: float = 0.03
var is_typing: bool = false

func _ready() -> void:
	if dialogue_box != null:
		dialogue_box.visible = false

	if portrait_rect != null:
		portrait_rect.visible = false

func start_dialogue(dialogue_lines: Array[String], portrait: Texture2D) -> void:
	if dialogue_lines.is_empty():
		return

	lines = dialogue_lines.duplicate()
	current_line = 0
	is_active = true

	var player = get_tree().current_scene.get_node_or_null("Player")
	if player != null:
		player.can_move = false
		player.moving = false

	if dialogue_box != null:
		dialogue_box.visible = true

	if dialogue_text != null:
		dialogue_text.text = lines[current_line]
		dialogue_text.visible_characters = 0
		type_line()

	if portrait_rect != null:
		if portrait != null:
			portrait_rect.texture = portrait
			portrait_rect.visible = true
		else:
			portrait_rect.texture = null
			portrait_rect.visible = false

func type_line() -> void:
	is_typing = true

	for i in dialogue_text.text.length():
		dialogue_text.visible_characters = i + 1
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false

func next_line() -> void:
	if not is_active:
		return

	if is_typing:
		dialogue_text.visible_characters = dialogue_text.text.length()
		is_typing = false
		return

	current_line += 1

	if current_line >= lines.size():
		end_dialogue()
		return

	dialogue_text.text = lines[current_line]
	dialogue_text.visible_characters = 0
	type_line()

func end_dialogue() -> void:
	is_active = false
	is_typing = false
	lines.clear()
	current_line = 0

	if dialogue_box != null:
		dialogue_box.visible = false

	if dialogue_text != null:
		dialogue_text.text = ""
		dialogue_text.visible_characters = -1

	if portrait_rect != null:
		portrait_rect.texture = null
		portrait_rect.visible = false

	var player = get_tree().current_scene.get_node_or_null("Player")
	if player != null:
		player.can_move = true
