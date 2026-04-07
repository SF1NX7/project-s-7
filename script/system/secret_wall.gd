extends Node2D

@export var item_data: ItemData
@export var lines: Array[String] = [
	"Ты осматриваешь стену…",
	"В щели что-то есть! Ты находишь пончик."
]
@export var portrait: Texture2D

@onready var hit_area: Area2D = $HitArea

var _taken := false


func interact() -> void:
	# Player.gd already checks "in front" before calling interact().
	if _taken:
		return
	_taken = true

	# запретить повторную активацию
	hit_area.monitoring = false
	hit_area.monitorable = false

	# найти DialogueUI (желательно добавь ноду DialogueUI в группу 'dialogue_ui')
	var dlg := get_tree().get_first_node_in_group("dialogue_ui") as CanvasLayer
	if dlg == null:
		dlg = get_tree().root.find_child("DialogueUI", true, false) as CanvasLayer

	if dlg != null:
		# добавляем последнюю строку: "Вы подобрали: <название>" (название — цветом из ItemData.pickup_color)
		var dialog_lines := lines.duplicate()
		var pickup_line := "Вы подобрали предмет."
		if item_data != null and item_data.title != "":
			var col := "FFD54A" # default
			var c = item_data.get("pickup_color")
			if c is Color:
				col = (c as Color).to_html(false) # rrggbb
			pickup_line = "Вы подобрали: [color=#%s]%s[/color]" % [col, item_data.title]
			dialog_lines.append(pickup_line)
		else:
			dialog_lines.append(pickup_line)
		dlg.start_dialogue(dialog_lines, portrait)
		# ждём окончания (нужен signal finished в dialogue_ui.gd)
		await dlg.finished
	else:
		push_warning("DialogueUI not found. Giving item without dialogue.")

	_give_item()
	queue_free()


func _give_item() -> void:
	if item_data == null:
		push_warning("SecretWall: item_data is empty.")
		return

	var inv: Node = get_tree().get_first_node_in_group("inventory_screen")
	if inv == null:
		# запасной поиск по имени (если группа не сработала)
		inv = get_tree().root.find_child("InventoryScreen", true, false)

	if inv == null:
		push_warning("InventoryScreen not found (group 'inventory_screen' or node name).")
		return

	# Лучше через метод, если он есть (можно добавить позже)
	if inv.has_method("add_item"):
		inv.call("add_item", item_data)
		return

	# Фолбэк: напрямую в starting_items (как у тебя сейчас)
	var arr = inv.get("starting_items")
	if arr == null:
		push_warning("InventoryScreen has no 'starting_items' property.")
		return

	arr.append(item_data)
	inv.set("starting_items", arr)

	# если инвентарь открыт — обновить
	if bool(inv.get("visible")) and inv.has_method("_apply_filter"):
		inv.call("_apply_filter")
