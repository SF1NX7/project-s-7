extends Control
class_name InventoryScreen

signal closed
signal equip_item_selected(item: ItemData)
signal equip_selection_canceled

@export var slot_scene: PackedScene
@export var starting_items: Array[ItemData] = []
@export var default_item_count := 32

@onready var grid: GridContainer = $Root/InnerMargin/Content/left/Scroll/Grid
@onready var scroll: ScrollContainer = $Root/InnerMargin/Content/left/Scroll

@onready var preview_icon: TextureRect = $Root/InnerMargin/Content/Right/PreviewPanel/PreviewIcon
@onready var title_label: Label = $Root/InnerMargin/Content/Right/DescPanel/TitleLabel
@onready var desc_label: RichTextLabel = $Root/InnerMargin/Content/Right/DescPanel/DescLabel

@onready var btn_use: Button = $Root/InnerMargin/Content/left/Action/BtnUse
@onready var btn_drop: Button = $Root/InnerMargin/Content/left/Action/BtnDrop

@onready var tab_all: Control = $Root/InnerMargin/Content/left/tabs/TabAll
@onready var tab_wpn: Control = $Root/InnerMargin/Content/left/tabs/TabWeapon
@onready var tab_arm: Control = $Root/InnerMargin/Content/left/tabs/TabArmor
@onready var tab_pot: Control = $Root/InnerMargin/Content/left/tabs/TabPotion
@onready var tab_oth: Control = $Root/InnerMargin/Content/left/tabs/TabOther

var _tabs_nodes: Array[Control] = []

enum UiMode { GRID, ACTION }
var _mode: UiMode = UiMode.GRID
var _action_index := 0

var _tab := 0
var _focus_tabs := false

var slots: Array[Node] = []
var _slot_items: Array[ItemData] = []
var selected_slot := -1
var _slot_count := 0

enum ScreenMode { NORMAL, EQUIP_SELECT }
var _screen_mode: ScreenMode = ScreenMode.NORMAL
var _equip_filter_slot: ItemData.EquipSlot = ItemData.EquipSlot.NONE
var _equip_allowed_mask: int = 0


func _ready() -> void:
	if slot_scene == null:
		push_warning("InventoryScreen: Slot Scene is empty in Inspector!")

	if btn_use:
		btn_use.pressed.connect(_on_use_pressed)
	if btn_drop:
		btn_drop.pressed.connect(_on_drop_pressed)

	_tabs_nodes = [tab_all, tab_wpn, tab_arm, tab_pot, tab_oth]
	_update_tab_highlight()

	visible = false
	_exit_action_mode()


func open(item_count: int = -1) -> void:
	_screen_mode = ScreenMode.NORMAL
	_equip_filter_slot = ItemData.EquipSlot.NONE
	_equip_allowed_mask = 0

	visible = true
	_mode = UiMode.GRID
	_focus_tabs = false

	if btn_use: btn_use.visible = true
	if btn_drop: btn_drop.visible = true

	if item_count < 0:
		item_count = default_item_count

	_build_slots(item_count)
	_tab = 0
	_update_tab_highlight()
	_apply_filter()
	_select_slot(0)


func open_equip_selection(slot: ItemData.EquipSlot, allowed_profs_mask: int = 0, item_count: int = -1) -> void:
	_screen_mode = ScreenMode.EQUIP_SELECT
	_equip_filter_slot = slot
	_equip_allowed_mask = allowed_profs_mask

	visible = true
	_mode = UiMode.GRID
	_focus_tabs = false

	if btn_use: btn_use.visible = false
	if btn_drop: btn_drop.visible = false
	_exit_action_mode()

	if item_count < 0:
		item_count = default_item_count

	_build_slots(item_count)
	_tab = 0
	_update_tab_highlight()
	_apply_filter()
	_select_slot(0)


func close() -> void:
	visible = false
	_focus_tabs = false
	_exit_action_mode()
	selected_slot = -1

	if preview_icon: preview_icon.texture = null
	if title_label: title_label.text = ""
	if desc_label: desc_label.text = ""

	closed.emit()


func add_item_to_inventory(item: ItemData) -> void:
	if item == null:
		return
	starting_items.append(item)
	_apply_filter()


func _remove_one_instance_from_inventory(item: ItemData) -> void:
	# Remove only one matching instance, so duplicates (multiple same items) still work.
	if item == null:
		return
	var idx := starting_items.find(item)
	if idx != -1:
		starting_items.remove_at(idx)


func _build_slots(count: int) -> void:
	if slot_scene == null:
		push_error("InventoryScreen: slot_scene is EMPTY. Set it in Inspector.")
		return

	while slots.size() < count:
		var s := slot_scene.instantiate()
		grid.add_child(s)
		slots.append(s)

	_slot_count = count

	if _slot_items.size() < count:
		_slot_items.resize(count)

	for i in range(slots.size()):
		slots[i].visible = (i < count)


func _update_tab_highlight() -> void:
	for i in range(_tabs_nodes.size()):
		_tabs_nodes[i].self_modulate = Color(1, 1, 1, 1) if i == _tab else Color(0.6, 0.6, 0.6, 1)


func _passes_equip_filter(it: ItemData) -> bool:
	if _screen_mode != ScreenMode.EQUIP_SELECT:
		return true
	if it.equip_slot != _equip_filter_slot:
		return false
	if _equip_allowed_mask == 0:
		return true
	if it.required_profs_mask == 0:
		return true
	return (_equip_allowed_mask & it.required_profs_mask) != 0


func _apply_filter() -> void:
	var filtered: Array[ItemData] = []
	for it in starting_items:
		if it == null:
			continue
		if not _passes_equip_filter(it):
			continue
		if _tab == 0:
			filtered.append(it)
		else:
			var want := -1
			match _tab:
				1: want = 0
				2: want = 1
				3: want = 2
				4: want = 3
			if want == -1 or int(it.item_class) == want:
				filtered.append(it)

	if _slot_items.size() < _slot_count:
		_slot_items.resize(_slot_count)

	for i in range(_slot_count):
		var item := filtered[i] if i < filtered.size() else null
		_slot_items[i] = item
		if slots[i].has_method("set_icon"):
			slots[i].call("set_icon", item.icon if item != null else null)

	if selected_slot < 0:
		selected_slot = 0
	selected_slot = clampi(selected_slot, 0, max(_slot_count - 1, 0))
	_select_slot(selected_slot)


func _select_slot(i: int) -> void:
	if _slot_count <= 0:
		selected_slot = -1
		return

	selected_slot = clampi(i, 0, _slot_count - 1)

	for j in range(slots.size()):
		if slots[j].has_method("set_selected"):
			slots[j].call("set_selected", j == selected_slot and slots[j].visible)

	var item: ItemData = _slot_items[selected_slot] if selected_slot >= 0 and selected_slot < _slot_items.size() else null
	if preview_icon: preview_icon.texture = item.preview if item != null else null
	if item != null:
		if title_label: title_label.text = item.title
		if desc_label:
			desc_label.bbcode_enabled = true
			desc_label.text = item.description
		if btn_use: btn_use.disabled = false
		if btn_drop: btn_drop.disabled = false
	else:
		if title_label: title_label.text = ""
		if desc_label: desc_label.text = ""
		if btn_use: btn_use.disabled = true
		if btn_drop: btn_drop.disabled = true

	if selected_slot >= 0 and selected_slot < slots.size() and scroll:
		scroll.ensure_control_visible(slots[selected_slot])


func _set_action_selected(idx: int) -> void:
	_action_index = clampi(idx, 0, 1)
	if btn_use:
		btn_use.self_modulate = Color(1, 1, 1, 1) if _action_index == 0 else Color(0.5, 0.5, 0.5, 1)
	if btn_drop:
		btn_drop.self_modulate = Color(1, 1, 1, 1) if _action_index == 1 else Color(0.5, 0.5, 0.5, 1)


func _enter_action_mode() -> void:
	_mode = UiMode.ACTION
	_set_action_selected(0)


func _exit_action_mode() -> void:
	_mode = UiMode.GRID
	if btn_use: btn_use.self_modulate = Color(1, 1, 1, 1)
	if btn_drop: btn_drop.self_modulate = Color(1, 1, 1, 1)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		if _screen_mode == ScreenMode.EQUIP_SELECT:
			equip_selection_canceled.emit()
			close()
		else:
			if _mode == UiMode.ACTION:
				_exit_action_mode()
			elif _focus_tabs:
				_focus_tabs = false
			else:
				close()
		get_viewport().set_input_as_handled()
		return

	# EQUIP SELECT: E selects and REMOVES item from inventory list before emitting.
	if _screen_mode == ScreenMode.EQUIP_SELECT and event.is_action_pressed("action"):
		var item := _slot_items[selected_slot] if selected_slot >= 0 and selected_slot < _slot_items.size() else null
		if item != null:
			_remove_one_instance_from_inventory(item)
			_apply_filter() # refresh UI so item disappears immediately
			equip_item_selected.emit(item)
			close()
		get_viewport().set_input_as_handled()
		return

	# ACTION MODE
	if _mode == UiMode.ACTION:
		if event.is_action_pressed("move_up"):
			_set_action_selected(0)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_down"):
			_set_action_selected(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("action"):
			_exit_action_mode()
			get_viewport().set_input_as_handled()
			return
		return

	var cols: int = max(grid.columns, 1)
	var idx: int = max(selected_slot, 0)
	var row: int = idx / cols
	var col: int = idx % cols
	var moved := false

	if event.is_action_pressed("move_left") and col > 0:
		idx -= 1
		moved = true
	elif event.is_action_pressed("move_right") and col < cols - 1 and idx + 1 < _slot_count:
		idx += 1
		moved = true
	elif event.is_action_pressed("move_up"):
		if row > 0:
			idx -= cols
			moved = true
		else:
			_focus_tabs = true
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("move_down") and idx + cols < _slot_count:
		idx += cols
		moved = true

	if moved:
		_select_slot(idx)
		get_viewport().set_input_as_handled()
		return

	if _screen_mode == ScreenMode.NORMAL and event.is_action_pressed("action"):
		var item: ItemData = _slot_items[selected_slot] if selected_slot >= 0 and selected_slot < _slot_items.size() else null
		if item != null:
			_enter_action_mode()
			get_viewport().set_input_as_handled()


func _on_use_pressed() -> void:
	print("USE pressed on slot:", selected_slot)


func _on_drop_pressed() -> void:
	print("DROP pressed on slot:", selected_slot)
