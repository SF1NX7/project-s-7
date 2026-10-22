extends Node2D
class_name QuestDeliveryNPC

# QuestDeliveryNPC
# Put this script on an NPC that gives a simple "bring item" quest.
#
# Flow:
# 1) If quest flag is done -> finished dialogue.
# 2) If player does not have required item -> request dialogue.
# 3) If player has required item -> offer handover prompt.
# 4) Yes -> remove item, give rewards, set done flag.
# 5) No -> refusal dialogue.
#
# Prompt controls:
# Left/Right or A/D = choose Yes/No
# E = confirm
# Esc/Menu = cancel as No

@export_group("Quest")
@export var quest_done_flag: String = "quest_house_potion_done"
@export var required_item_id: String = "hp_small"
@export var required_item_name: String = "Малое зелье здоровья"

@export_group("Rewards")
@export var reward_items: Array[ItemData] = []
@export var reward_gold: int = 100
@export var completion_sfx: AudioStream

@export_group("Dialogue")
@export var portrait: Texture2D
@export_multiline var request_lines: Array[String] = [
	"Мне необходимо малое зелье здоровья.",
	"Если найдёшь его, пожалуйста, принеси мне."
]
@export_multiline var has_item_lines: Array[String] = [
	"О, у тебя есть малое зелье здоровья.",
	"Ты отдашь его мне?"
]
@export_multiline var refuse_lines: Array[String] = [
	"Жадина..."
]
@export_multiline var thanks_lines: Array[String] = [
	"Спасибо! Ты очень помог.",
	"Вот тебе пончик и немного золота."
]
@export_multiline var completed_lines: Array[String] = [
	"Спасибо ещё раз. Благодаря тебе мне уже намного лучше."
]

@export_group("Prompt")
@export var prompt_title: String = "Передать предмет?"
@export var prompt_yes_text: String = "Да"
@export var prompt_no_text: String = "Нет"
@export var prompt_font_size: int = 32
@export var prompt_panel_size: Vector2 = Vector2(520, 190)
@export var prompt_dim_color: Color = Color(0, 0, 0, 0.35)
@export var prompt_panel_color: Color = Color(0.12, 0.08, 0.06, 0.97)
@export var prompt_selected_color: Color = Color(1.0, 0.82, 0.35, 1.0)
@export var prompt_normal_color: Color = Color(0.7, 0.7, 0.7, 1.0)

@export_group("Reward Text")
@export var reward_header: String = "Получено:"
@export var reward_gold_line_template: String = "%d золота"
@export var reward_item_separator: String = ", "

@export_group("Debug")
@export var print_debug: bool = true

var _busy: bool = false
var _prompt_layer: CanvasLayer = null
var _prompt_selected_yes: bool = true
var _prompt_done: bool = false
var _prompt_result: bool = false
var _yes_label: Label = null
var _no_label: Label = null
var _prompt_active: bool = false


func interact(_player: Node = null) -> void:
	if _busy:
		return

	_busy = true
	await _run_quest_dialogue()
	_busy = false


func _run_quest_dialogue() -> void:
	if _is_quest_done():
		await _say(completed_lines)
		return

	if not _has_required_item():
		await _say(request_lines)
		return

	await _say(has_item_lines)

	var accepted: bool = await _ask_transfer_prompt()
	if not accepted:
		await _say(refuse_lines)
		return

	if not _remove_required_item():
		await _say(["Похоже, предмет куда-то исчез."])
		return

	_give_rewards()
	_set_quest_done()

	var final_lines: Array[String] = []
	for line in thanks_lines:
		var text: String = str(line).strip_edges()
		if text != "":
			final_lines.append(text)

	var reward_text: String = _build_reward_text()
	if reward_text.strip_edges() != "":
		final_lines.append(reward_text)

	await _say(final_lines)


func _is_quest_done() -> bool:
	var gs: Node = _get_game_state()
	if gs != null and gs.has_method("get_flag"):
		return bool(gs.call("get_flag", quest_done_flag, false))
	if gs != null and ("flags" in gs):
		return bool(gs.flags.get(quest_done_flag, false))
	return false


func _set_quest_done() -> void:
	var gs: Node = _get_game_state()
	if gs != null and gs.has_method("set_flag"):
		gs.call("set_flag", quest_done_flag, true)
	elif gs != null and ("flags" in gs):
		gs.flags[quest_done_flag] = true

	if print_debug:
		print("QuestDeliveryNPC: quest done -> ", quest_done_flag)


func _has_required_item() -> bool:
	var id_text: String = required_item_id.strip_edges()
	if id_text == "":
		return false

	var service: Node = _get_inventory_service()
	if service != null and service.has_method("has_item_id"):
		if bool(service.call("has_item_id", id_text)):
			return true

	var inv: Node = _find_inventory_screen()
	if inv != null:
		if inv.has_method("has_item"):
			return bool(inv.call("has_item", id_text))

		if "starting_items" in inv:
			var items: Array = inv.starting_items
			for item in items:
				if _item_matches_id(item, id_text):
					return true

	return false


func _remove_required_item() -> bool:
	var id_text: String = required_item_id.strip_edges()
	if id_text == "":
		return false

	var inv: Node = _find_inventory_screen()
	if inv != null and ("starting_items" in inv):
		var items: Array = inv.starting_items

		for i in range(items.size()):
			if _item_matches_id(items[i], id_text):
				items.remove_at(i)
				inv.starting_items = items
				if inv.has_method("_apply_filter"):
					inv.call("_apply_filter")
				if print_debug:
					print("QuestDeliveryNPC: removed required item -> ", id_text)
				return true

	var service: Node = _get_inventory_service()
	if service != null and ("_queued_items" in service):
		var queued: Array = service._queued_items

		for i in range(queued.size()):
			if _item_matches_id(queued[i], id_text):
				queued.remove_at(i)
				service._queued_items = queued
				if service.has_signal("inventory_changed"):
					service.emit_signal("inventory_changed")
				if print_debug:
					print("QuestDeliveryNPC: removed queued required item -> ", id_text)
				return true

	return false


func _give_rewards() -> void:
	var service: Node = _get_inventory_service()

	for item in reward_items:
		if item == null:
			continue

		if service != null and service.has_method("add_item"):
			service.call("add_item", item)
		else:
			var inv: Node = _find_inventory_screen()
			if inv != null and inv.has_method("add_item_to_inventory"):
				inv.call("add_item_to_inventory", item)

	if reward_gold != 0:
		if service != null and service.has_method("add_gold"):
			service.call("add_gold", reward_gold)
		else:
			var inv2: Node = _find_inventory_screen()
			if inv2 != null and inv2.has_method("add_gold"):
				inv2.call("add_gold", reward_gold)

	if completion_sfx != null:
		var player := AudioStreamPlayer.new()
		player.stream = completion_sfx
		get_tree().current_scene.add_child(player)
		player.finished.connect(player.queue_free)
		player.play()


func _build_reward_text() -> String:
	var parts: Array[String] = []

	for item in reward_items:
		if item == null:
			continue
		var title: String = item.title if ("title" in item) else "предмет"
		parts.append(title)

	if reward_gold != 0:
		parts.append(reward_gold_line_template % reward_gold)

	if parts.is_empty():
		return ""

	return "[center][b]%s[/b]\n%s[/center]" % [
		reward_header,
		reward_item_separator.join(parts)
	]


func _item_matches_id(item, id_text: String) -> bool:
	if item == null:
		return false

	var want: String = id_text.strip_edges()
	if want == "":
		return false

	if "id" in item:
		if str(item.id).strip_edges() == want:
			return true

	if "resource_path" in item:
		var rp: String = str(item.resource_path)
		if rp != "" and rp.get_file().get_basename() == want:
			return true

	if "title" in item:
		if str(item.title).strip_edges() == want:
			return true

	return false


func _say(lines: Array[String]) -> void:
	var clean: Array[String] = []
	for line in lines:
		var text: String = str(line).strip_edges()
		if text != "":
			clean.append(text)

	if clean.is_empty():
		return

	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		push_warning("QuestDeliveryNPC: DialogueUI with start_dialogue() was not found.")
		return

	dlg.call("start_dialogue", clean, portrait)

	if dlg.has_signal("finished"):
		await dlg.finished
	else:
		while "is_active" in dlg and dlg.is_active:
			await get_tree().process_frame


func _ask_transfer_prompt() -> bool:
	_prompt_selected_yes = true
	_prompt_done = false
	_prompt_result = false
	_prompt_active = true

	_create_prompt()
	_update_prompt_visuals()

	while not _prompt_done:
		await get_tree().process_frame

	_destroy_prompt()
	_prompt_active = false
	return _prompt_result


func _unhandled_input(event: InputEvent) -> void:
	if not _prompt_active:
		return

	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_prompt_selected_yes = true
		_update_prompt_visuals()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_prompt_selected_yes = false
		_update_prompt_visuals()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		_prompt_result = _prompt_selected_yes
		_prompt_done = true
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		_prompt_result = false
		_prompt_done = true
		get_viewport().set_input_as_handled()
		return


func _create_prompt() -> void:
	_destroy_prompt()

	_prompt_layer = CanvasLayer.new()
	_prompt_layer.name = "QuestTransferPrompt"
	_prompt_layer.layer = 100
	get_tree().current_scene.add_child(_prompt_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt_layer.add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = prompt_dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = prompt_panel_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -prompt_panel_size.x * 0.5
	panel.offset_top = -prompt_panel_size.y * 0.5
	panel.offset_right = prompt_panel_size.x * 0.5
	panel.offset_bottom = prompt_panel_size.y * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = prompt_panel_color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "%s\n%s" % [prompt_title, required_item_name]
	title.add_theme_font_size_override("font_size", prompt_font_size)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 80)
	box.add_child(row)

	_yes_label = Label.new()
	_yes_label.text = prompt_yes_text
	_yes_label.add_theme_font_size_override("font_size", prompt_font_size)
	row.add_child(_yes_label)

	_no_label = Label.new()
	_no_label.text = prompt_no_text
	_no_label.add_theme_font_size_override("font_size", prompt_font_size)
	row.add_child(_no_label)


func _update_prompt_visuals() -> void:
	if _yes_label != null:
		_yes_label.text = "◀ %s ▶" % prompt_yes_text if _prompt_selected_yes else prompt_yes_text
		_yes_label.self_modulate = prompt_selected_color if _prompt_selected_yes else prompt_normal_color

	if _no_label != null:
		_no_label.text = "◀ %s ▶" % prompt_no_text if not _prompt_selected_yes else prompt_no_text
		_no_label.self_modulate = prompt_selected_color if not _prompt_selected_yes else prompt_normal_color


func _destroy_prompt() -> void:
	if _prompt_layer != null:
		_prompt_layer.queue_free()
	_prompt_layer = null
	_yes_label = null
	_no_label = null


func _find_dialogue_ui() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var dlg: Node = scene.find_child("DialogueUI", true, false)
		if dlg != null:
			return dlg
	return get_tree().root.find_child("DialogueUI", true, false)


func _find_inventory_screen() -> Node:
	var inv: Node = get_tree().get_first_node_in_group("inventory_screen")
	if inv != null:
		return inv

	var scene: Node = get_tree().current_scene
	if scene != null:
		var found: Node = scene.find_child("InventoryScreen", true, false)
		if found != null:
			return found

	return get_tree().root.find_child("InventoryScreen", true, false)


func _get_inventory_service() -> Node:
	var service: Node = get_node_or_null("/root/Inventory_Service")
	if service != null:
		return service

	service = get_node_or_null("/root/InventoryService")
	if service != null:
		return service

	return null


func _get_game_state() -> Node:
	var gs: Node = get_tree().get_first_node_in_group("game_state")
	if gs != null:
		return gs

	gs = get_node_or_null("/root/GameState")
	if gs != null:
		return gs

	return get_tree().root.find_child("GameState", true, false)
