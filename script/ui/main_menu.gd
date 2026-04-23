extends CanvasLayer

@onready var ui_root: Node = $UiRoot
@onready var menu_root: Control = ui_root.get_node_or_null("MenuRoot")

@onready var inventory_screen: Node = ui_root.get_node_or_null("InventoryScreen")
@onready var equip_screen: Node = ui_root.get_node_or_null("EquipScreen")
@onready var status_screen: Node = ui_root.get_node_or_null("StatusScreen")
@onready var magic_screen: Node = ui_root.get_node_or_null("MagicScreen")

@onready var panel_inventory: Control = menu_root.get_node_or_null("InventoryPanel") if menu_root else null
@onready var panel_magic: Control = menu_root.get_node_or_null("MagicPanel") if menu_root else null
@onready var panel_equip: Control = menu_root.get_node_or_null("EquipPanel") if menu_root else null
@onready var panel_status: Control = menu_root.get_node_or_null("StatusPanel") if menu_root else null

var panels: Array[Control] = []
var selected_index := 0
var is_open := false
var selection_frame: Panel

# Equip pick context
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
	if status_screen:
		status_screen.visible = false
	if magic_screen:
		magic_screen.visible = false

	# Equip connections
	if equip_screen:
		if equip_screen.has_signal("request_equip_pick") and not equip_screen.request_equip_pick.is_connected(_on_request_equip_pick):
			equip_screen.request_equip_pick.connect(_on_request_equip_pick)

		if equip_screen.has_signal("request_unequip") and not equip_screen.request_unequip.is_connected(_on_request_unequip):
			equip_screen.request_unequip.connect(_on_request_unequip)

		if equip_screen.has_signal("closed") and not equip_screen.closed.is_connected(_on_equip_closed):
			equip_screen.closed.connect(_on_equip_closed)

	# Status connection
	if status_screen and status_screen.has_signal("closed") and not status_screen.closed.is_connected(_on_status_closed):
		status_screen.closed.connect(_on_status_closed)

	# Magic connection
	if magic_screen and magic_screen.has_signal("closed") and not magic_screen.closed.is_connected(_on_magic_closed):
		magic_screen.closed.connect(_on_magic_closed)

	# Inventory picker result
	if inventory_screen.has_signal("equip_item_selected") and not inventory_screen.equip_item_selected.is_connected(_on_equip_item_selected):
		inventory_screen.equip_item_selected.connect(_on_equip_item_selected)
	if inventory_screen.has_signal("equip_selection_canceled") and not inventory_screen.equip_selection_canceled.is_connected(_on_equip_pick_canceled):
		inventory_screen.equip_selection_canceled.connect(_on_equip_pick_canceled)

	is_open = false
	selected_index = 0
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Selection frame (menu cursor)
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



	_update_crossmenu_visuals()
func _unhandled_input(event: InputEvent) -> void:
	# If another UI screen is open, let it handle Tab itself.
	if equip_screen and equip_screen.visible:
		return
	if inventory_screen and inventory_screen.visible:
		return
	if status_screen and status_screen.visible:
		return
	if magic_screen and magic_screen.visible:
		return

	if event.is_action_pressed("menu"):
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



	_update_crossmenu_visuals()
func _close_menu() -> void:
	is_open = false
	menu_root.visible = false



	_update_crossmenu_visuals()
func _activate_selected() -> void:
	match selected_index:
		0:
			_open_inventory()
		1:
			_open_magic()
		2:
			_open_equip()
		3:
			_open_status()


func _open_inventory() -> void:
	_close_menu()
	inventory_screen.visible = true
	if inventory_screen.has_method("open"):
		inventory_screen.call("open")


func _open_magic() -> void:
	_close_menu()
	if magic_screen == null:
		print("Magic selected (no MagicScreen node found)")
		return
	magic_screen.visible = true
	if magic_screen.has_method("open"):
		magic_screen.call("open")
	else:
		push_warning("MagicScreen missing open() method.")


func _open_equip() -> void:
	_close_menu()
	if equip_screen == null:
		print("Equip selected (no EquipScreen node found)")
		return
	equip_screen.visible = true
	if equip_screen.has_method("open"):
		equip_screen.call("open")


func _open_status() -> void:
	_close_menu()
	if status_screen == null:
		print("Status selected (no StatusScreen node found)")
		return
	status_screen.visible = true
	if status_screen.has_method("open"):
		status_screen.call("open")
	else:
		push_warning("StatusScreen missing open() method.")


# ---- Equip picking ----
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
	if equip_screen:
		equip_screen.visible = false
	_open_menu()


# ---- Status ----
func _on_status_closed() -> void:
	if status_screen:
		status_screen.visible = false
	_open_menu()


# ---- Magic ----
func _on_magic_closed() -> void:
	if magic_screen:
		magic_screen.visible = false
	_open_menu()


func _update_selection_frame() -> void:
	if not is_open:
		return
	var p := panels[selected_index]
	if p == null:
		return
	selection_frame.position = p.position
	selection_frame.size = p.size
	selection_frame.visible = true
	_update_crossmenu_visuals()


func is_ui_blocking() -> bool:
	return (menu_root and menu_root.visible) \
		or (inventory_screen and inventory_screen.visible) \
		or (equip_screen and equip_screen.visible) \
		or (status_screen and status_screen.visible) \
		or (magic_screen and magic_screen.visible)


# ---- Cross menu visuals (blink + dim) ----
func _find_bg(panel: Control) -> TextureRect:
	# Looks for child named "Bg"
	var n: Node = panel.find_child("Bg", true, false)
	if n != null and n is TextureRect:
		return n as TextureRect
	return null


func _update_crossmenu_visuals() -> void:
	# Dims inactive icons and enables blinking only on selected one.
	# Requires CrossMenuBlink script on the panel (or any node with set_selected(bool))
	for i in range(panels.size()):
		var p: Control = panels[i]
		if p == null:
			continue
		var is_sel: bool = (is_open and i == selected_index)

		# Drive blinking if the panel has CrossMenuBlink
		if p.has_method("set_selected"):
			p.call("set_selected", is_sel)

		# Dim only the background image (Bg), keep label readable
		var bg: TextureRect = _find_bg(p)
		if bg != null:
			bg.self_modulate = Color(1, 1, 1, 1) if is_sel else Color(0.55, 0.55, 0.55, 1)
