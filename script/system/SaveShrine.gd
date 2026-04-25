extends Node2D
class_name SaveShrine

# SaveShrine v3
# - Shows dialogue before prompt
# - Pauses the game while the Yes/No prompt is open, so the player cannot move
# - Uses ConfirmPromptUI v2

@export_group("Save")
@export var slot_override: int = -1
@export var save_once_per_interaction: bool = false

@export_group("Prompt")
@export var confirm_question: String = "Сохранить прогресс?"
@export var yes_text: String = "Да"
@export var no_text: String = "Нет"

@export_group("Dialogue")
@export var before_prompt_lines: Array[String] = [
	"Святыня излучает мягкий свет..."
]
@export var cancelled_lines: Array[String] = [
	"Вы отошли от святыни."
]
@export var success_lines: Array[String] = [
	"Прогресс сохранён."
]
@export var fail_lines: Array[String] = [
	"Не удалось сохранить прогресс."
]

@export_group("Prompt Style")
@export var prompt_font: Font
@export var prompt_box_position: Vector2 = Vector2(140, 210)
@export var prompt_box_size: Vector2 = Vector2(360, 105)

var _busy: bool = false


func interact(_player: Node = null) -> void:
	if _busy and save_once_per_interaction:
		return

	_busy = true

	await _show_lines(before_prompt_lines)

	var prompt: ConfirmPromptUI = _get_or_create_prompt()
	_apply_prompt_style(prompt)

	var was_paused: bool = get_tree().paused
	get_tree().paused = true

	var should_save: bool = await prompt.ask(confirm_question, yes_text, no_text)

	get_tree().paused = was_paused

	if not should_save:
		await _show_lines(cancelled_lines)
		_busy = false
		return

	var ok: bool = false
	if slot_override > 0:
		ok = Save_Manager.save_game(slot_override)
	else:
		ok = Save_Manager.save_game()

	if ok:
		await _show_lines(success_lines)
	else:
		await _show_lines(fail_lines)

	_busy = false


func _get_or_create_prompt() -> ConfirmPromptUI:
	var scene: Node = get_tree().current_scene
	var found: Node = null

	if scene != null:
		found = scene.find_child("ConfirmPromptUI", true, false)
		if found != null and found is ConfirmPromptUI:
			return found as ConfirmPromptUI

	var prompt: ConfirmPromptUI = ConfirmPromptUI.new()
	prompt.name = "ConfirmPromptUI"
	prompt.process_mode = Node.PROCESS_MODE_ALWAYS

	if scene != null:
		scene.add_child(prompt)
	else:
		get_tree().root.add_child(prompt)

	return prompt


func _apply_prompt_style(prompt: ConfirmPromptUI) -> void:
	if prompt == null:
		return
	prompt.box_position = prompt_box_position
	prompt.box_size = prompt_box_size
	if prompt_font != null:
		prompt.font = prompt_font


func _show_lines(lines: Array[String]) -> void:
	if lines.is_empty():
		return

	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		return

	dlg.call("start_dialogue", lines, null)

	if dlg.has_signal("finished"):
		await dlg.finished
	elif "is_active" in dlg:
		while bool(dlg.is_active):
			await get_tree().process_frame


func _find_dialogue_ui() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var dlg: Node = scene.find_child("DialogueUI", true, false)
		if dlg != null:
			return dlg
	return get_tree().root.find_child("DialogueUI", true, false)
