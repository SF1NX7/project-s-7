extends Control
class_name MainMenuSlotsCustom

# Attach to MainMenu root.
# Uses your exact node names from the screenshot.
# Controls: move_up/move_down + action. ui_up/ui_down/ui_accept also work.

@export_group("Scenes")
@export var start_scene_path: String = "res://scene/world/World_1.tscn"

@export_group("Visual")
@export var selected_color: Color = Color(1.0, 0.92, 0.60, 1.0)
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var disabled_color: Color = Color(0.45, 0.45, 0.45, 1.0)

@export_group("Text")
@export var empty_text: String = "Пустой слот"
@export var overwrite_text: String = "Есть сохранение. Будет перезаписано."
@export var no_save_text: String = "Нет сохранения."
@export var start_button_text: String = "Start New Game"
@export var load_button_text: String = "Load Game"
@export var hide_title_in_slot_menus: bool = true

@export_group("Slot Info Layout")
@export var info_margin_left: float = 14.0
@export var info_margin_top: float = 10.0
@export var info_margin_right: float = 14.0
@export var info_margin_bottom: float = 8.0
@export var info_extra_line_spacing: float = 2.0
@export var new_game_status_prefix: String = "Статус: "
@export var load_game_status_prefix: String = "Статус: "
@export var location_prefix: String = "Локация: "
@export var gold_prefix: String = "Золото: "
@export var time_prefix: String = "Дата: "

enum MenuMode {
	MAIN,
	NEW_GAME,
	LOAD_GAME
}

var _mode: MenuMode = MenuMode.MAIN
var _selected_index: int = 0

@onready var main_buttons: Control = $MainButtons
@onready var start_button: BaseButton = $MainButtons/StartButton
@onready var load_button: BaseButton = $MainButtons/LoadButton
@onready var title_node: CanvasItem = $Title

@onready var new_panel: Control = $NewGameSlotPanel
@onready var new_slot_1: BaseButton = $NewGameSlotPanel/Newslot1
@onready var new_slot_2: BaseButton = $NewGameSlotPanel/Newslot2
@onready var new_slot_3: BaseButton = $NewGameSlotPanel/Newslot3
@onready var new_info_1: Label = $NewGameSlotPanel/Slot1info
@onready var new_info_2: Label = $NewGameSlotPanel/Slot2info
@onready var new_info_3: Label = $NewGameSlotPanel/Slot3info
@onready var new_back_button: BaseButton = $NewGameSlotPanel/NewBackButton

@onready var load_panel: Control = $LoadGameSlotPanel
@onready var load_slot_1: BaseButton = $LoadGameSlotPanel/Loadslot1
@onready var load_slot_2: BaseButton = $LoadGameSlotPanel/Loadslot2
@onready var load_slot_3: BaseButton = $LoadGameSlotPanel/Loadslot3
@onready var load_info_1: Label = $LoadGameSlotPanel/Slot1info
@onready var load_info_2: Label = $LoadGameSlotPanel/Slot2info
@onready var load_info_3: Label = $LoadGameSlotPanel/Slot3info
@onready var load_back_button: BaseButton = $LoadGameSlotPanel/LoadBackButton

var _main_items: Array[BaseButton] = []
var _new_items: Array[BaseButton] = []
var _load_items: Array[BaseButton] = []


func _ready() -> void:
	_main_items = [start_button, load_button]
	_new_items = [new_slot_1, new_slot_2, new_slot_3, new_back_button]
	_load_items = [load_slot_1, load_slot_2, load_slot_3, load_back_button]

	_set_button_text(start_button, start_button_text)
	_set_button_text(load_button, load_button_text)
	_set_button_text(new_slot_1, "Слот 1")
	_set_button_text(new_slot_2, "Слот 2")
	_set_button_text(new_slot_3, "Слот 3")
	_set_button_text(new_back_button, "Назад")
	_set_button_text(load_slot_1, "Слот 1")
	_set_button_text(load_slot_2, "Слот 2")
	_set_button_text(load_slot_3, "Слот 3")
	_set_button_text(load_back_button, "Назад")

	_prepare_info_label(new_info_1)
	_prepare_info_label(new_info_2)
	_prepare_info_label(new_info_3)
	_prepare_info_label(load_info_1)
	_prepare_info_label(load_info_2)
	_prepare_info_label(load_info_3)

	start_button.pressed.connect(_open_new_game_slots)
	load_button.pressed.connect(_open_load_game_slots)

	new_slot_1.pressed.connect(func() -> void: _start_new_game_in_slot(1))
	new_slot_2.pressed.connect(func() -> void: _start_new_game_in_slot(2))
	new_slot_3.pressed.connect(func() -> void: _start_new_game_in_slot(3))
	new_back_button.pressed.connect(_back_to_main)

	load_slot_1.pressed.connect(func() -> void: _load_slot(1))
	load_slot_2.pressed.connect(func() -> void: _load_slot(2))
	load_slot_3.pressed.connect(func() -> void: _load_slot(3))
	load_back_button.pressed.connect(_back_to_main)

	_show_main()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_move_selection(-1)
		_accept_input_event()
		return

	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_move_selection(1)
		_accept_input_event()
		return

	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		_accept_input_event()
		_activate_current()
		return

	if event.is_action_pressed("ui_cancel"):
		if _mode != MenuMode.MAIN:
			_back_to_main()
			_accept_input_event()


func _show_main() -> void:
	_mode = MenuMode.MAIN
	_selected_index = 0
	main_buttons.visible = true
	new_panel.visible = false
	load_panel.visible = false
	_set_title_visible(true)
	_update_visuals()


func _open_new_game_slots() -> void:
	_mode = MenuMode.NEW_GAME
	_selected_index = 0
	main_buttons.visible = false
	new_panel.visible = true
	load_panel.visible = false
	_set_title_visible(false)
	_refresh_new_slot_info()
	_update_visuals()


func _open_load_game_slots() -> void:
	_mode = MenuMode.LOAD_GAME
	_selected_index = 0
	main_buttons.visible = false
	new_panel.visible = false
	load_panel.visible = true
	_set_title_visible(false)
	_refresh_load_slot_info()
	_update_visuals()


func _back_to_main() -> void:
	_show_main()


func _move_selection(delta: int) -> void:
	var items: Array[BaseButton] = _current_items()
	if items.is_empty():
		return

	var count: int = items.size()
	var next_index: int = _selected_index

	for _step in range(count):
		next_index = int(posmod(next_index + delta, count))
		var b: BaseButton = items[next_index]
		if b != null and not b.disabled:
			_selected_index = next_index
			_update_visuals()
			return


func _activate_current() -> void:
	var items: Array[BaseButton] = _current_items()
	if items.is_empty():
		return
	if _selected_index < 0 or _selected_index >= items.size():
		return

	var b: BaseButton = items[_selected_index]
	if b == null or b.disabled:
		return

	b.emit_signal("pressed")


func _current_items() -> Array[BaseButton]:
	match _mode:
		MenuMode.MAIN:
			return _main_items
		MenuMode.NEW_GAME:
			return _new_items
		MenuMode.LOAD_GAME:
			return _load_items
	return _main_items


func _update_visuals() -> void:
	_apply_group_visuals(_main_items, _mode == MenuMode.MAIN)
	_apply_group_visuals(_new_items, _mode == MenuMode.NEW_GAME)
	_apply_group_visuals(_load_items, _mode == MenuMode.LOAD_GAME)


func _apply_group_visuals(items: Array[BaseButton], active_group: bool) -> void:
	for i in range(items.size()):
		var b: BaseButton = items[i]
		if b == null:
			continue

		var is_selected: bool = active_group and i == _selected_index and not b.disabled

		if b.disabled:
			b.self_modulate = disabled_color
		elif is_selected:
			b.self_modulate = selected_color
			b.grab_focus()
		else:
			b.self_modulate = normal_color


func _refresh_new_slot_info() -> void:
	_set_new_slot_info(1, new_info_1)
	_set_new_slot_info(2, new_info_2)
	_set_new_slot_info(3, new_info_3)
	new_slot_1.disabled = false
	new_slot_2.disabled = false
	new_slot_3.disabled = false


func _refresh_load_slot_info() -> void:
	_set_load_slot_info(1, load_info_1, load_slot_1)
	_set_load_slot_info(2, load_info_2, load_slot_2)
	_set_load_slot_info(3, load_info_3, load_slot_3)

	var items: Array[BaseButton] = _current_items()
	for i in range(items.size()):
		var b: BaseButton = items[i]
		if b != null and not b.disabled:
			_selected_index = i
			break


func _set_new_slot_info(slot: int, label: Label) -> void:
	if label == null:
		return

	var exists: bool = Save_Manager.slot_exists(slot)
	if not exists:
		label.text = empty_text
		return

	var data: Dictionary = Save_Manager.peek_slot_data(slot)
	label.text = _compose_slot_info_text(data, new_game_status_prefix + overwrite_text)


func _set_load_slot_info(slot: int, label: Label, button: BaseButton) -> void:
	var exists: bool = Save_Manager.slot_exists(slot)

	if label != null:
		if exists:
			var data: Dictionary = Save_Manager.peek_slot_data(slot)
			label.text = _compose_slot_info_text(data, load_game_status_prefix + "Готово к загрузке")
		else:
			label.text = no_save_text

	if button != null:
		button.disabled = not exists


func _compose_slot_info_text(data: Dictionary, _status_text: String) -> String:
	var location_name: String = str(data.get("location_name", ""))
	if location_name.strip_edges() == "":
		var scene_path: String = str(data.get("scene_path", ""))
		location_name = scene_path.get_file().get_basename() if scene_path != "" else "Неизвестно"

	var gold_amount: int = int(data.get("gold", 0))
	var saved_time: int = int(data.get("saved_unix_time", 0))
	var time_text: String = Save_Manager._format_save_time(saved_time)

	# Exactly 3 lines: location, gold, save date.
	return "%s%s\n%s%d\n%s%s" % [
		location_prefix, location_name,
		gold_prefix, gold_amount,
		time_prefix, time_text
	]


func _prepare_info_label(label: Label) -> void:
	if label == null:
		return

	label.position.x += info_margin_left
	label.position.y += info_margin_top

	var new_size: Vector2 = label.size
	new_size.x = max(16.0, new_size.x - info_margin_left - info_margin_right)
	new_size.y = max(16.0, new_size.y - info_margin_top - info_margin_bottom)
	label.size = new_size

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_constant_override("line_spacing", int(info_extra_line_spacing))


func _start_new_game_in_slot(slot: int) -> void:
	Save_Manager.start_new_game(slot, start_scene_path)


func _load_slot(slot: int) -> void:
	if not Save_Manager.slot_exists(slot):
		return
	Save_Manager.load_slot_and_enter_game(slot)



func _accept_input_event() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _set_title_visible(show_main_title: bool) -> void:
	if title_node == null:
		return
	if hide_title_in_slot_menus:
		title_node.visible = show_main_title
	else:
		title_node.visible = true


func _set_button_text(button: BaseButton, value: String) -> void:
	if button == null:
		return
	if button is Button:
		var b: Button = button as Button
		b.text = value
