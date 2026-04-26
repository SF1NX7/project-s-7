extends Node2D
class_name Chest

# Chest v8 persistent state
# Saves opened/closed state through Save_Manager.
#
# Required:
# - SaveManager_v9_world_state.gd as Autoload name Save_Manager
# - Inventory_Service autoload for rewards
#
# Important:
# Set chest_id in Inspector for every chest.
# Example:
#   world1_potion_chest_01
#   world1_helm_chest_01

@export_group("Persistent State")
@export var chest_id: String = ""
@export var one_time: bool = true
@export var opened: bool = false

@export_group("Data")
@export var data: ChestData

@export_group("Visual")
@export var closed_texture: Texture2D
@export var opened_texture: Texture2D

@export_group("Dialogue")
@export var opened_header: String = "Вы открыли сундук."
@export var already_opened_header: String = "Сундук пуст."
@export var gold_line_template: String = "Вы нашли %d золота."
@export var item_line_template: String = "Вы нашли: %s"
@export var header_font_size: int = 36
@export var loot_font_size: int = 36
@export var portrait: Texture2D

@onready var spr: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var hit_area: Area2D = get_node_or_null("HitArea") as Area2D


func _ready() -> void:
	add_to_group("chests")
	# If this chest was opened in loaded save, mark it opened immediately.
	if Save_Manager != null:
		var id_text: String = _get_state_id()
		if Save_Manager.is_chest_opened(id_text):
			opened = true

	_update_sprite()

	if opened and one_time:
		_disable_hit_area()


func interact(_player: Node = null) -> void:
	if opened and one_time:
		_show_already_opened_message()
		return

	_open()


func _open() -> void:
	opened = true
	_update_sprite()

	var id_text: String = _get_state_id()
	if Save_Manager != null:
		Save_Manager.mark_chest_opened(id_text)

	_show_loot_message()
	_give_loot()

	if one_time:
		_disable_hit_area()


func _get_state_id() -> String:
	var id_text: String = chest_id.strip_edges()
	if id_text != "":
		return id_text

	# Fallback. Better than nothing, but manual chest_id is safer.
	var scene_path: String = ""
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	return "%s::%s" % [scene_path, str(get_path())]


func _give_loot() -> void:
	if data == null:
		return

	if data.items != null and not data.items.is_empty():
		Inventory_Service.add_items(data.items)

	if int(data.gold) != 0:
		Inventory_Service.add_gold(int(data.gold))


func _show_loot_message() -> void:
	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		return

	var lines: Array[String] = []
	lines.append(_center_size_bold(opened_header, header_font_size))

	if data != null:
		if int(data.gold) != 0:
			lines.append(_center_size(gold_line_template % int(data.gold), loot_font_size))

		for it in data.items:
			if it == null:
				continue
			var title: String = str(it.title) if ("title" in it) else "предмет"
			lines.append(_center_size(item_line_template % title, loot_font_size))

	dlg.call("start_dialogue", lines, portrait)


func _show_already_opened_message() -> void:
	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		return

	var lines: Array[String] = []
	lines.append(_center_size_bold(already_opened_header, header_font_size))
	dlg.call("start_dialogue", lines, portrait)


func _find_dialogue_ui() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var dlg: Node = scene.find_child("DialogueUI", true, false)
		if dlg != null:
			return dlg
	return get_tree().root.find_child("DialogueUI", true, false)


func _update_sprite() -> void:
	if spr == null:
		return

	if opened and opened_texture != null:
		spr.texture = opened_texture
	elif closed_texture != null:
		spr.texture = closed_texture


func _disable_hit_area() -> void:
	if hit_area == null:
		return
	hit_area.monitoring = false
	hit_area.monitorable = false


func _center_size(text: String, px: int) -> String:
	if px <= 0:
		return "[center]%s[/center]" % text
	return "[center][font_size=%d]%s[/font_size][/center]" % [px, text]


func _center_size_bold(text: String, px: int) -> String:
	if px <= 0:
		return "[center][b]%s[/b][/center]" % text
	return "[center][font_size=%d][b]%s[/b][/font_size][/center]" % [px, text]
