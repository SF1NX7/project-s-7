extends CanvasLayer

@onready var menu_root: Control = $UiRoot/MenuRoot

@onready var panel_inventory: Control = $UiRoot/MenuRoot/InventoryPanel
@onready var panel_magic: Control = $UiRoot/MenuRoot/MagicPanel
@onready var panel_equip: Control = $UiRoot/MenuRoot/EquipPanel
@onready var panel_status: Control = $UiRoot/MenuRoot/StatusPanel
@onready var inventory_screen: Control = $UiRoot/InventoryScreen
@onready var equip_screen: Control = $UiRoot/EquipScreen

var panels: Array[Control] = []
var selected_index := 0
var is_open := false
var selection_frame: Panel

func _ready() -> void:
	panels = [panel_inventory, panel_magic, panel_equip, panel_status]
	menu_root.visible = false
	inventory_screen.visible = false
	equip_screen.visible = false
	# Возврат из EquipScreen обратно в крест-меню
	if equip_screen and equip_screen.has_signal("closed") and not equip_screen.closed.is_connected(_on_equip_closed):
		equip_screen.closed.connect(_on_equip_closed)
	is_open = false
	selected_index = 0
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

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

func _unhandled_input(event: InputEvent) -> void:
	# Tab открывает/закрывает меню. Если открыт инвентарь — закрываем инвентарь.
	# Если открыт EquipScreen — пусть он сам обработает Tab (возврат на PartyBar/закрытие).
	if equip_screen.visible:
		return

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

func _close_menu() -> void:
	is_open = false
	menu_root.visible = false

func _activate_selected() -> void:
	match selected_index:
		0:
			_open_inventory()
		1:
			print("Magic selected")
		2:
			_open_equip()
		3:
			print("Status selected")

func _open_inventory() -> void:
	_close_menu()
	inventory_screen.visible = true
	inventory_screen.call("open")

func _open_equip() -> void:
	_close_menu()
	equip_screen.visible = true
	if equip_screen.has_method("open"):
		equip_screen.call("open")

func _on_equip_closed() -> void:
	# EquipScreen сообщил, что нужно вернуться в крест-меню
	equip_screen.visible = false
	_open_menu()

func _hide_inventory() -> void:
	# Close inventory and return to game.
	inventory_screen.call("close")
	is_open = false
	menu_root.visible = false

func _update_selection_frame() -> void:
	if not is_open:
		return

	var p := panels[selected_index]
	# Рамка должна совпасть с панелью (в координатах menu_root)
	var rect := p.get_rect()
	var pos := p.position
	selection_frame.position = pos
	selection_frame.size = rect.size
	selection_frame.visible = true
	
func is_ui_blocking() -> bool:
	# блокируем движение, если открыто крест-меню или любой экран
	return (menu_root and menu_root.visible) \
		or (inventory_screen and inventory_screen.visible) \
		or (equip_screen and equip_screen.visible)
