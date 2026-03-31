extends CharacterBody2D

@export var dialogue_lines: Array[String] = []
@export var portrait: Texture2D

func interact() -> void:
	var dialogue_ui = get_tree().current_scene.get_node_or_null("DialogueUI")
	if dialogue_ui == null:
		return

	dialogue_ui.start_dialogue(dialogue_lines, portrait)
