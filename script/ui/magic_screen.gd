extends Control
class_name MagicScreen

signal closed

@export_group("Data")
@export var party: PartyData

@export_group("UI")
# Keep these as your preferred values:
@export var cursor_modulate: Color = Color(0.294, 0.294, 0.294, 0.447)
@export var cursor_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var cursor_tint_strong: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("Behavior")
@export var show_description_only_in_grid: bool = true

@export_group("Selection Scale")
# Small scale pop for the currently selected slot (only in GRID focus).
@export var selected_slot_scale: Vector2 = Vector2(1.06, 1.06)
@export var normal_slot_scale: Vector2 = Vector2(1.0, 1.0)

@onready var background: Node = $Background
@onready var party_bar: Control = $Background/PartyBar
@onready var magic_grid: Control = $Background/MagicGrid

# Optional branch icon UI:
# Background/BranchIcons/BranchIcon_1..BranchIcon_4 (TextureRect)
@onready var branch_icons_root: Node = $Background/BranchIcons if has_node("Background/BranchIcons") else null

# Desc UI (resolved in _ready)
var spell_name: Label
var desc_text: RichTextLabel
var spell_icon: TextureRect

var _portraits: Array[BaseButton] = []
var _slots: Array[MagicSlot] = []

enum Focus { PARTY, GRID }
var _focus: Focus = Focus.PARTY
var _hero_idx: int = 0
var _slot_idx: int = 0  # 0..15, left->right, top->bottom


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)
	_collect_nodes()
	_try_autofill_party()
	_resolve_desc_nodes()
	_set_focus(Focus.PARTY)
	_refresh_all()


func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	_collect_nodes()
	_try_autofill_party()
	_resolve_desc_nodes()
	_set_focus(Focus.PARTY)
	_hero_idx = clampi(_hero_idx, 0, max(_hero_count() - 1, 0))
	_slot_idx = clampi(_slot_idx, 0, max(_slots.size() - 1, 0))
	_refresh_all()


func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		if _focus == Focus.GRID:
			_set_focus(Focus.PARTY)
			get_viewport().set_input_as_handled()
			return
		close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		if _focus == Focus.PARTY:
			_set_focus(Focus.GRID)
		else:
			_show_selected_spell()
		get_viewport().set_input_as_handled()
		return

	if _focus == Focus.PARTY:
		if event.is_action_pressed("move_left"):
			_select_hero(_hero_idx - 1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_right"):
			_select_hero(_hero_idx + 1)
			get_viewport().set_input_as_handled()
	else:
		_handle_grid_nav(event)


func _handle_grid_nav(event: InputEvent) -> void:
	var cols: int = 4
	var rows: int = 4
	var max_i: int = _slots.size() - 1
	if max_i < 0:
		return

	var r: int = _slot_idx / cols
	var c: int = _slot_idx % cols

	if event.is_action_pressed("move_left"):
		if c > 0: _slot_idx -= 1
	elif event.is_action_pressed("move_right"):
		if c < cols - 1: _slot_idx += 1
	elif event.is_action_pressed("move_up"):
		if r > 0: _slot_idx -= cols
	elif event.is_action_pressed("move_down"):
		if r < rows - 1: _slot_idx += cols

	_slot_idx = clampi(_slot_idx, 0, max_i)
	_update_grid_highlight()
	_show_selected_spell()
	get_viewport().set_input_as_handled()


func _collect_nodes() -> void:
	_portraits.clear()
	for c in party_bar.get_children():
		if c is BaseButton:
			_portraits.append(c)

	_slots = _find_slots_ordered(magic_grid)


func _find_slots_ordered(root: Node) -> Array[MagicSlot]:
	var ordered: Array[MagicSlot] = []
	for i in range(1, 17):
		var n := root.get_node_or_null("MagicSlot_%d" % i)
		if n != null and n is MagicSlot:
			ordered.append(n)
	if not ordered.is_empty():
		return ordered

	var all: Array[MagicSlot] = []
	_collect_magic_slots_recursive(root, all)
	all.sort_custom(func(a: MagicSlot, b: MagicSlot) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return all


func _collect_magic_slots_recursive(n: Node, out_arr: Array[MagicSlot]) -> void:
	for ch in n.get_children():
		if ch is MagicSlot:
			out_arr.append(ch)
		_collect_magic_slots_recursive(ch, out_arr)


func _try_autofill_party() -> void:
	if party != null:
		return
	var parent := get_parent()
	if parent == null:
		return

	var equip := parent.get_node_or_null("EquipScreen")
	if equip != null and ("party" in equip):
		party = equip.party
		return

	var status := parent.get_node_or_null("StatusScreen")
	if status != null and ("party" in status):
		party = status.party
		return


func _hero_count() -> int:
	if party == null:
		return 0
	return party.heroes.size()


func _get_hero() -> HeroData:
	if party == null:
		return null
	if _hero_idx < 0 or _hero_idx >= party.heroes.size():
		return null
	return party.heroes[_hero_idx]


func _select_hero(i: int) -> void:
	var n: int = _hero_count()
	if n <= 0:
		_hero_idx = 0
	else:
		_hero_idx = clampi(i, 0, n - 1)
	_slot_idx = clampi(_slot_idx, 0, max(_slots.size() - 1, 0))
	_refresh_all()


func _set_focus(f: Focus) -> void:
	_focus = f
	_update_party_highlight()
	_update_grid_highlight()
	_show_selected_spell()


func _update_party_highlight() -> void:
	for i in range(_portraits.size()):
		var b: BaseButton = _portraits[i]
		var is_selected: bool = (i == _hero_idx)
		if is_selected:
			b.self_modulate = cursor_tint_strong if _focus == Focus.PARTY else cursor_tint
		else:
			b.self_modulate = cursor_modulate


func _update_grid_highlight() -> void:
	# When not in GRID focus: keep grid neutral (no tint, no scale).
	if _focus != Focus.GRID:
		for i in range(_slots.size()):
			_slots[i].self_modulate = Color(1, 1, 1, 1)
			_slots[i].scale = normal_slot_scale
		return

	# In GRID focus:
	for i in range(_slots.size()):
		var b: MagicSlot = _slots[i]
		var active: bool = (i == _slot_idx)
		# Keep backgrounds white, but add a small scale pop to the active slot.
		b.self_modulate = cursor_tint if active else Color(1, 1, 1, 1)
		b.scale = selected_slot_scale if active else normal_slot_scale


func _apply_party_portraits() -> void:
	for i in range(_portraits.size()):
		var b: BaseButton = _portraits[i]
		if party == null or i >= party.heroes.size():
			b.visible = false
			continue
		b.visible = true
		var h: HeroData = party.heroes[i]
		if h != null and h.portrait != null and b is TextureButton:
			(b as TextureButton).texture_normal = h.portrait


func _refresh_all() -> void:
	_apply_party_portraits()
	_update_branch_icons()
	_fill_grid_from_hero()
	_update_party_highlight()
	_update_grid_highlight()
	_show_selected_spell()


func _hero_level(hero: HeroData) -> int:
	return hero.level if hero != null and ("level" in hero) else 1


func _fill_grid_from_hero() -> void:
	var hero: HeroData = _get_hero()
	var tree: HeroMagicTree = hero.magic_tree if hero != null and ("magic_tree" in hero) else null
	var lvl: int = _hero_level(hero)

	for i in range(_slots.size()):
		var slot: MagicSlot = _slots[i]
		var branch_index: int = i / 4
		var level_index: int = i % 4

		var unlock: SpellUnlock = null
		if tree != null:
			unlock = tree.get_unlock(branch_index, level_index)

		if unlock == null or unlock.enabled == false:
			slot.set_state(null, false, true)
			continue

		var is_locked: bool = true
		if lvl >= unlock.required_level and unlock.required_item_id == "" and unlock.required_flag == "":
			is_locked = false
		slot.set_state(unlock.spell, true, is_locked)


func _update_branch_icons() -> void:
	if branch_icons_root == null:
		return

	var hero := _get_hero()
	var tree: HeroMagicTree = hero.magic_tree if hero != null and ("magic_tree" in hero) else null

	for i in range(4):
		var n := branch_icons_root.get_node_or_null("BranchIcon_%d" % (i + 1))
		if n == null or not (n is TextureRect):
			continue
		var tr := n as TextureRect
		if tree == null or i >= tree.branches.size() or tree.branches[i] == null:
			tr.texture = null
			continue
		tr.texture = tree.branches[i].branch_icon


func _resolve_desc_nodes() -> void:
	var dp := background.get_node_or_null("DescPanel")
	if dp == null:
		dp = _find_by_name(background, "DescPanel")

	if dp != null:
		spell_name = (dp.get_node_or_null("SpellName") as Label)
		desc_text = (dp.get_node_or_null("SpellDesc") as RichTextLabel)
		spell_icon = (dp.get_node_or_null("SpellIcon") as TextureRect)

	if spell_name == null:
		spell_name = _find_by_name(background, "SpellName") as Label
	if desc_text == null:
		desc_text = _find_by_name(background, "SpellDesc") as RichTextLabel
	if spell_icon == null:
		spell_icon = _find_by_name(background, "SpellIcon") as TextureRect


func _find_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for ch in root.get_children():
		var found := _find_by_name(ch, target_name)
		if found != null:
			return found
	return null


func _clear_desc_panel() -> void:
	if spell_name:
		spell_name.text = ""
	if desc_text:
		desc_text.text = ""
	if spell_icon:
		spell_icon.texture = null


func _show_selected_spell() -> void:
	if desc_text == null or spell_name == null:
		return

	if show_description_only_in_grid and _focus == Focus.PARTY:
		_clear_desc_panel()
		return

	var hero := _get_hero()
	if hero == null:
		_clear_desc_panel()
		return

	if not ("magic_tree" in hero) or hero.magic_tree == null:
		spell_name.text = hero.hero_name
		desc_text.bbcode_enabled = true
		desc_text.text = "Нет дерева магии (magic_tree)."
		if spell_icon: spell_icon.texture = null
		return

	if _slots.is_empty():
		_clear_desc_panel()
		return

	_slot_idx = clampi(_slot_idx, 0, _slots.size() - 1)
	var s: MagicSlot = _slots[_slot_idx]

	if not s.exists:
		spell_name.text = "???"
		desc_text.bbcode_enabled = true
		desc_text.text = "Слот недоступен."
		if spell_icon: spell_icon.texture = null
		return

	if s.locked or s.spell == null:
		spell_name.text = "???"
		desc_text.bbcode_enabled = true
		desc_text.text = "Магия закрыта."
		if spell_icon: spell_icon.texture = null
		return

	var sp: SpellData = s.spell
	spell_name.text = sp.title
	if spell_icon: spell_icon.texture = sp.icon

	desc_text.bbcode_enabled = true
	var elem: String = str(SpellData.Element.keys()[int(sp.element)])
	desc_text.text = "%s\n\nMana: %d\nElement: %s" % [
		sp.description,
		sp.mp_cost,
		elem
	]
