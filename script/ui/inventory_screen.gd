extends Control
class_name InventoryScreen

# v34: targeted item use with scrollable target overlay.
# Use potion -> choose party member in scrollable overlay -> apply effect -> consume item only after successful use.

# Robust node lookup: works whether this script is on InventoryScreen or on its child Root.
func _n(primary: String, fallback: String = "") -> Node:
	var n := get_node_or_null(primary)
	if n == null and fallback != "":
		n = get_node_or_null(fallback)
	return n


func _find_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for ch in root.get_children():
		var found := _find_by_name(ch, target_name)
		if found != null:
			return found
	return null

func _find_label_by_name(name: String) -> Label:
	var n := _find_by_name(self, name)
	return n as Label

func _update_gold_label() -> void:
	if gold_label == null:
		return
	gold_label.text = "Gold: %d" % gold_amount

func set_gold(amount: int) -> void:
	gold_amount = max(amount, 0)
	_update_gold_label()

func add_gold(amount: int) -> void:
	set_gold(gold_amount + amount)

signal closed
signal equip_item_selected(item: ItemData)
signal equip_selection_canceled

@export var slot_scene: PackedScene
@export var starting_items: Array[ItemData] = []
@export var default_item_count := 32

@export_group("Currency")
@export var gold_amount: int = 0

@export_group("Party")
@export var party: PartyData

@export_group("Target Overlay")
@export var target_overlay_title: String = "Кому использовать?"
@export var target_overlay_hint: String = "W/S — выбор    E — применить    Esc — назад"
@export var target_overlay_item_prefix: String = "Предмет:"
@export var target_overlay_panel_size: Vector2 = Vector2(520, 300)
@export var target_overlay_portrait_size: Vector2 = Vector2(64, 64)
@export var target_overlay_row_height: float = 74.0
@export var target_overlay_max_visible_rows: int = 4
@export var target_overlay_dim_color: Color = Color(0, 0, 0, 0.45)
@export var target_overlay_panel_color: Color = Color(0.12, 0.08, 0.06, 0.96)
@export var target_overlay_selected_color: Color = Color(0.95, 0.78, 0.42, 0.35)
@export var target_overlay_normal_color: Color = Color(1, 1, 1, 0.08)

@onready var grid: Control = _n("Root/Content/left/Scroll/Grid", "Content/left/Scroll/Grid") as Control
@onready var scroll: Control = _n("Root/Content/left/Scroll", "Content/left/Scroll") as Control

@onready var preview_icon: TextureRect = _n("Root/Content/Right/PreviewPanel/PreviewIcon", "Content/Right/PreviewPanel/PreviewIcon") as TextureRect
@onready var gold_label: Label = _n("Root/GoldLabel", "GoldLabel") as Label
@onready var title_label: Label = _n("Root/Content/Right/DescPanel/TitleLabel", "Content/Right/DescPanel/TitleLabel") as Label
@onready var desc_label: RichTextLabel = _n("Root/Content/Right/DescPanel/DescLabel", "Content/Right/DescPanel/DescLabel") as RichTextLabel

@onready var btn_use: BaseButton = _n("Root/Content/left/Action/BtnUse", "Content/left/Action/BtnUse") as BaseButton
@onready var btn_drop: BaseButton = _n("Root/Content/left/Action/BtnDrop", "Content/left/Action/BtnDrop") as BaseButton

@export_group("Action Buttons")
@export var action_disabled_modulate: Color = Color(1, 1, 1, 0.35)
@export var action_enabled_modulate: Color = Color(1, 1, 1, 1)
@export var action_unselected_modulate: Color = Color(0.55, 0.55, 0.55, 1)
@export var action_selected_scale: Vector2 = Vector2(1.06, 1.06)
@export var action_normal_scale: Vector2 = Vector2(1.0, 1.0)


@onready var tab_all: Control = _n("Root/Content/left/tabs/TabAll", "Content/left/tabs/TabAll") as Control
@onready var tab_wpn: Control = _n("Root/Content/left/tabs/TabWeapon", "Content/left/tabs/TabWeapon") as Control
@onready var tab_arm: Control = _n("Root/Content/left/tabs/TabArmor", "Content/left/tabs/TabArmor") as Control
@onready var tab_pot: Control = _n("Root/Content/left/tabs/TabPotion", "Content/left/tabs/TabPotion") as Control
@onready var tab_oth: Control = _n("Root/Content/left/tabs/TabOther", "Content/left/tabs/TabOther") as Control

var _tabs_nodes: Array[BaseButton] = []

enum UiMode { GRID, ACTION, TARGET }
var _mode: UiMode = UiMode.GRID
var _action_index := 0 # 0=Use, 1=Drop
var _target_index: int = 0
var _pending_use_item: ItemData = null

var _target_overlay: Control = null
var _target_rows: Array[PanelContainer] = []
var _target_title_label: Label = null
var _target_item_label: Label = null
var _target_scroll: ScrollContainer = null

# Tabs: 0=ALL,1=WPN,2=ARM,3=POT,4=OTH
var _tab := 0
var _focus_tabs := false

# Slots
var slots: Array[Node] = []
var _slot_items: Array[ItemData] = []
var selected_slot := -1
var _slot_count := 0

# Equip-select mode
enum ScreenMode { NORMAL, EQUIP_SELECT }
var _screen_mode: ScreenMode = ScreenMode.NORMAL
var _equip_filter_slot: ItemData.EquipSlot = ItemData.EquipSlot.NONE
var _equip_allowed_mask: int = 0



func _get_tab_node(idx: int) -> Control:
	if idx < 0 or idx >= _tabs_nodes.size():
		return null
	return _tabs_nodes[idx]


func _rebuild_tabs_nodes() -> void:
	# Collect tab buttons safely (supports both old/new node layouts).
	_tabs_nodes.clear()
	var tabs_root: Node = null
	# Try common paths first
	if has_node("Root/Content/left/tabs"):
		tabs_root = get_node("Root/Content/left/tabs")
	elif has_node("Content/left/tabs"):
		tabs_root = get_node("Content/left/tabs")
	else:
		# Fallback: search by name
		tabs_root = _find_by_name(self, "tabs")
	if tabs_root == null:
		return
	# Collect buttons (direct children or nested)
	_collect_buttons_recursive(tabs_root, _tabs_nodes)

func _collect_buttons_recursive(n: Node, out_arr: Array[BaseButton]) -> void:
	for ch in n.get_children():
		if ch is BaseButton:
			out_arr.append(ch)
		else:
			_collect_buttons_recursive(ch, out_arr)

func _ready() -> void:
	# Extra safety: if you moved nodes / changed where the script is attached.
	if grid == null:
		grid = _find_by_name(self, "Grid") as Control
	if scroll == null:
		scroll = _find_by_name(self, "Scroll") as Control
	if btn_use == null:
		btn_use = _find_by_name(self, "BtnUse") as BaseButton
	if btn_drop == null:
		btn_drop = _find_by_name(self, "BtnDrop") as BaseButton
	if preview_icon == null:
		preview_icon = _find_by_name(self, "PreviewIcon") as TextureRect
	if title_label == null:
		title_label = _find_by_name(self, "TitleLabel") as Label
	if desc_label == null:
		desc_label = _find_by_name(self, "DescLabel") as RichTextLabel
	if gold_label == null:
		gold_label = _find_by_name(self, "GoldLabel") as Label
	if grid == null:
		push_error("InventoryScreen: Grid node not found. Check node paths or rename back to 'Grid'.")
		return
	_rebuild_tabs_nodes()
	if slot_scene == null:
		push_warning("InventoryScreen: Slot Scene is empty in Inspector!")
	_update_gold_label()

	# Mouse click support
	if btn_use:
		btn_use.pressed.connect(_on_use_pressed)
	if btn_drop:
		btn_drop.pressed.connect(_on_drop_pressed)

	_update_tab_highlight()

	visible = false
	_exit_action_mode()


# -------- Public --------
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

	if btn_use: btn_use.visible = true
	if btn_drop: btn_drop.visible = true
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


# -------- Inventory operations --------
func _remove_one_instance_from_inventory(item: ItemData) -> bool:
	if item == null:
		return false
	var idx := starting_items.find(item)
	if idx == -1:
		return false
	starting_items.remove_at(idx)
	return true


# -------- Slots --------
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


# -------- Tabs / Filter --------
func _update_tab_highlight() -> void:
	if _tabs_nodes.is_empty():
		return
	for i in range(_tabs_nodes.size()):
		var t := _tabs_nodes[i]
		if t == null:
			continue
		t.self_modulate = Color(1, 1, 1, 1) if i == _tab else Color(0.6, 0.6, 0.6, 1)


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
	if _focus_tabs:
		_set_grid_cursor_visible(false)


# -------- Selection / Preview --------
func _get_selected_item() -> ItemData:
	if selected_slot < 0 or selected_slot >= _slot_items.size():
		return null
	return _slot_items[selected_slot]


func _select_slot(i: int) -> void:
	if _slot_count <= 0:
		selected_slot = -1
		return

	selected_slot = clampi(i, 0, _slot_count - 1)

	for j in range(slots.size()):
		if slots[j].has_method("set_selected"):
			slots[j].call("set_selected", j == selected_slot and slots[j].visible)

	var item := _get_selected_item()
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


# -------- Action mode (Use/Drop) --------
func _set_grid_cursor_visible(v: bool) -> void:
	# When focusing tabs, we want NO active selection visible on the grid.
	for j in range(slots.size()):
		if slots[j].has_method("set_selected"):
			slots[j].call("set_selected", v and j == selected_slot and slots[j].visible)


func _set_action_buttons_enabled(enabled: bool) -> void:
	if btn_use:
		btn_use.disabled = not enabled
		btn_use.self_modulate = action_enabled_modulate if enabled else action_disabled_modulate
		btn_use.scale = action_normal_scale
	if btn_drop:
		btn_drop.disabled = not enabled
		btn_drop.self_modulate = action_enabled_modulate if enabled else action_disabled_modulate
		btn_drop.scale = action_normal_scale


func _set_action_selected(idx: int) -> void:
	_action_index = clampi(idx, 0, 1)

	# Only meaningful when buttons are enabled (ACTION mode).
	if btn_use:
		btn_use.self_modulate = action_enabled_modulate if _action_index == 0 else action_unselected_modulate
		btn_use.scale = action_selected_scale if _action_index == 0 else action_normal_scale
	if btn_drop:
		btn_drop.self_modulate = action_enabled_modulate if _action_index == 1 else action_unselected_modulate
		btn_drop.scale = action_selected_scale if _action_index == 1 else action_normal_scale


func _enter_action_mode() -> void:
	_mode = UiMode.ACTION
	_set_action_selected(0)


func _exit_action_mode() -> void:
	_mode = UiMode.GRID
	_set_action_buttons_enabled(false)


func _confirm_action_mode() -> void:
	# Keyboard confirm while in ACTION mode
	if _action_index == 0:
		_on_use_pressed()
	else:
		_on_drop_pressed()


# -------- Input --------
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		if _screen_mode == ScreenMode.EQUIP_SELECT:
			equip_selection_canceled.emit()
			close()
		else:
			if _mode == UiMode.TARGET:
				_exit_target_mode()
			elif _mode == UiMode.ACTION:
				_exit_action_mode()
			elif _focus_tabs:
				_focus_tabs = false
				_set_grid_cursor_visible(true)
				_select_slot(clampi(selected_slot, 0, max(_slot_count - 1, 0)))
			else:
				close()
		get_viewport().set_input_as_handled()
		return

	# EQUIP SELECT: E selects and removes from inventory
	if _screen_mode == ScreenMode.EQUIP_SELECT and event.is_action_pressed("action"):
		var item := _get_selected_item()
		if item != null:
			_remove_one_instance_from_inventory(item)
			_apply_filter()
			equip_item_selected.emit(item)
			close()
		get_viewport().set_input_as_handled()
		return


	# TARGET MODE input: choose who receives the item effect.
	if _mode == UiMode.TARGET:
		var p: PartyData = _get_valid_party_data()
		var count: int = p.heroes.size() if p != null else 0

		if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
			if count > 0:
				_target_index = int(posmod(_target_index - 1, count))
				_update_target_use_text()
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
			if count > 0:
				_target_index = int(posmod(_target_index + 1, count))
				_update_target_use_text()
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
			_confirm_target_use()
			get_viewport().set_input_as_handled()
			return

		return

	# ACTION MODE input (THIS was the missing part)
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
			_confirm_action_mode()

			# _confirm_action_mode() may open TARGET mode for potions.
			# Do not force back to GRID if target overlay was opened.
			if _mode == UiMode.ACTION:
				_exit_action_mode()

			get_viewport().set_input_as_handled()
			return
		return


	# TAB FOCUS navigation (top row tabs)
	if _focus_tabs:
		if event.is_action_pressed("move_left"):
			if _tabs_nodes.size() > 0:
				_tab = (_tab - 1 + _tabs_nodes.size()) % _tabs_nodes.size()
			_update_tab_highlight()
			_apply_filter()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("move_right"):
			if _tabs_nodes.size() > 0:
				_tab = (_tab + 1) % _tabs_nodes.size()
			_update_tab_highlight()
			_apply_filter()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("move_down") or event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
			_focus_tabs = false
			_set_grid_cursor_visible(true)
			# Return focus to the currently selected grid slot
			_select_slot(clampi(selected_slot, 0, max(_slot_count - 1, 0)))
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("move_up"):
			# Already at tabs - do nothing
			get_viewport().set_input_as_handled()
			return

	# GRID navigation
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
			_set_grid_cursor_visible(false)
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("move_down") and idx + cols < _slot_count:
		idx += cols
		moved = true

	if moved:
		_select_slot(idx)
		get_viewport().set_input_as_handled()
		return

	# Enter action mode with E
	if _screen_mode == ScreenMode.NORMAL and event.is_action_pressed("action"):
		var item := _get_selected_item()
		if item != null:
			_enter_action_mode()
			get_viewport().set_input_as_handled()


# -------- Button callbacks --------

func _show_use_message(msg: String, is_error: bool = true) -> void:
	# Shows a temporary message in the description panel (right side).
	desc_label.bbcode_enabled = true
	var color := "#ff6b6b" if is_error else "#7CFF7C"
	desc_label.text = "[color=%s]%s[/color]" % [color, msg]

func _on_use_pressed() -> void:
	# Use selected item.
	if _screen_mode != ScreenMode.NORMAL:
		return

	var item := _get_selected_item()
	if item == null:
		return

	if not ("usable_in_inventory" in item) or item.usable_in_inventory == false:
		_show_use_message("Не может быть использовано")
		return

	if not ("use_effect" in item) or item.use_effect == null:
		_show_use_message("У предмета нет эффекта")
		return

	var effect: ItemUseEffect = item.use_effect
	if _effect_needs_party_target(effect):
		_enter_target_mode(item)
		return

	if _apply_item_effect_to_party_member(item, 0):
		_consume_after_success(item)
		_show_use_message(_get_use_success_message(item), false)
	else:
		_show_use_message("Сейчас это не даст эффекта")


func _effect_needs_party_target(effect: ItemUseEffect) -> bool:
	if effect == null:
		return false
	return int(effect.hp_restore) != 0 or int(effect.mp_restore) != 0


func _enter_target_mode(item: ItemData) -> void:
	var p: PartyData = _get_valid_party_data()
	if p == null or p.heroes.is_empty():
		_show_use_message("Нет доступных целей")
		return

	_pending_use_item = item
	_target_index = clampi(_target_index, 0, p.heroes.size() - 1)
	_mode = UiMode.TARGET
	_set_action_buttons_enabled(false)
	_show_target_overlay()
	_update_target_use_text()


func _exit_target_mode() -> void:
	_mode = UiMode.GRID
	_pending_use_item = null
	_hide_target_overlay()
	_select_slot(selected_slot)


func _update_target_use_text() -> void:
	var p: PartyData = _get_valid_party_data()
	if p == null or p.heroes.is_empty():
		_show_use_message("Нет доступных целей")
		return

	_show_target_overlay()

	if _target_title_label != null:
		_target_title_label.text = target_overlay_title

	if _target_item_label != null:
		var item_title: String = _pending_use_item.title if _pending_use_item != null else "предмет"
		_target_item_label.text = "%s %s" % [target_overlay_item_prefix, item_title]

	for i in range(_target_rows.size()):
		var row: PanelContainer = _target_rows[i]
		if row == null:
			continue

		var sb := StyleBoxFlat.new()
		sb.bg_color = target_overlay_selected_color if i == _target_index else target_overlay_normal_color
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", sb)

		var marker := row.find_child("MarkerLabel", true, false) as Label
		if marker != null:
			marker.text = "▶" if i == _target_index else ""

		var name_label := row.find_child("NameLabel", true, false) as Label
		var hp_label := row.find_child("HpLabel", true, false) as Label
		var mp_label := row.find_child("MpLabel", true, false) as Label
		var portrait_rect := row.find_child("Portrait", true, false) as TextureRect

		if i >= p.heroes.size():
			continue

		var hero: HeroData = p.heroes[i]
		if hero == null:
			continue

		if name_label != null:
			name_label.text = hero.hero_name

		if hp_label != null:
			hp_label.text = "HP %d / %d" % [_get_hero_current_hp(hero), _get_hero_max_hp(hero)]

		if mp_label != null:
			hp_label.text = hp_label.text if hp_label != null else ""
			mp_label.text = "MP %d / %d" % [_get_hero_current_mp(hero), _get_hero_max_mp(hero)]

		if portrait_rect != null:
			portrait_rect.texture = hero.portrait

		if i == _target_index and _target_scroll != null:
			_target_scroll.ensure_control_visible(row)


func _confirm_target_use() -> void:
	if _pending_use_item == null:
		_exit_target_mode()
		return

	if _apply_item_effect_to_party_member(_pending_use_item, _target_index):
		var used_item: ItemData = _pending_use_item
		_consume_after_success(used_item)
		_pending_use_item = null
		_mode = UiMode.GRID
		_hide_target_overlay()
		_apply_filter()
		selected_slot = clampi(selected_slot, 0, max(_slot_count - 1, 0))
		_select_slot(selected_slot)
		_show_use_message(_get_use_success_message(used_item), false)
	else:
		_update_target_use_text()
		_show_use_message("Сейчас это не даст эффекта")


func _apply_item_effect_to_party_member(item: ItemData, target_index: int) -> bool:
	if item == null or item.use_effect == null:
		return false

	var p: PartyData = _get_valid_party_data()
	if p == null or p.heroes.is_empty():
		return false

	var idx: int = clampi(target_index, 0, p.heroes.size() - 1)
	var hero: HeroData = p.heroes[idx]
	if hero == null:
		return false

	var effect: ItemUseEffect = item.use_effect
	var changed: bool = false

	if int(effect.hp_restore) != 0:
		var max_hp: int = _get_hero_max_hp(hero)
		var before_hp: int = _get_hero_current_hp(hero)
		var after_hp: int = clampi(before_hp + int(effect.hp_restore), 0, max_hp)
		if after_hp != before_hp:
			hero.hp_current = after_hp
			changed = true

	if int(effect.mp_restore) != 0:
		var max_mp: int = _get_hero_max_mp(hero)
		var before_mp: int = _get_hero_current_mp(hero)
		var after_mp: int = clampi(before_mp + int(effect.mp_restore), 0, max_mp)
		if after_mp != before_mp:
			hero.mp_current = after_mp
			changed = true

	_refresh_status_screens()

	return changed


func _consume_after_success(item: ItemData) -> void:
	if item == null or item.use_effect == null:
		return

	if item.use_effect.consume_on_use:
		if _remove_one_instance_from_inventory(item):
			_apply_filter()
			selected_slot = clampi(selected_slot, 0, max(_slot_count - 1, 0))
			_select_slot(selected_slot)


func _get_use_success_message(item: ItemData) -> String:
	if item != null and item.use_effect != null:
		var msg: String = str(item.use_effect.use_message).strip_edges()
		if msg != "":
			return msg
	return "Использовано"



func _show_target_overlay() -> void:
	if _target_overlay == null:
		_build_target_overlay()

	if _target_overlay != null:
		_target_overlay.visible = true
		_target_overlay.move_to_front()


func _hide_target_overlay() -> void:
	if _target_overlay != null:
		_target_overlay.visible = false


func _build_target_overlay() -> void:
	var p: PartyData = _get_valid_party_data()
	if p == null:
		return

	_target_overlay = Control.new()
	_target_overlay.name = "UseTargetOverlay"
	_target_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_overlay.visible = false
	add_child(_target_overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = target_overlay_dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "TargetPanel"
	var p_count: int = max(p.heroes.size(), 1)
	var visible_rows_for_size: int = mini(maxi(target_overlay_max_visible_rows, 1), p_count)
	var dynamic_height: float = max(target_overlay_panel_size.y, 160.0 + visible_rows_for_size * target_overlay_row_height)
	var panel_size := Vector2(target_overlay_panel_size.x, dynamic_height)

	panel.custom_minimum_size = panel_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = target_overlay_panel_color
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)

	_target_overlay.add_child(panel)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	_target_title_label = Label.new()
	_target_title_label.name = "TitleLabel"
	_target_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_title_label.text = target_overlay_title
	root.add_child(_target_title_label)

	_target_item_label = Label.new()
	_target_item_label.name = "ItemLabel"
	_target_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_target_item_label)

	_target_scroll = ScrollContainer.new()
	_target_scroll.name = "TargetScroll"
	_target_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_target_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_target_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var visible_rows: int = mini(maxi(target_overlay_max_visible_rows, 1), max(p.heroes.size(), 1))
	_target_scroll.custom_minimum_size = Vector2(0, visible_rows * target_overlay_row_height + max(0, visible_rows - 1) * 6)
	root.add_child(_target_scroll)

	var list := VBoxContainer.new()
	list.name = "TargetList"
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_scroll.add_child(list)

	_target_rows.clear()

	for i in range(p.heroes.size()):
		var row := PanelContainer.new()
		row.name = "TargetRow_%d" % i
		row.custom_minimum_size = Vector2(0, target_overlay_row_height)
		list.add_child(row)
		_target_rows.append(row)

		var h := HBoxContainer.new()
		h.name = "RowContent"
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)

		var marker := Label.new()
		marker.name = "MarkerLabel"
		marker.custom_minimum_size = Vector2(26, 0)
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(marker)

		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.custom_minimum_size = target_overlay_portrait_size
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(portrait)

		var text_box := VBoxContainer.new()
		text_box.name = "TextBox"
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(text_box)

		var name_label := Label.new()
		name_label.name = "NameLabel"
		text_box.add_child(name_label)

		var hp_label := Label.new()
		hp_label.name = "HpLabel"
		text_box.add_child(hp_label)

		var mp_label := Label.new()
		mp_label.name = "MpLabel"
		text_box.add_child(mp_label)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.text = target_overlay_hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

func _get_valid_party_data() -> PartyData:
	if party != null and not party.heroes.is_empty():
		return party

	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	return _search_party_recursive(scene)


func _search_party_recursive(root: Node) -> PartyData:
	if root == null:
		return null

	if "party" in root:
		var p = root.party
		if p != null and p is PartyData:
			var pd: PartyData = p as PartyData
			if not pd.heroes.is_empty():
				return pd

	for child in root.get_children():
		var found: PartyData = _search_party_recursive(child)
		if found != null:
			return found

	return null


func _get_hero_max_hp(hero: HeroData) -> int:
	if hero == null or hero.base_stats == null:
		return 0
	return max(0, int(hero.base_stats.hp))


func _get_hero_max_mp(hero: HeroData) -> int:
	if hero == null or hero.base_stats == null:
		return 0
	return max(0, int(hero.base_stats.mp))


func _get_hero_current_hp(hero: HeroData) -> int:
	var max_hp: int = _get_hero_max_hp(hero)
	var cur: int = int(hero.hp_current)
	if cur <= 0 and max_hp > 0:
		cur = max_hp
	return clampi(cur, 0, max_hp)


func _get_hero_current_mp(hero: HeroData) -> int:
	var max_mp: int = _get_hero_max_mp(hero)
	var cur: int = int(hero.mp_current)
	if cur < 0:
		cur = 0
	if cur == 0 and max_mp > 0:
		cur = max_mp
	return clampi(cur, 0, max_mp)


func _refresh_status_screens() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_refresh_status_recursive(scene)


func _refresh_status_recursive(root: Node) -> void:
	if root == null:
		return

	if root.has_method("_render"):
		root.call("_render")
	elif root.has_method("_refresh"):
		root.call("_refresh")
	elif root.has_method("refresh"):
		root.call("refresh")

	for child in root.get_children():
		_refresh_status_recursive(child)


func _on_drop_pressed() -> void:
	# Remove selected item from inventory.
	if _screen_mode != ScreenMode.NORMAL:
		return

	var item := _get_selected_item()
	if item == null:
		return

	if _remove_one_instance_from_inventory(item):
		_apply_filter()
		selected_slot = clampi(selected_slot, 0, max(_slot_count - 1, 0))
		_select_slot(selected_slot)
