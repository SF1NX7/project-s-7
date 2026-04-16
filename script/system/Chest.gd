extends Node2D
class_name Chest

@export_group("Data")
@export var data: ChestData
@export var opened: bool = false

@export_group("Visual")
@export var closed_texture: Texture2D
@export var opened_texture: Texture2D

@export_group("Dialogue")
# Base lines shown when opening (BBCode allowed).
@export var base_lines: Array[String] = ["Вы открыли сундук."]
@export var portrait: Texture2D

# Formatting (BBCode)
@export var header_font_size: int = 24
@export var loot_font_size: int = 20

@export var gold_line_template: String = "Вы нашли %d золота."
@export var item_line_template: String = "Вы нашли: %s"

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	_apply_visual()

func interact() -> void:
	# Player.gd already checks "in front" before calling interact().
	_try_open()

func _try_open() -> void:
	if opened:
		return

	opened = true
	_apply_visual()

	# prevent re-interaction via area (optional, matches SecretWall behavior)
	if hit_area != null:
		hit_area.monitoring = false
		hit_area.monitorable = false

	# Build dialogue lines with BBCode sizes
	var dialog_lines: Array[String] = []
	for l in base_lines:
		dialog_lines.append(_size_bbcode(l, header_font_size))

	if data != null:
		if data.gold > 0:
			dialog_lines.append(_size_bbcode(gold_line_template % data.gold, loot_font_size))
		for it in data.items:
			if it != null and it.title != "":
				dialog_lines.append(_size_bbcode(item_line_template % it.title, loot_font_size))

	# Show popup if DialogueUI exists
	var dlg := get_tree().get_first_node_in_group("dialogue_ui") as CanvasLayer
	if dlg == null:
		dlg = get_tree().root.find_child("DialogueUI", true, false) as CanvasLayer

	if dlg != null and dlg.has_method("start_dialogue"):
		dlg.start_dialogue(dialog_lines, portrait)
		if dlg.has_signal("finished"):
			await dlg.finished

	_give_loot()


func _size_bbcode(text: String, px: int) -> String:
	# RichTextLabel supports [font_size=..] in Godot 4.x.
	if px <= 0:
		return text
	return "[font_size=%d]%s[/font_size]" % [px, text]


func _apply_visual() -> void:
	if sprite == null:
		return
	if opened:
		if opened_texture != null:
			sprite.texture = opened_texture
	else:
		if closed_texture != null:
			sprite.texture = closed_texture


func _give_loot() -> void:
	if data == null:
		return

	# Give items to InventoryScreen (same approach as secret_wall.gd)
	var inv: Node = get_tree().get_first_node_in_group("inventory_screen")
	if inv == null:
		inv = get_tree().root.find_child("InventoryScreen", true, false)

	if inv != null and inv.has_method("add_item"):
		for it in data.items:
			if it != null:
				inv.add_item(it)

	# Gold: if you have a global gold store, switch this later.
	if inv != null and inv.has_method("add_gold") and data.gold > 0:
		inv.add_gold(data.gold)
	elif Global != null and Global.has_method("add_gold") and data.gold > 0:
		Global.add_gold(data.gold)

	# Clear contents if one-time
	if data.one_time:
		data.items.clear()
		data.gold = 0
