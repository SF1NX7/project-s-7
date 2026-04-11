extends Control
class_name EquipScreen

signal closed
signal request_equip_pick(hero_idx: int, slot: ItemData.EquipSlot)
signal request_unequip(hero_idx: int, slot: ItemData.EquipSlot, item: ItemData)

@export var cursor_modulate: Color = Color(1, 1, 1, 1)
@export var cursor_tint: Color = Color(1, 1, 0.85, 1)

@export_group("Data")
@export var party: PartyData

@onready var party_bar: Control = $Background/PartyBar
@onready var equip_slots_root: Control = $Background/EquipSlots
@onready var stats_text: RichTextLabel = $Background/StatsPanel/StatsText

var _portraits: Array[BaseButton] = []

var _slot_head: BaseButton
var _slot_armor: BaseButton
var _slot_boots: BaseButton
var _slot_weapon: BaseButton
var _slot_ring: BaseButton

enum EquipFocus { PARTY, SLOTS }
var _focus: EquipFocus = EquipFocus.PARTY
var _hero_idx: int = 0

enum SlotPos { CLOTHES_HEAD, CLOTHES_ARMOR, CLOTHES_BOOTS, WEAPON, RING }
var _slot_pos: SlotPos = SlotPos.CLOTHES_HEAD
var _last_clothes: SlotPos = SlotPos.CLOTHES_HEAD

# per hero -> per slot -> item
var _equipped := {} # Dictionary[int, Dictionary[int, ItemData]]


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
	_select_hero(clampi(_hero_idx, 0, max(_portraits.size() - 1, 0)))
	_update_stats()


func close() -> void:
	visible = false
	set_process_unhandled_input(false)


func set_equipped_item(hero_idx: int, slot: ItemData.EquipSlot, item: ItemData) -> void:
	# If we are replacing an already equipped item, return the old one to inventory.
	var old_item := _get_equipped_item(hero_idx, slot)
	if old_item != null and item != null and old_item != item:
		request_unequip.emit(hero_idx, slot, old_item)

	if not _equipped.has(hero_idx):
		_equipped[hero_idx] = {}

	_equipped[hero_idx][int(slot)] = item
	_apply_slot_visual(slot, item)
	_update_stats()


func _get_equipped_item(hero_idx: int, slot: ItemData.EquipSlot) -> ItemData:
	if not _equipped.has(hero_idx):
		return null
	return _equipped[hero_idx].get(int(slot), null)


func _collect_nodes() -> void:
	_portraits.clear()
	for c in party_bar.get_children():
		if c is BaseButton:
			_portraits.append(c)

	_apply_party_portraits()

	_slot_head = equip_slots_root.get_node_or_null("SlotHead") as BaseButton
	_slot_armor = equip_slots_root.get_node_or_null("SlotArmor") as BaseButton
	_slot_boots = equip_slots_root.get_node_or_null("SlotBoots") as BaseButton
	_slot_weapon = equip_slots_root.get_node_or_null("SlotWeapon") as BaseButton
	_slot_ring = equip_slots_root.get_node_or_null("SlotRing") as BaseButton

	for s in [ItemData.EquipSlot.HEAD, ItemData.EquipSlot.ARMOR, ItemData.EquipSlot.BOOTS, ItemData.EquipSlot.WEAPON, ItemData.EquipSlot.RING]:
		_apply_slot_visual(s, _get_equipped_item(_hero_idx, s))


func _apply_party_portraits() -> void:
	for btn in _portraits:
		btn.visible = true
	if party == null or party.heroes.is_empty():
		return
	for i in range(min(_portraits.size(), party.heroes.size())):
		var btn: BaseButton = _portraits[i]
		var hero: HeroData = party.heroes[i]
		if hero == null or hero.portrait == null:
			continue
		if btn is TextureButton:
			(btn as TextureButton).texture_normal = hero.portrait


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		if _focus == EquipFocus.SLOTS:
			_set_focus(EquipFocus.PARTY)
			_update_party_highlight()
			get_viewport().set_input_as_handled()
			return
		close()
		closed.emit()
		get_viewport().set_input_as_handled()
		return

	# Unequip action (bind unequip to R in Input Map)
	if _focus == EquipFocus.SLOTS and event.is_action_pressed("unequip"):
		var slot := _slotpos_to_equipslot(_slot_pos)
		var it := _get_equipped_item(_hero_idx, slot)
		if it != null:
			request_unequip.emit(_hero_idx, slot, it)
			set_equipped_item(_hero_idx, slot, null)
		get_viewport().set_input_as_handled()
		return

	# Confirm (E)
	if event.is_action_pressed("action") or event.is_action_pressed("ui_accept"):
		if _focus == EquipFocus.PARTY:
			_set_focus(EquipFocus.SLOTS)
			_select_slot_pos(_last_clothes)
		else:
			request_equip_pick.emit(_hero_idx, _slotpos_to_equipslot(_slot_pos))
		get_viewport().set_input_as_handled()
		return

	if _focus == EquipFocus.PARTY:
		_handle_party_nav(event)
	else:
		_handle_slots_nav(event)


func _slotpos_to_equipslot(p: SlotPos) -> ItemData.EquipSlot:
	match p:
		SlotPos.CLOTHES_HEAD: return ItemData.EquipSlot.HEAD
		SlotPos.CLOTHES_ARMOR: return ItemData.EquipSlot.ARMOR
		SlotPos.CLOTHES_BOOTS: return ItemData.EquipSlot.BOOTS
		SlotPos.WEAPON: return ItemData.EquipSlot.WEAPON
		SlotPos.RING: return ItemData.EquipSlot.RING
		_: return ItemData.EquipSlot.NONE


func _handle_party_nav(event: InputEvent) -> void:
	if party == null or party.heroes.is_empty():
		return
	if event.is_action_pressed("move_left"):
		_select_hero(maxi(_hero_idx - 1, 0))
	elif event.is_action_pressed("move_right"):
		_select_hero(mini(_hero_idx + 1, party.heroes.size() - 1))
	get_viewport().set_input_as_handled()


func _handle_slots_nav(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_on_move_up()
	elif event.is_action_pressed("move_down"):
		_on_move_down()
	elif event.is_action_pressed("move_left"):
		_on_move_left()
	elif event.is_action_pressed("move_right"):
		_on_move_right()
	get_viewport().set_input_as_handled()


func _on_move_up() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_ARMOR: _select_slot_pos(SlotPos.CLOTHES_HEAD)
		SlotPos.CLOTHES_BOOTS: _select_slot_pos(SlotPos.CLOTHES_ARMOR)
		_: pass


func _on_move_down() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_HEAD: _select_slot_pos(SlotPos.CLOTHES_ARMOR)
		SlotPos.CLOTHES_ARMOR: _select_slot_pos(SlotPos.CLOTHES_BOOTS)
		_: pass


func _on_move_left() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_HEAD, SlotPos.CLOTHES_ARMOR, SlotPos.CLOTHES_BOOTS:
			_last_clothes = _slot_pos
			_select_slot_pos(SlotPos.WEAPON)
		SlotPos.RING:
			_select_slot_pos(_last_clothes)
		_: pass


func _on_move_right() -> void:
	match _slot_pos:
		SlotPos.CLOTHES_HEAD, SlotPos.CLOTHES_ARMOR, SlotPos.CLOTHES_BOOTS:
			_last_clothes = _slot_pos
			_select_slot_pos(SlotPos.RING)
		SlotPos.WEAPON:
			_select_slot_pos(_last_clothes)
		_: pass


func _set_focus(m: EquipFocus) -> void:
	_focus = m
	_update_party_highlight()
	_update_slots_highlight()
	_update_stats()


func _select_hero(i: int) -> void:
	if party == null or party.heroes.is_empty():
		_hero_idx = 0
		_update_party_highlight()
		_update_stats()
		return
	_hero_idx = clampi(i, 0, party.heroes.size() - 1)
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
		var active := (_focus == EquipFocus.PARTY and i == _hero_idx)
		b.self_modulate = cursor_tint if active else cursor_modulate


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


# Slot icon overlay: if child TextureRect named Icon exists, we use it.
func _set_slot_icon(btn: BaseButton, tex: Texture2D) -> void:
	if btn == null:
		return
	var icon_node := btn.get_node_or_null("Icon")
	if icon_node != null and icon_node is TextureRect:
		(icon_node as TextureRect).texture = tex
		return
	# fallback: do not erase placeholder when clearing
	if btn is TextureButton and tex != null:
		(btn as TextureButton).texture_normal = tex


func _apply_slot_visual(slot: ItemData.EquipSlot, item: ItemData) -> void:
	var b: BaseButton = null
	match slot:
		ItemData.EquipSlot.HEAD: b = _slot_head
		ItemData.EquipSlot.ARMOR: b = _slot_armor
		ItemData.EquipSlot.BOOTS: b = _slot_boots
		ItemData.EquipSlot.WEAPON: b = _slot_weapon
		ItemData.EquipSlot.RING: b = _slot_ring
	if b == null:
		return
	_set_slot_icon(b, item.icon if item != null else null)


# ------- Stats -------
func _get_hero_data(idx: int) -> HeroData:
	if party == null:
		return null
	if idx < 0 or idx >= party.heroes.size():
		return null
	return party.heroes[idx]


func _sum_equipment_bonuses(hero_idx: int) -> StatsBonus:
	var total := StatsBonus.new()
	for slot in [ItemData.EquipSlot.HEAD, ItemData.EquipSlot.ARMOR, ItemData.EquipSlot.BOOTS, ItemData.EquipSlot.WEAPON, ItemData.EquipSlot.RING]:
		var it := _get_equipped_item(hero_idx, slot)
		if it != null and it.bonuses != null:
			total.hp += it.bonuses.hp
			total.mp += it.bonuses.mp
			total.attack += it.bonuses.attack
			total.magic += it.bonuses.magic
			total.defense += it.bonuses.defense
			total.resistance += it.bonuses.resistance
			total.speed += it.bonuses.speed
			total.luck += it.bonuses.luck
	return total


func _format_line(stat_name: String, base: int, bonus: int) -> String:
	if bonus == 0:
		return "%s: %d" % [stat_name, base]
	var sign := "+" if bonus > 0 else "-"
	var btxt := "%s%d" % [sign, abs(bonus)]
	var col := "green" if bonus > 0 else "red"
	return "%s: %d [color=%s](%s)[/color]" % [stat_name, base, col, btxt]


func _update_stats() -> void:
	if stats_text == null:
		return
	var hero := _get_hero_data(_hero_idx)
	if hero == null:
		stats_text.bbcode_enabled = true
		stats_text.text = "[b]No HeroData[/b]\nAssign PartyData to EquipScreen."
		return

	var base_stats := hero.base_stats if hero.base_stats != null else StatsBonus.new()
	var eq := _sum_equipment_bonuses(_hero_idx)

	var header := "[center][b]%s (%s)[/b][/center]\n\n" % [hero.hero_name, hero.profession_name]
	var t := header
	t += "[table=2]"
	t += "[cell]%s[/cell][cell]%s[/cell]" % [_format_line("HP", base_stats.hp, eq.hp), _format_line("DEF", base_stats.defense, eq.defense)]
	t += "[cell]%s[/cell][cell]%s[/cell]" % [_format_line("MP", base_stats.mp, eq.mp), _format_line("RES", base_stats.resistance, eq.resistance)]
	t += "[cell]%s[/cell][cell]%s[/cell]" % [_format_line("ATK", base_stats.attack, eq.attack), _format_line("SPD", base_stats.speed, eq.speed)]
	t += "[cell]%s[/cell][cell]%s[/cell]" % [_format_line("MAG", base_stats.magic, eq.magic), _format_line("LUK", base_stats.luck, eq.luck)]
	t += "[/table]"
	stats_text.bbcode_enabled = true
	stats_text.text = t
