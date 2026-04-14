extends Control
class_name MagicScreen

signal closed

@export_group("Data")
@export var party: PartyData

@export_group("UI")
@export var cursor_modulate: Color = Color(0.31, 0.31, 0.31, 0.522)
@export var cursor_tint: Color = Color(1.0, 1.0, 1.0, 1.0)

@onready var party_bar: Control = $Background/PartyBar
@onready var magic_grid: Control = $Background/MagicGrid
@onready var spell_name: Label = $Background/DescPanel/SpellName
@onready var desc_text: RichTextLabel = $Background/DescPanel/SpellDesc
@onready var spell_icon: TextureRect = $Background/DescPanel/SpellIcon if has_node("Background/DescPanel/SpellIcon") else null

var _portraits: Array[BaseButton] = []
var _slots: Array[MagicSlot] = []

enum Focus { PARTY, GRID }
var _focus: Focus = Focus.PARTY
var _hero_idx: int = 0
var _slot_idx: int = 0  # 0..15


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)
	_collect_nodes()
	_try_autofill_party()
	_set_focus(Focus.PARTY)
	_refresh_all()


func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	_collect_nodes()
	_try_autofill_party()
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
	# If Party isn't set in Inspector, try to grab it from sibling screens.
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
	_refresh_all()


func _set_focus(f: Focus) -> void:
	_focus = f
	_update_party_highlight()
	_update_grid_highlight()
	_show_selected_spell()


func _update_party_highlight() -> void:
	for i in range(_portraits.size()):
		var b: BaseButton = _portraits[i]
		var active: bool = (_focus == Focus.PARTY and i == _hero_idx)
		b.self_modulate = cursor_tint if active else cursor_modulate


func _update_grid_highlight() -> void:
	for i in range(_slots.size()):
		var b: MagicSlot = _slots[i]
		var active: bool = (_focus == Focus.GRID and i == _slot_idx)
		b.self_modulate = cursor_tint if active else cursor_modulate


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
		var branch: int = i % 4
		var level_index: int = i / 4

		var unlock: SpellUnlock = null
		if tree != null:
			unlock = tree.get_unlock(branch, level_index)

		if unlock == null or unlock.enabled == false:
			slot.set_state(null, false, true)
			continue

		var is_locked: bool = true
		if lvl >= unlock.required_level and unlock.required_item_id == "" and unlock.required_flag == "":
			is_locked = false
		slot.set_state(unlock.spell, true, is_locked)


func _show_selected_spell() -> void:
	if desc_text == null or spell_name == null:
		return

	var hero := _get_hero()

	# While choosing hero, show hint (no mouse).
	if _focus == Focus.PARTY:
		spell_name.text = hero.hero_name if hero != null else "—"
		desc_text.bbcode_enabled = true
		desc_text.text = "A/D — выбрать героя\nE — перейти к магии\nTab/Esc — назад"
		if spell_icon: spell_icon.texture = null
		return

	# GRID focus:
	if hero == null:
		spell_name.text = ""
		desc_text.text = ""
		if spell_icon: spell_icon.texture = null
		return

	# If hero has no tree assigned, explain it.
	if not ("magic_tree" in hero) or hero.magic_tree == null:
		spell_name.text = hero.hero_name
		desc_text.bbcode_enabled = true
		desc_text.text = "Для этого героя не назначено дерево магии (magic_tree).\nНазначь его в party_data.tres -> Heroes[%d]." % _hero_idx
		if spell_icon: spell_icon.texture = null
		return

	if _slots.is_empty():
		spell_name.text = ""
		desc_text.text = ""
		if spell_icon: spell_icon.texture = null
		return

	_slot_idx = clampi(_slot_idx, 0, _slots.size() - 1)
	var s: MagicSlot = _slots[_slot_idx]

	if not s.exists:
		spell_name.text = "???"
		desc_text.bbcode_enabled = true
		desc_text.text = "Этот слот недоступен для этого героя."
		if spell_icon: spell_icon.texture = null
		return

	if s.locked or s.spell == null:
		spell_name.text = "???"
		desc_text.bbcode_enabled = true
		desc_text.text = "Заклинание ещё не открыто (проверь required_level)."
		if spell_icon: spell_icon.texture = null
		return

	var sp: SpellData = s.spell
	spell_name.text = sp.title
	if spell_icon: spell_icon.texture = sp.icon

	desc_text.bbcode_enabled = true
	var elem: String = str(SpellData.Element.keys()[int(sp.element)])
	var eff: String = str(SpellData.EffectType.keys()[int(sp.effect_type)])
	desc_text.text = "%s\n\n[b]MP:[/b] %d\n[b]Element:[/b] %s\n[b]Type:[/b] %s" % [
		sp.description,
		sp.mp_cost,
		elem,
		eff
	]
