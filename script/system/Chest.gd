extends Node2D
# Chest script (v3) - works with your NO-MOUSE / Player-driven interaction.
# Player should call chest.interact() when facing it and pressing E (same as SecretWall/NPC).
# Loot delivery uses Inventory_Service autoload.

@export var data: ChestData

@export_group("Visual")
@export var closed_texture: Texture2D
@export var opened_texture: Texture2D

@export_group("Behaviour")
@export var one_time: bool = true
@export var opened: bool = false

@export_group("Dialogue Style")
@export var header_font_size: int = 36
@export var loot_font_size: int = 36
@export var gold_line_template: String = "Вы нашли %d золота."
@export var item_line_template: String = "Вы нашли: %s"
@export var opened_header: String = "Вы открыли сундук."

@onready var spr: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	_update_sprite()

# Called by Player.gd (like SecretWall)
func interact(_player: Node = null) -> void:
	if opened and (one_time or (data != null and data.one_time)):
		return
	_open()

func _open() -> void:
	opened = true
	_update_sprite()
	_give_loot()
	_show_loot_message()
	# Clear contents if one-time
	if data != null and (one_time or data.one_time):
		data.items.clear()
		data.gold = 0

func _give_loot() -> void:
	if data == null:
		return
	# Items
	if data.items != null and not data.items.is_empty():
		Inventory_Service.add_items(data.items)
	# Gold
	if int(data.gold) != 0:
		Inventory_Service.add_gold(int(data.gold))

func _show_loot_message() -> void:
	var dlg: Node = get_tree().current_scene.find_child("DialogueUI", true, false)
	if dlg == null or not dlg.has_method("start_dialogue"):
		return

	var lines: Array[String] = []
	lines.append("[center][b]%s[/b][/center]" % opened_header)

	if data != null:
		if int(data.gold) != 0:
			lines.append("[center]%s[/center]" % (gold_line_template % int(data.gold)))
		for it in data.items:
			if it == null:
				continue
			var title: String = str(it.title) if ("title" in it) else "предмет"
			lines.append("[center]%s[/center]" % (item_line_template % title))

	dlg.call("start_dialogue", lines, null)

func _update_sprite() -> void:
	if spr == null:
		return
	if opened and opened_texture != null:
		spr.texture = opened_texture
	elif closed_texture != null:
		spr.texture = closed_texture
