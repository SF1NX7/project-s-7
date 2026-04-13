extends Control
class_name StatusScreen

signal closed

@export_group("Data")
@export var party: PartyData
@export var show_empty_message: bool = true

# Display tuning (you can tweak in Inspector)
@export_group("Layout")
@export var left_column_pad: int = 0
@export var right_column_pad: int = 0
@export var show_level_on_own_line: bool = true

# Final tree:
# StatusScreen/Background
#   InfoPanel/InfoText
#   TalentPanel/...
#   Portrait
#   NameLabel

@onready var name_label: Label = $Background/NameLabel
@onready var portrait: TextureRect = $Background/Portrait
@onready var info_text: RichTextLabel = $Background/InfoPanel/InfoText
@onready var talent_icon: TextureRect = $Background/TalentPanel/TalentIconFrame/TalentIcon
@onready var talent_text: RichTextLabel = $Background/TalentPanel/TalentText

var _index: int = 0


func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)


func open() -> void:
	visible = true
	set_process_unhandled_input(true)
	_index = clampi(_index, 0, max(_hero_count() - 1, 0))
	_refresh()


func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_up"):
		_step(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_down"):
		_step(+1)
		get_viewport().set_input_as_handled()
		return


func _hero_count() -> int:
	if party == null:
		return 0
	return party.heroes.size()


func _step(dir: int) -> void:
	var n := _hero_count()
	if n <= 0:
		_refresh()
		return
	_index = (_index + dir) % n
	if _index < 0:
		_index += n
	_refresh()


func _get_hero() -> HeroData:
	if party == null:
		return null
	if _index < 0 or _index >= party.heroes.size():
		return null
	return party.heroes[_index]


func _clamp_current_to_max(cur: int, maxv: int) -> int:
	if maxv <= 0:
		return 0
	return clampi(cur, 0, maxv)


func _pad(n: int) -> String:
	# Add a little spacing using non-breaking spaces in BBCode.
	# RichTextLabel treats regular spaces normally; this helps align columns.
	var s := ""
	for i in range(max(n, 0)):
		s += " "
	return s


func _refresh() -> void:
	var hero := _get_hero()
	if hero == null:
		if show_empty_message:
			name_label.text = ""
			portrait.texture = null
			info_text.bbcode_enabled = true
			info_text.text = "[center][b]Нет персонажей[/b][/center]\nНазначь PartyData в инспекторе StatusScreen."
			talent_icon.texture = null
			talent_text.bbcode_enabled = true
			talent_text.text = ""
		return

	# Left header above portrait
	name_label.text = hero.hero_name
	portrait.texture = hero.portrait

	var bs := hero.base_stats if hero.base_stats != null else StatsBonus.new()

	var level := hero.level if "level" in hero else 1
	var xp := hero.xp if "xp" in hero else 0
	var xp_to_next := hero.xp_to_next if "xp_to_next" in hero else 100
	var hp_current := hero.hp_current if "hp_current" in hero else bs.hp
	var mp_current := hero.mp_current if "mp_current" in hero else bs.mp

	var talent_name := hero.talent_name if "talent_name" in hero else ""
	var talent_desc := hero.talent_desc if "talent_desc" in hero else ""
	var talent_icon_tex := hero.talent_icon if "talent_icon" in hero else null

	var max_hp := bs.hp
	var max_mp := bs.mp
	var cur_hp := _clamp_current_to_max(hp_current, max_hp)
	var cur_mp := _clamp_current_to_max(mp_current, max_mp)

	# --- Top block: Name (Class) centered ---
	var title := "[center][b]%s (%s)[/b][/center]\n" % [hero.hero_name, hero.profession_name]

	# --- Second line: EXP left + Level right (same row) ---
	# We use a 2-column table for perfect alignment.
	var exp_level := "[table=2]"
	exp_level += "[cell]%sEXP: %d / %d[/cell][cell][right]Level %d[/right][/cell]" % [_pad(left_column_pad), xp, xp_to_next, level]
	exp_level += "[/table]\n"

	# --- Stats: 2 columns, bigger labels look better with your font size ---
	var left := ""
	left += "%sHealth: %d / %d\n" % [_pad(left_column_pad), cur_hp, max_hp]
	left += "%sAttack: %d\n" % [_pad(left_column_pad), bs.attack]
	left += "%sDefense: %d\n" % [_pad(left_column_pad), bs.defense]
	left += "%sSpeed: %d\n" % [_pad(left_column_pad), bs.speed]

	var right := ""
	right += "%sMana: %d / %d\n" % [_pad(right_column_pad), cur_mp, max_mp]
	right += "%sMagic: %d\n" % [_pad(right_column_pad), bs.magic]
	right += "%sResistance: %d\n" % [_pad(right_column_pad), bs.resistance]
	right += "%sLuck: %d\n" % [_pad(right_column_pad), bs.luck]

	var stats := "[table=2]"
	stats += "[cell]%s[/cell][cell]%s[/cell]" % [left, right]
	stats += "[/table]"

	info_text.bbcode_enabled = true
	info_text.text = title + exp_level + stats

	# Talent
	talent_icon.texture = talent_icon_tex
	talent_text.bbcode_enabled = true
	if str(talent_name).strip_edges() == "" and str(talent_desc).strip_edges() == "":
		talent_text.text = "[b]Особый талант:[/b]\n—"
	else:
		talent_text.text = "[b]Особый талант: %s[/b]\n%s" % [talent_name, talent_desc]
