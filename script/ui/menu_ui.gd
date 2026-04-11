extends CanvasLayer

@onready var ui_root: Node = $UiRoot
@onready var menu_root: Control = ui_root.get_node_or_null("MenuRoot")
@onready var inventory_screen: Node = ui_root.get_node_or_null("InventoryScreen")
@onready var equip_screen: Node = ui_root.get_node_or_null("EquipScreen")

@onready var panel_inventory: Control = menu_root.get_node_or_null("InventoryPanel") if menu_root else null
@onready var panel_magic: Control = menu_root.get_node_or_null("MagicPanel") if menu_root else null
@onready var panel_equip: Control = menu_root.get_node_or_null("EquipPanel") if menu_root else null
@onready var panel_status: Control = menu_root.get_node_or_null("StatusPanel") if menu_root else null

var panels: Array[Control] = []
var selected_index := 0
var is_open := false
var selection_frame: Panel

var _pending_hero_idx: int = -1
var _pending_slot: ItemData.EquipSlot = ItemData.EquipSlot.NONE


func _ready() -> void:
	if menu_root == null:
		push_error("menu_ui.gd: UiRoot/MenuRoot not found. Check node paths.")
		return
	if inventory_screen == null:
		push_error("menu_ui.gd: UiRoot/InventoryScreen not found. Check node paths.")
		return

	panels = [panel_inventory, panel_magic, panel_equip, panel_status]
	menu_root.visible = false
	inventory_screen.visible = false
	if equip_screen:
		equip_screen.visible = false

	if equip_screen:
		if equip_screen.has_signal("request_equip_pick") and not equip_screen.request_equip_pick.is_connected(_on_request_equip_pick):
			equip_screen.request_equip_pick.connect(_on_request_equip_pick)

		if equip_screen.has_signal("request_unequip") and not equip_screen.request_unequip.is_connected(_on_request_unequip):
			equip_screen.request_unequip.connect(_on_request_unequip)

		if equip_screen.has_signal("closed") and not equip_screen.closed.is_connected(_on_equip_closed):
			equip_screen.closed.connect(_on_equip_closed)

	if inventory_screen.has_signal("equip_item_selected") and not inventory_screen.equip_item_selected.is_connected(_on_equip_item_selected):
		inventory_screen.equip_item_selected.connect(_on_equip_item_selected)
	if inventory_screen.has_signal("equip_selection_canceled") and not inventory_screen.equip_selection_canceled.is_connected(_on_equip_pick_canceled):
		inventory_screen.equip_selection_canceled.connect(_on_equip_pick_canceled)

	is_open = false
	selected_index = 0
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

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
	if equip_screen and equip_screen.visible:
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
		0: _open_inventory()
		1: print("Magic selected")
		2: _open_equip()
		3: print("Status selected")


func _open_inventory() -> void:
	_close_menu()
	inventory_screen.visible = true
	if inventory_screen.has_method("open"):
		inventory_screen.call("open")


func _open_equip() -> void:
	_close_menu()
	if equip_screen == null:
		return
	equip_screen.visible = true
	if equip_screen.has_method("open"):
		equip_screen.call("open")


func _on_request_equip_pick(hero_idx: int, slot: ItemData.EquipSlot) -> void:
	_pending_hero_idx = hero_idx
	_pending_slot = slot

	equip_screen.visible = false
	inventory_screen.visible = true

	if inventory_screen.has_method("open_equip_selection"):
		inventory_screen.call("open_equip_selection", slot, 0)
	else:
		push_error("InventoryScreen: open_equip_selection() not found.")


func _on_equip_item_selected(item: ItemData) -> void:
	inventory_screen.visible = false

	if equip_screen and equip_screen.has_method("set_equipped_item"):
		equip_screen.call("set_equipped_item", _pending_hero_idx, _pending_slot, item)

	equip_screen.visible = true
	_pending_hero_idx = -1
	_pending_slot = ItemData.EquipSlot.NONE


func _on_equip_pick_canceled() -> void:
	inventory_screen.visible = false
	equip_screen.visible = true
	_pending_hero_idx = -1
	_pending_slot = ItemData.EquipSlot.NONE


func _on_request_unequip(hero_idx: int, slot: ItemData.EquipSlot, item: ItemData) -> void:
	if inventory_screen and inventory_screen.has_method("add_item_to_inventory"):
		inventory_screen.call("add_item_to_inventory", item)
	else:
		push_warning("InventoryScreen missing add_item_to_inventory().")


func _on_equip_closed() -> void:
	equip_screen.visible = false
	_open_menu()


func _hide_inventory() -> void:
	if inventory_screen.has_method("close"):
		inventory_screen.call("close")
	is_open = false
	menu_root.visible = false


func _update_selection_frame() -> void:
	if not is_open:
		return
	var p := panels[selected_index]
	if p == null:
		return
	selection_frame.position = p.position
	selection_frame.size = p.size
	selection_frame.visible = true


func is_ui_blocking() -> bool:
	return (menu_root and menu_root.visible) or (inventory_screen and inventory_screen.visible) or (equip_screen and equip_screen.visible)
