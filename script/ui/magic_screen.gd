extends Control
class_name MagicScreen

signal closed

@export_group("Data")
@export var party: PartyData

@export_group("UI")
@export var cursor_modulate: Color = Color(1,1,1,1)
@export var cursor_tint: Color = Color(1,1,0.85,1)

@onready var party_bar: Control = $Background/PartyBar
@onready var magic_grid: GridContainer = $Background/MagicGrid
@onready var spell_name: Label = $Background/DescPanel/SpellName
@onready var desc_text: RichTextLabel = $Background/DescPanel/DescText
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
	_set_focus(Focus.PARTY)
	_refresh_all()

func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	_collect_nodes()
	_set_focus(Focus.PARTY)
	_hero_idx = clampi(_hero_idx, 0, max(_hero_count()-1, 0))
	_slot_idx = clampi(_slot_idx, 0, 15)
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
	var cols := 4
	var r := _slot_idx / cols
	var c := _slot_idx % cols

	if event.is_action_pressed("move_left"):
		if c > 0: _slot_idx -= 1
	elif event.is_action_pressed("move_right"):
		if c < cols-1: _slot_idx += 1
	elif event.is_action_pressed("move_up"):
		if r > 0: _slot_idx -= cols
	elif event.is_action_pressed("move_down"):
		if r < 3: _slot_idx += cols

	_slot_idx = clampi(_slot_idx, 0, 15)
	_update_grid_highlight()
	_show_selected_spell()
	get_viewport().set_input_as_handled()

func _collect_nodes() -> void:
	_portraits.clear()
	for c in party_bar.get_children():
		if c is BaseButton:
			_portraits.append(c)

	_slots.clear()
	for c in magic_grid.get_children():
		if c is MagicSlot:
			_slots.append(c)

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
	var n := _hero_count()
	if n <= 0:
		_hero_idx = 0
	else:
		_hero_idx = clampi(i, 0, n-1)
	_refresh_all()

func _set_focus(f: Focus) -> void:
	_focus = f
	_update_party_highlight()
	_update_grid_highlight()
	_show_selected_spell()

func _update_party_highlight() -> void:
	for i in range(_portraits.size()):
		var b := _portraits[i]
		var active := (_focus == Focus.PARTY and i == _hero_idx)
		b.self_modulate = cursor_tint if active else cursor_modulate

func _update_grid_highlight() -> void:
	for i in range(_slots.size()):
		var b := _slots[i]
		var active := (_focus == Focus.GRID and i == _slot_idx)
		b.self_modulate = cursor_tint if active else cursor_modulate

func _apply_party_portraits() -> void:
	for i in range(_portraits.size()):
		var b := _portraits[i]
		if party == null or i >= party.heroes.size():
			b.visible = false
			continue
		b.visible = true
		var h := party.heroes[i]
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
	var hero := _get_hero()
	var tree := hero.magic_tree if hero != null and ("magic_tree" in hero) else null
	var lvl := _hero_level(hero)

	for i in range(16):
		if i >= _slots.size():
			break
		var slot := _slots[i]
		var branch := i % 4
		var level_index := i / 4  # 0..3 (rows)
		var unlock: SpellUnlock = null
		if tree != null:
			unlock = tree.get_unlock(branch, level_index)

		if unlock == null or unlock.enabled == false:
			slot.set_state(null, false, true)
			continue

		var is_locked := true
		if lvl >= unlock.required_level and unlock.required_item_id == "" and unlock.required_flag == "":
			is_locked = false
		slot.set_state(unlock.spell, true, is_locked)

func _show_selected_spell() -> void:
	if desc_text == null or spell_name == null:
		return

	if _slots.is_empty() or _slot_idx >= _slots.size():
		spell_name.text = ""
		desc_text.text = ""
		if spell_icon: spell_icon.texture = null
		return

	var s := _slots[_slot_idx]
	if not s.exists:
		spell_name.text = "???"
		desc_text.bbcode_enabled = true
		desc_text.text = "Этот слот недоступен для этого героя."
		if spell_icon: spell_icon.texture = null
		return

	if s.locked or s.spell == null:
		spell_name.text = "???"
		desc_text.bbcode_enabled = true
		desc_text.text = "Заклинание ещё не открыто."
		if spell_icon: spell_icon.texture = null
		return

	var sp := s.spell
	spell_name.text = sp.title
	if spell_icon: spell_icon.texture = sp.icon

	desc_text.bbcode_enabled = true
	var elem := SpellData.Element.keys()[int(sp.element)]
	var eff := SpellData.EffectType.keys()[int(sp.effect_type)]
	desc_text.text = "%s\n\n[b]MP:[/b] %d\n[b]Element:[/b] %s\n[b]Type:[/b] %s" % [
		sp.description,
		sp.mp_cost,
		elem,
		eff
	]
