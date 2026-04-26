extends Area2D
class_name PartyHpHotspot

# PartyHpHotspot v5
# Adds Inspector option:
# - Interact From Any Side
#
# If OFF, Player.gd will use its normal "must face object" check.
# If ON, E works from any side while overlapping the Area.

@export_group("Party")
@export var party: PartyData
@export var affect_all_heroes: bool = false
@export var hero_index: int = 0

@export_group("Activation")
@export var activate_on_interact: bool = true
@export var activate_on_touch: bool = false
@export var interact_from_any_side: bool = false
@export var one_time: bool = false
@export var used: bool = false

@export_group("HP Change")
@export var hp_delta: int = -3
@export var min_hp: int = 1

@export_group("Dialogue")
@export_multiline var message_lines: Array[String] = [
	"Холодная вода ослабила вас."
]
@export_multiline var repeat_message_lines: Array[String] = [
	"Здесь больше ничего не происходит."
]
@export var portrait: Texture2D
@export var line_font_size: int = 36
@export var center_text: bool = true

@export_group("Debug")
@export var print_debug: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if print_debug:
		print("PartyHpHotspot v5 READY: ", get_path())
		print("Party assigned: ", party != null)
		if party != null:
			print("Assigned Party heroes: ", party.heroes.size())
		print("activate_on_interact=", activate_on_interact)
		print("activate_on_touch=", activate_on_touch)
		print("interact_from_any_side=", interact_from_any_side)


func can_interact_from_any_side() -> bool:
	return interact_from_any_side


func interact(_player: Node = null) -> void:
	if not activate_on_interact:
		if print_debug:
			print("PartyHpHotspot: interact ignored because activate_on_interact = false")
		return

	_activate("interact", _player)


func _on_body_entered(body: Node2D) -> void:
	if print_debug:
		print("PartyHpHotspot: body entered -> ", body.name, " path=", body.get_path())

	if activate_on_touch and body.is_in_group("player"):
		_activate("body_entered", body)


func _on_area_entered(area: Area2D) -> void:
	if print_debug:
		print("PartyHpHotspot: area entered -> ", area.name, " path=", area.get_path())

	if not activate_on_touch:
		return

	# Player usually has InteractionArea as child.
	if area.name == "InteractionArea":
		var parent: Node = area.get_parent()
		if parent != null and parent.is_in_group("player"):
			_activate("area_entered", parent)


func _activate(source: String, activator: Node = null) -> void:
	if print_debug:
		print("PartyHpHotspot: ACTIVATE source=", source, " activator=", activator, " used=", used, " hp_delta=", hp_delta)

	if one_time and used:
		_show_lines(repeat_message_lines)
		return

	var p: PartyData = _get_valid_party_data()
	if p == null:
		push_warning("PartyHpHotspot: valid PartyData with heroes was not found.")
		_show_lines([
			"DEBUG: PartyData не найден или в нём нет героев.",
			"Назначь правильный party_data.tres в поле Party."
		])
		return

	if print_debug:
		print("PartyHpHotspot: using PartyData with heroes=", p.heroes.size())

	if affect_all_heroes:
		for i in range(p.heroes.size()):
			_apply_hp_delta_to_hero(p.heroes[i], i)
	else:
		var idx: int = clampi(hero_index, 0, p.heroes.size() - 1)
		_apply_hp_delta_to_hero(p.heroes[idx], idx)

	used = true
	_refresh_status_screens()
	_show_lines(message_lines)


func _get_valid_party_data() -> PartyData:
	if party != null and not party.heroes.is_empty():
		return party

	var found: PartyData = _find_party_data_with_heroes()
	if found != null:
		return found

	return null


func _find_party_data_with_heroes() -> PartyData:
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
				if print_debug:
					print("PartyHpHotspot: found PartyData on node: ", root.get_path())
				return pd

	for child in root.get_children():
		var found: PartyData = _search_party_recursive(child)
		if found != null:
			return found

	return null


func _apply_hp_delta_to_hero(hero: HeroData, index: int) -> void:
	if hero == null:
		push_warning("PartyHpHotspot: hero is null at index %d" % index)
		return

	var max_hp: int = _get_hero_max_hp(hero)
	if max_hp <= 0:
		push_warning("PartyHpHotspot: hero '%s' has max HP <= 0." % hero.hero_name)
		return

	var cur_hp: int = int(hero.hp_current)

	# In this project, 0 usually means "not initialized yet".
	# For HP events, treat it as full HP first.
	if cur_hp <= 0:
		cur_hp = max_hp

	var new_hp: int = clampi(cur_hp + hp_delta, min_hp, max_hp)
	hero.hp_current = new_hp

	if print_debug:
		print("PartyHpHotspot: hero[%d] %s HP %d -> %d / %d" % [
			index,
			hero.hero_name,
			cur_hp,
			new_hp,
			max_hp
		])


func _get_hero_max_hp(hero: HeroData) -> int:
	if hero == null:
		return 0
	if hero.base_stats == null:
		return 0
	return int(hero.base_stats.hp)


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


func _show_lines(source: Array[String]) -> void:
	var lines: Array[String] = _format_lines(source)
	if lines.is_empty():
		return

	var dlg: Node = _find_dialogue_ui()
	if dlg == null or not dlg.has_method("start_dialogue"):
		push_warning("PartyHpHotspot: DialogueUI with start_dialogue() was not found.")
		return

	dlg.call("start_dialogue", lines, portrait)


func _format_lines(source: Array[String]) -> Array[String]:
	var out: Array[String] = []

	for raw_line in source:
		var text: String = str(raw_line).strip_edges()
		if text == "":
			continue

		if line_font_size > 0:
			text = "[font_size=%d]%s[/font_size]" % [line_font_size, text]

		if center_text:
			text = "[center]%s[/center]" % text

		out.append(text)

	return out


func _find_dialogue_ui() -> Node:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var dlg: Node = scene.find_child("DialogueUI", true, false)
		if dlg != null:
			return dlg

	return get_tree().root.find_child("DialogueUI", true, false)
