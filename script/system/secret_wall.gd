extends Node2D
class_name SecretWall

# SecretWall v4 persistent state
# Saves opened/found state through Save_Manager.
#
# Required:
# - SaveManager_v9_world_state.gd as Autoload name Save_Manager
# - Inventory_Service autoload for reward
#
# Important:
# Set secret_id in Inspector for every secret.
# Example:
#   world1_secret_wall_helmet_01

@export_group("Persistent State")
@export var secret_id: String = ""
@export var one_time: bool = true
@export var opened: bool = false

@export_group("Reward")
@export var item_data: ItemData

@export_group("Dialogue")
@export var opened_text: String = "Вы нашли тайник."
@export var already_opened_text: String = "Здесь больше ничего нет."
@export var item_line_template: String = "Вы нашли: %s"
@export var header_font_size: int = 36
@export var loot_font_size: int = 36


func _ready() -> void:
	if Save_Manager != null:
		var id_text: String = _get_state_id()
		if Save_Manager.is_secret_opened(id_text):
			opened = true


func interact(_player: Node = null) -> void:
	if opened and one_time:
		_show_already_opened_message()
		return

	opened = true

	var id_text: String = _get_state_id()
	if Save_Manager != null:
		Save_Manager.mark_secret_opened(id_text)

	if item_data != null:
		Inventory_Service.add_item(item_data)

	_show_message()


func _get_state_id() -> String:
	var id_text: String = secret_id.strip_edges()
	if id_text != "":
		return id_text

	var scene_path: String = ""
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	return "%s::%s" % [scene_path, str(get_path())]


func _show_message() -> void:
	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		return

	var lines: Array[String] = []
	lines.append(_center_size_bold(opened_text, header_font_size))

	if item_data != null:
		var title: String = str(item_data.title) if ("title" in item_data) else "предмет"
		lines.append(_center_size(item_line_template % title, loot_font_size))

	dlg.call("start_dialogue", lines, null)


func _show_already_opened_message() -> void:
	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		return

	var lines: Array[String] = []
	lines.append(_center_size_bold(already_opened_text, header_font_size))
	dlg.call("start_dialogue", lines, null)


func _find_dialogue_ui() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var dlg: Node = scene.find_child("DialogueUI", true, false)
		if dlg != null:
			return dlg
	return get_tree().root.find_child("DialogueUI", true, false)


func _center_size(text: String, px: int) -> String:
	if px <= 0:
		return "[center]%s[/center]" % text
	return "[center][font_size=%d]%s[/font_size][/center]" % [px, text]


func _center_size_bold(text: String, px: int) -> String:
	if px <= 0:
		return "[center][b]%s[/b][/center]" % text
	return "[center][font_size=%d][b]%s[/b][/font_size][/center]" % [px, text]
