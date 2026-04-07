extends Control
class_name InventoryScreen

# ---------- Data ----------
@export var slot_scene: PackedScene
@export var starting_items: Array[ItemData] = []
@export var default_item_count := 32

# ---------- Node refs (update paths if you renamed nodes) ----------
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

# ---------- UI state ----------
enum UiMode { GRID, ACTION }
var _mode: UiMode = UiMode.GRID
var _action_index := 0 # 0=Use, 1=Drop

# Tabs: 0=ALL,1=WPN,2=ARM,3=POT,4=OTH
var _tab := 0
var _focus_tabs := false
var _grid_col_when_tabs := 0

# Slots
var slots: Array[InventorySlot] = []
var _slot_items: Array = []
var selected_slot := -1
var _slot_count := 0


func _ready() -> void:
	# Defensive checks (avoid silent nulls)
	if slot_scene == null:
		push_warning("InventoryScreen: Slot Scene is empty in Inspector!")
	if btn_use == null or btn_drop == null:
		push_error("InventoryScreen: BtnUse/BtnDrop path is wrong.")
		return

	btn_use.pressed.connect(_on_use_pressed)
	btn_drop.pressed.connect(_on_drop_pressed)

	_tabs_nodes = [tab_all, tab_wpn, tab_arm, tab_pot, tab_oth]
	_update_tab_highlight()

	visible = false
	_exit_action_mode()


# ---------- Public ----------
func open(item_count: int = -1) -> void:
	visible = true
	_mode = UiMode.GRID
	_focus_tabs = false

	if item_count < 0:
		item_count = default_item_count

	_build_slots(item_count)

	# Always start on ALL tab
	_tab = 0
	_update_tab_highlight()

	_apply_filter()
	_select_slot(0)


func close() -> void:
	visible = false
	_focus_tabs = false
	_exit_action_mode()
	selected_slot = -1

	preview_icon.texture = null
	title_label.text = ""
	desc_label.text = ""


# ---------- Slots ----------
func _build_slots(count: int) -> void:
	if slot_scene == null:
		push_error("InventoryScreen: Slot Scene is EMPTY. Set it in Inspector.")
		return

	# Create missing slots once
	while slots.size() < count:
		var s := slot_scene.instantiate() as InventorySlot
		grid.add_child(s)
		slots.append(s)

	_slot_count = count

	# Keep slot-items array in sync
	if _slot_items.size() < count:
		_slot_items.resize(count)

	# Hide extras
	for i in range(slots.size()):
		slots[i].visible = (i < count)


# ---------- Tabs ----------
func _set_tab(t: int) -> void:
	_tab = clampi(t, 0, _tabs_nodes.size() - 1)
	_update_tab_highlight()
	_apply_filter()
	# While we are on the tabs, keep slot highlight hidden.
	if _focus_tabs:
		_clear_slot_highlight()


func _update_tab_highlight() -> void:
	for i in range(_tabs_nodes.size()):
		_tabs_nodes[i].self_modulate = Color(1, 1, 1, 1) if i == _tab else Color(0.6, 0.6, 0.6, 1)


func _apply_filter() -> void:
	# Gather filtered items
	var filtered: Array[ItemData] = []
	for it in starting_items:
		if it == null:
			continue

		if _tab == 0:
			filtered.append(it)
		else:
			# Map tab->ItemClass int (WPN=0, ARM=1, POT=2, OTH=3)
			var want := -1
			match _tab:
				1: want = 0
				2: want = 1
				3: want = 2
				4: want = 3

			if want == -1 or int(it.item_class) == want:
				filtered.append(it)

	# Fill grid left-to-right
	if _slot_items.size() < _slot_count:
		_slot_items.resize(_slot_count)
	for i in range(_slot_count):
		var item := filtered[i] if i < filtered.size() else null
		_slot_items[i] = item
		slots[i].set_icon(item.icon if item != null else null)

	# Keep selection valid
	if selected_slot < 0:
		selected_slot = 0
	selected_slot = clampi(selected_slot, 0, max(_slot_count - 1, 0))

	_select_slot(selected_slot)


# ---------- Selection ----------
func _select_slot(i: int) -> void:
	var total := _slot_count
	if total <= 0:
		selected_slot = -1
		preview_icon.texture = null
		title_label.text = ""
		desc_label.text = ""
		btn_use.disabled = true
		btn_drop.disabled = true
		return

	selected_slot = clampi(i, 0, total - 1)

	# Highlight slot
	for j in range(slots.size()):
		slots[j].set_selected(j == selected_slot and slots[j].visible)

	# Preview + text (simple: index in starting_items == slot index)
	var item: ItemData = _slot_items[selected_slot] if selected_slot >= 0 and selected_slot < _slot_items.size() else null
	preview_icon.texture = item.preview if item != null else null

	if item != null:
		title_label.text = item.title
		desc_label.text = item.description
		btn_use.disabled = false
		btn_drop.disabled = false
	else:
		title_label.text = ""
		desc_label.text = ""
		btn_use.disabled = true
		btn_drop.disabled = true

	# Auto-scroll to keep selection visible
	if selected_slot >= 0 and selected_slot < slots.size():
		scroll.ensure_control_visible(slots[selected_slot])



func _clear_slot_highlight() -> void:
	for j in range(slots.size()):
		slots[j].set_selected(false)

# ---------- Action mode (Use/Drop focus) ----------
func _set_action_selected(idx: int) -> void:
	_action_index = clampi(idx, 0, 1)
	btn_use.self_modulate = Color(1, 1, 1, 1) if _action_index == 0 else Color(0.5, 0.5, 0.5, 1)
	btn_drop.self_modulate = Color(1, 1, 1, 1) if _action_index == 1 else Color(0.5, 0.5, 0.5, 1)


func _enter_action_mode() -> void:
	_mode = UiMode.ACTION
	_set_action_selected(0)


func _exit_action_mode() -> void:
	_mode = UiMode.GRID
	btn_use.self_modulate = Color(1, 1, 1, 1)
	btn_drop.self_modulate = Color(1, 1, 1, 1)


# ---------- Input ----------
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Close / back
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		if _mode == UiMode.ACTION:
			_exit_action_mode()
		elif _focus_tabs:
			_focus_tabs = false
		else:
			close()
		get_viewport().set_input_as_handled()
		return

	# ACTION MODE: only W/S + E (action)
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
			if _action_index == 0:
				print("USE on slot:", selected_slot)
			else:
				print("DROP on slot:", selected_slot)
			_exit_action_mode()
			get_viewport().set_input_as_handled()
			return
		return

	# TABS FOCUS: A/D (left/right), S (down back to grid)
	if _focus_tabs:
		if event.is_action_pressed("move_left"):
			_set_tab(max(_tab - 1, 0))
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("move_right"):
			_set_tab(min(_tab + 1, _tabs_nodes.size() - 1))
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("move_down"):
			# Return to grid: always jump to first slot
			_focus_tabs = false
			_select_slot(0)
			get_viewport().set_input_as_handled()
			return

		return

	# GRID MODE
	if _slot_count <= 0:
		return

	var cols: int = max(grid.columns, 1)
	var idx: int = selected_slot
	if idx < 0:
		idx = 0

	var row: int = idx / cols
	var col: int = idx % cols
	var moved := false

	if event.is_action_pressed("move_left"):
		if col > 0:
			idx -= 1
			moved = true

	elif event.is_action_pressed("move_right"):
		if col < cols - 1 and idx + 1 < _slot_count:
			idx += 1
			moved = true

	elif event.is_action_pressed("move_up"):
		if row > 0:
			idx -= cols
			moved = true
		else:
			# Top row -> move focus to tabs
			_focus_tabs = true
			_grid_col_when_tabs = col
			_clear_slot_highlight()
			get_viewport().set_input_as_handled()
			return

	elif event.is_action_pressed("move_down"):
		if idx + cols < _slot_count:
			idx += cols
			moved = true

	if moved:
		_select_slot(idx)
		get_viewport().set_input_as_handled()
		return

	# E in grid -> enter action mode only if slot has item
	if event.is_action_pressed("action"):
		var item: ItemData = starting_items[selected_slot] if selected_slot < starting_items.size() else null
		if item != null:
			_enter_action_mode()
			get_viewport().set_input_as_handled()


# ---------- Buttons (later you will implement real logic) ----------
func _on_use_pressed() -> void:
	print("USE pressed on slot:", selected_slot)


func _on_drop_pressed() -> void:
	print("DROP pressed on slot:", selected_slot)
