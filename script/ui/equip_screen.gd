extends Control
class_name EquipScreen

signal closed

# Colors for highlighting (tweak in Inspector)
@export var cursor_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var cursor_tint: Color = Color(1.0, 1.0, 0.6, 1.0) # highlighted element

@onready var party_bar: Control = $Background/PartyBar
@onready var equip_slots_root: Control = $Background/EquipSlots
@onready var stats_text: RichTextLabel = $Background/StatsPanel/StatsText

# PartyBar children: Portrait1..Portrait7 (TextureButton)
# EquipSlots children: SlotHead, SlotArmor, SlotBoots, SlotWeapon, SlotRing (TextureButton)
var _portraits: Array[BaseButton] = []
var _slots: Array[BaseButton] = []

enum EquipFocus { PARTY, SLOTS }
var _focus: EquipFocus = EquipFocus.PARTY

var _hero_idx: int = 0
var _slot_idx: int = 0


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)

	_collect_nodes()

	_set_focus(EquipFocus.PARTY)
	_select_hero(0)
	_select_slot(0)
	_update_stats()


func open() -> void:
	visible = true
	set_process_unhandled_input(true)

	_collect_nodes() # in case nodes were edited

	_set_focus(EquipFocus.PARTY)
	_select_hero(clampi(_hero_idx, 0, _portraits.size() - 1))
	_clear_slots_highlight()
	_update_stats()


func close() -> void:
	visible = false
	set_process_unhandled_input(false)


func _collect_nodes() -> void:
	_portraits.clear()
	_slots.clear()

	for c in party_bar.get_children():
		if c is BaseButton:
			_portraits.append(c)

	var by_name := {}
	for c in equip_slots_root.get_children():
		if c is BaseButton:
			by_name[c.name] = c

	var order := ["SlotHead", "SlotArmor", "SlotBoots", "SlotWeapon", "SlotRing"]
	for n in order:
		if by_name.has(n):
			_slots.append(by_name[n])

	if _slots.is_empty():
		for c in equip_slots_root.get_children():
			if c is BaseButton:
				_slots.append(c)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Back / Close
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		if _focus == EquipFocus.SLOTS:
			# Step back: Slots -> PartyBar
			_set_focus(EquipFocus.PARTY)
			_clear_slots_highlight()
			_update_party_highlight()
			get_viewport().set_input_as_handled()
			return
		else:
			# PartyBar -> close (return to cross menu)
			close()
			closed.emit()
			get_viewport().set_input_as_handled()
			return

	# Confirm
	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		if _focus == EquipFocus.PARTY:
			# Confirm hero -> go to slots
			_set_focus(EquipFocus.SLOTS)
			_select_slot(clampi(_slot_idx, 0, _slots.size() - 1))
			get_viewport().set_input_as_handled()
			return
		else:
			# Confirm slot (later: open item list / equip)
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
	if _slots.is_empty():
		return

	var head := _index_of_slot_name("SlotHead")
	var armor := _index_of_slot_name("SlotArmor")
	var boots := _index_of_slot_name("SlotBoots")
	var weapon := _index_of_slot_name("SlotWeapon")
	var ring := _index_of_slot_name("SlotRing")

	var next := _slot_idx

	if event.is_action_pressed("move_up"):
		match _slot_idx:
			weapon, armor, ring:
				next = head if head != -1 else _slot_idx
			boots:
				next = weapon if weapon != -1 else _slot_idx
			_:
				pass
		_select_slot(next)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_down"):
		match _slot_idx:
			head:
				next = weapon if weapon != -1 else _slot_idx
			weapon, armor, ring:
				next = boots if boots != -1 else _slot_idx
			_:
				pass
		_select_slot(next)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_left"):
		match _slot_idx:
			weapon:
				next = armor if armor != -1 else _slot_idx
			ring:
				next = weapon if weapon != -1 else _slot_idx
			_:
				pass
		_select_slot(next)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		match _slot_idx:
			weapon:
				next = ring if ring != -1 else _slot_idx
			armor:
				next = weapon if weapon != -1 else _slot_idx
			_:
				pass
		_select_slot(next)
		get_viewport().set_input_as_handled()
		return


func _index_of_slot_name(n: String) -> int:
	for i in range(_slots.size()):
		if _slots[i].name == n:
			return i
	return -1


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


func _select_slot(i: int) -> void:
	if _slots.is_empty():
		return
	_slot_idx = clampi(i, 0, _slots.size() - 1)
	_update_slots_highlight()
	_update_stats()


func _update_party_highlight() -> void:
	for i in range(_portraits.size()):
		var b := _portraits[i]
		b.self_modulate = cursor_tint if (_focus == EquipFocus.PARTY and i == _hero_idx) else cursor_modulate


func _update_slots_highlight() -> void:
	if _focus != EquipFocus.SLOTS:
		_clear_slots_highlight()
		return

	for i in range(_slots.size()):
		var b := _slots[i]
		b.self_modulate = cursor_tint if i == _slot_idx else cursor_modulate


func _clear_slots_highlight() -> void:
	for b in _slots:
		b.self_modulate = cursor_modulate


func _update_stats() -> void:
	if stats_text == null:
		return

	var hero_name := "Hero %d" % (_hero_idx + 1)
	var slot_name := "Slot"
	if _slots.size() > 0:
		slot_name = _slots[_slot_idx].name

	stats_text.bbcode_enabled = true
	stats_text.text = "[b]%s[/b]\nSelected: %s" % [hero_name, slot_name]
