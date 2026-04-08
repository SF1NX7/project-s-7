extends Control
class_name EquipScreen

signal closed

@export var cursor_modulate: Color = Color(1, 1, 1, 1)
@export var cursor_tint: Color = Color(1, 1, 0.6, 1)

@onready var party_bar: Control = $Background/PartyBar
@onready var equip_slots_root: Control = $Background/EquipSlots
@onready var stats_text: RichTextLabel = $Background/StatsPanel/StatsText

var _portraits: Array[BaseButton] = []

# Slot buttons (expected names)
var _slot_head: BaseButton
var _slot_armor: BaseButton
var _slot_boots: BaseButton
var _slot_weapon: BaseButton
var _slot_ring: BaseButton

enum EquipFocus { PARTY, SLOTS }
var _focus: EquipFocus = EquipFocus.PARTY

var _hero_idx: int = 0

# Your exact navigation model:
# - Clothes column: Head -> Armor -> Boots (W/S)
# - A from clothes -> Weapon, D from clothes -> Ring
# - D from Weapon -> back to clothes (same row as last clothes)
# - A from Ring -> back to clothes (same row as last clothes)
enum SlotPos { CLOTHES_HEAD, CLOTHES_ARMOR, CLOTHES_BOOTS, WEAPON, RING }
var _slot_pos: SlotPos = SlotPos.CLOTHES_HEAD
var _last_clothes: SlotPos = SlotPos.CLOTHES_HEAD


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)

	_collect_nodes()

	_set_focus(EquipFocus.PARTY)
	_select_hero(0)
	_select_slot_pos(SlotPos.CLOTHES_HEAD)
	_update_stats()


func open() -> void:
	visible = true
	set_process_unhandled_input(true)

	_collect_nodes()

	_set_focus(EquipFocus.PARTY)
	_select_hero(clampi(_hero_idx, 0, _portraits.size() - 1))
	_clear_slots_highlight()
	_update_stats()


func close() -> void:
	visible = false
	set_process_unhandled_input(false)


func _collect_nodes() -> void:
	_portraits.clear()

	for c in party_bar.get_children():
		if c is BaseButton:
			_portraits.append(c)

	# Cache slot refs by name (stable)
	_slot_head = equip_slots_root.get_node_or_null("SlotHead") as BaseButton
	_slot_armor = equip_slots_root.get_node_or_null("SlotArmor") as BaseButton
	_slot_boots = equip_slots_root.get_node_or_null("SlotBoots") as BaseButton
	_slot_weapon = equip_slots_root.get_node_or_null("SlotWeapon") as BaseButton
	_slot_ring = equip_slots_root.get_node_or_null("SlotRing") as BaseButton


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Back / Close (Tab or Esc)
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		if _focus == EquipFocus.SLOTS:
			_set_focus(EquipFocus.PARTY)
			_clear_slots_highlight()
			_update_party_highlight()
			get_viewport().set_input_as_handled()
			return
		else:
			close()
			closed.emit()
			get_viewport().set_input_as_handled()
			return

	# Confirm (E)
	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		if _focus == EquipFocus.PARTY:
			_set_focus(EquipFocus.SLOTS)
			# Start on last clothes row (feels natural)
			_select_slot_pos(_last_clothes)
			get_viewport().set_input_as_handled()
			return
		else:
			_update_stats()
			get_viewport().set_input_as_handled()
			return

	# Navigation
	if _focus == EquipFocus.PARTY:
		_handle_party_nav(event)
	else:
		_handle_slots_nav(event)


func _handle_party_nav(event: InputEvent) -> void:
	if _portraits.is_empty():
		return

	if event.is_action_pressed("move_left"):
		_select_hero(maxi(_hero_idx - 1, 0))
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		_select_hero(mini(_hero_idx + 1, _portraits.size() - 1))
		get_viewport().set_input_as_handled()
		return


func _handle_slots_nav(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_on_move_up()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_down"):
		_on_move_down()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_left"):
		_on_move_left()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		_on_move_right()
		get_viewport().set_input_as_handled()
		return


func _on_move_up() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_ARMOR:
			_select_slot_pos(SlotPos.CLOTHES_HEAD)
		SlotPos.CLOTHES_BOOTS:
			_select_slot_pos(SlotPos.CLOTHES_ARMOR)
		_:
			pass


func _on_move_down() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_HEAD:
			_select_slot_pos(SlotPos.CLOTHES_ARMOR)
		SlotPos.CLOTHES_ARMOR:
			_select_slot_pos(SlotPos.CLOTHES_BOOTS)
		_:
			pass


func _on_move_left() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_HEAD, SlotPos.CLOTHES_ARMOR, SlotPos.CLOTHES_BOOTS:
			_last_clothes = _slot_pos
			_select_slot_pos(SlotPos.WEAPON)
		SlotPos.RING:
			_select_slot_pos(_last_clothes)
		_:
			pass


func _on_move_right() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_HEAD, SlotPos.CLOTHES_ARMOR, SlotPos.CLOTHES_BOOTS:
			_last_clothes = _slot_pos
			_select_slot_pos(SlotPos.RING)
		SlotPos.WEAPON:
			_select_slot_pos(_last_clothes)
		_:
			pass


func _set_focus(m: EquipFocus) -> void:
	_focus = m
	_update_party_highlight()
	_update_slots_highlight()
	_update_stats()


func _select_hero(i: int) -> void:
	if _portraits.is_empty():
		return
	_hero_idx = clampi(i, 0, _portraits.size() - 1)
	_update_party_highlight()
	_update_stats()


func _select_slot_pos(p: SlotPos) -> void:
	_slot_pos = p

	if p in [SlotPos.CLOTHES_HEAD, SlotPos.CLOTHES_ARMOR, SlotPos.CLOTHES_BOOTS]:
		_last_clothes = p

	_update_slots_highlight()
	_update_stats()


func _current_slot_button() -> BaseButton:
	match _slot_pos:
		SlotPos.CLOTHES_HEAD: return _slot_head
		SlotPos.CLOTHES_ARMOR: return _slot_armor
		SlotPos.CLOTHES_BOOTS: return _slot_boots
		SlotPos.WEAPON: return _slot_weapon
		SlotPos.RING: return _slot_ring
		_: return null


func _update_party_highlight() -> void:
	for i in range(_portraits.size()):
		var b := _portraits[i]
		b.self_modulate = cursor_tint if (_focus == EquipFocus.PARTY and i == _hero_idx) else cursor_modulate


func _update_slots_highlight() -> void:
	_clear_slots_highlight()
	if _focus != EquipFocus.SLOTS:
		return

	var b := _current_slot_button()
	if b:
		b.self_modulate = cursor_tint


func _clear_slots_highlight() -> void:
	for b in [_slot_head, _slot_armor, _slot_boots, _slot_weapon, _slot_ring]:
		if b:
			b.self_modulate = cursor_modulate


func _update_stats() -> void:
	if stats_text == null:
		return

	var hero_name := "Hero %d" % (_hero_idx + 1)
	var slot_name := ""
	var b := _current_slot_button()
	if b:
		slot_name = b.name

	stats_text.bbcode_enabled = true
	stats_text.text = "[b]%s[/b]\\nSelected: %s" % [hero_name, slot_name]
