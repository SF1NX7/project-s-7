extends Node2D
# SecretWall script (v3) - uses Inventory_Service autoload and keeps centered/bold header.
# Player should call interact() (or interact(player)) as before.

@export var item_data: ItemData
@export var one_time: bool = true
@export var opened: bool = false

@export_group("Dialogue")
@export var opened_text: String = "Вы нашли тайник."
@export var item_line_template: String = "Вы нашли: %s"

func interact(_player: Node = null) -> void:
	if opened and one_time:
		return
	opened = true

	if item_data != null:
		Inventory_Service.add_item(item_data)

	_show_message()

	if one_time:
		item_data = null

func _show_message() -> void:
	var dlg: Node = get_tree().current_scene.find_child("DialogueUI", true, false)
	if dlg == null or not dlg.has_method("start_dialogue"):
		return

	var lines: Array[String] = []
	# Center + bold so it matches your dialogue style/font sizing better.
	lines.append("[center][b]%s[/b][/center]" % opened_text)

	if item_data != null:
		lines.append("[center]%s[/center]" % (item_line_template % str(item_data.title)))

	dlg.call("start_dialogue", lines, null)
