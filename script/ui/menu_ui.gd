extends CanvasLayer

@onready var menu_root: Control = $UiRoot/MenuRoot
@onready var panel_inventory: Control = $UiRoot/MenuRoot/InventoryPanel
@onready var panel_magic: Control = $UiRoot/MenuRoot/MagicPanel
@onready var panel_equip: Control = $UiRoot/MenuRoot/EquipPanel
@onready var panel_status: Control = $UiRoot/MenuRoot/StatusPanel

@onready var inventory_screen = $UiRoot/InventoryScreen
# (опционально) если Player называется не "Player" и не в группе "player" — можно один раз указать путь в инспекторе
@export var player_node_path: NodePath

var panels: Array[Control] = []
var selected_index := 0
var is_open := false
var selection_frame: Panel

var _player: Node = null
var _player_saved := false
var _prev_process := true
var _prev_physics := true
var _prev_input := true
var _prev_unhandled := true
var _prev_unhandled_key := true

func _ready() -> void:
	panels = [panel_inventory, panel_magic, panel_equip, panel_status]
	menu_root.visible = false
	inventory_screen.visible = false
	is_open = false
	selected_index = 0
	# Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Создаём рамку как Panel (самый надёжный)
	selection_frame = Panel.new()
	selection_frame.name = "SelectionFrame"
	selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 1)

	selection_frame.add_theme_stylebox_override("panel", sb)
	menu_root.add_child(selection_frame)
	_update_selection_frame()

	# Чтобы при закрытии инвентаря (Esc/Tab внутри inventory_screen.gd) мы сразу возвращали управление игроку
	if inventory_screen and not inventory_screen.closed.is_connected(_on_inventory_closed):
		inventory_screen.closed.connect(_on_inventory_closed)

	_cache_player()
	_refresh_player_lock()

func _unhandled_input(event: InputEvent) -> void:
	# Tab открывает/закрывает меню. Если открыт инвентарь — закрываем инвентарь.
	if event.is_action_pressed("menu"):
		if inventory_screen.visible:
			_hide_inventory()
		else:
			_toggle_menu()
		get_viewport().set_input_as_handled()
		return

	if not is_open:
		return

	if event.is_action_pressed("move_up"):
		selected_index = 0
		_update_selection_frame()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		selected_index = 1
		_update_selection_frame()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		selected_index = 2
		_update_selection_frame()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		selected_index = 3
		_update_selection_frame()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action"):
		_activate_selected()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()

func _toggle_menu() -> void:
	if is_open:
		_close_menu()
	else:
		_open_menu()

func _open_menu() -> void:
	is_open = true
	menu_root.visible = true
	_update_selection_frame()
	_refresh_player_lock()

func _close_menu() -> void:
	is_open = false
	menu_root.visible = false
	_refresh_player_lock()

func _activate_selected() -> void:
	match selected_index:
		0:
			_open_inventory()
		1:
			print("Magic selected")
		2:
			print("Equip selected")
		3:
			print("Status selected")

func _open_inventory() -> void:
	# ВАЖНО: сначала открываем инвентарь (он становится visible),
	# потом закрываем меню — чтобы блокировка игрока не “мигала”.
	inventory_screen.open()
	_close_menu()
	_refresh_player_lock()

func _hide_inventory() -> void:
	# Сначала показываем меню (чтобы блокировка сразу оставалась),
	# затем закрываем инвентарь.
	_open_menu()
	inventory_screen.close()
	# close() сэмитит closed -> там тоже вызовется _refresh_player_lock()

func _on_inventory_closed() -> void:
	_refresh_player_lock()

func _update_selection_frame() -> void:
	if not is_open:
		return

	var p := panels[selected_index]
	var rect := p.get_rect()
	var pos := p.position
	selection_frame.position = pos
	selection_frame.size = rect.size
	selection_frame.visible = true

# ------------------------------
# Централизованный "UI блокирует управление"
# ------------------------------

func _is_ui_blocking() -> bool:
	return menu_root.visible or inventory_screen.visible

func _refresh_player_lock() -> void:
	_set_player_frozen(_is_ui_blocking())

func _cache_player() -> void:
	if player_node_path != NodePath():
		_player = get_node_or_null(player_node_path)
		if is_instance_valid(_player):
			return

	# вариант на будущее (если захочешь): добавь Player в группу "player" в инспекторе
	var by_group := get_tree().get_first_node_in_group("player")
	if by_group:
		_player = by_group
		return

	# текущий вариант без правок Player: ищем ноду с именем "Player" в текущей сцене
	if get_tree().current_scene:
		_player = get_tree().current_scene.find_child("Player", true, false)

func _set_player_frozen(frozen: bool) -> void:
	if not is_instance_valid(_player):
		_cache_player()

	if not is_instance_valid(_player):
		return

	if frozen:
		if not _player_saved:
			_prev_process = _player.is_processing()
			_prev_physics = _player.is_physics_processing()
			_prev_input = _player.is_processing_input()
			_prev_unhandled = _player.is_processing_unhandled_input()
			_prev_unhandled_key = _player.is_processing_unhandled_key_input()
			_player_saved = true

		_player.set_process(false)
		_player.set_physics_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)
		_player.set_process_unhandled_key_input(false)
	else:
		if not _player_saved:
			return

		_player.set_process(_prev_process)
		_player.set_physics_process(_prev_physics)
		_player.set_process_input(_prev_input)
		_player.set_process_unhandled_input(_prev_unhandled)
		_player.set_process_unhandled_key_input(_prev_unhandled_key)
		_player_saved = false
