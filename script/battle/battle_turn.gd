extends Node
## First battle turn prototype. Reads existing HeroData and living units on the map.
## No battle actions, artificial enemies or permanent save mutations yet.

@export_group("References")
@export var units_path: NodePath = ^"../Units"
@export var cursor_path: NodePath = ^"../BattleCursor"
@export var party: PartyData = preload("res://data/items/party_data.tres")
@export var menu_path: NodePath = ^"../BattleMenu"

@export_group("Turn Rules")
@export var focus_cursor_on_active_unit: bool = true
@export var higher_speed_acts_first: bool = true

@export_group("Turn Indicator")
@export var show_turn_indicator: bool = true
@export var indicator_position: Vector2 = Vector2(8, 8)
@export_range(100, 360, 1) var indicator_width: int = 180
@export var indicator_background: Color = Color(0.09, 0.14, 0.25, 0.92)
@export var indicator_text_color: Color = Color.WHITE

signal active_unit_changed(unit: Node2D, hero: HeroData)
signal turn_completed(unit: Node2D, hero: HeroData)
signal enemy_turn_started(unit: Node2D, enemy_data: Resource)

var active_unit: Node2D
var active_hero: HeroData
var active_enemy_data: Resource
var _units: Node2D
var _cursor: Node2D
var _label: Label
var _panel: PanelContainer
var _roster: Array[Dictionary] = []
var _turn_index: int = -1
var _menu: Node
var _is_switching: bool = false
var _battle_stopped: bool = false
var _death_presentation_active: bool = false
var _enemy_turn_end_pending: bool = false

func _ready() -> void:
	_units = get_node_or_null(units_path) as Node2D
	_cursor = get_node_or_null(cursor_path) as Node2D
	if _units == null or _cursor == null:
		push_error("BattleTurn: Check Units Path and Cursor Path.")
		return
	_menu = get_node_or_null(menu_path)
	if _menu != null and _menu.has_signal("command_selected"):
		_menu.connect("command_selected", Callable(self, "_on_command_selected"))
	else:
		push_warning("BattleTurn: BattleMenu command signal not found. Check Menu Path.")
	_create_indicator()
	call_deferred("_start_first_turn")

func _start_first_turn() -> void:
	var roster: Array[Dictionary] = []
	if party == null:
		push_warning("BattleTurn: Party resource is missing.")
		return
	for child in _units.get_children():
		var unit := child as Node2D
		if unit == null:
			continue
		for hero in party.heroes:
			if hero != null and hero.hero_name == unit.name and int(hero.hp_current) > 0:
				var speed: int = 0
				if hero.base_stats != null:
					speed = hero.base_stats.speed
				roster.append({"unit": unit, "hero": hero, "enemy": null, "speed": speed})
				break
	for child in _units.get_children():
		var enemy_unit := child as Node2D
		if enemy_unit == null or not enemy_unit.is_in_group(&"battle_enemies") or bool(enemy_unit.get_meta("battle_defeated", false)):
			continue
		var enemy_entry: Resource = enemy_unit.get_meta("enemy_data", null) as Resource
		var enemy_speed: int = _enemy_int(enemy_entry, ["speed"], 1)
		roster.append({"unit": enemy_unit, "hero": null, "enemy": enemy_entry, "speed": enemy_speed})
	if roster.is_empty():
		push_warning("BattleTurn: No deployed heroes found in Units.")
		return
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["speed"] == b["speed"]:
			return _party_index(a["hero"]) < _party_index(b["hero"])
		if higher_speed_acts_first:
			return a["speed"] > b["speed"]
		return a["speed"] < b["speed"]
	)
	_roster = roster
	_turn_index = 0
	_activate_current_turn()

func _on_command_selected(command: String) -> void:
	if _battle_stopped or _death_presentation_active or command != "defend" or _is_switching or active_unit == null or active_enemy_data != null:
		return
	if _menu != null and _menu.get("is_open") != true:
		return
	_is_switching = true
	if _menu != null and _menu.has_method("close_menu"):
		_menu.call("close_menu")
	turn_completed.emit(active_unit, active_hero)
	call_deferred("_next_turn")


func _next_turn() -> void:
	if _battle_stopped or _death_presentation_active or _roster.is_empty():
		_is_switching = false
		return
	# Skip removed / defeated units without changing the order of survivors.
	for i in range(_roster.size()):
		_turn_index = (_turn_index + 1) % _roster.size()
		var candidate: Variant = _roster[_turn_index].get("unit")
		if _unit_is_alive(candidate):
			_activate_current_turn()
			_is_switching = false
			return
	active_unit = null
	active_hero = null
	active_enemy_data = null
	_update_indicator()
	_is_switching = false


func finish_enemy_turn() -> void:
	if _battle_stopped:
		return
	if _death_presentation_active:
		_enemy_turn_end_pending = true
		return
	if _is_switching or not is_instance_valid(active_unit) or active_enemy_data == null:
		return
	_is_switching = true
	turn_completed.emit(active_unit, null)
	call_deferred("_next_turn")


func _activate_current_turn() -> void:
	if _battle_stopped:
		return
	if _turn_index < 0 or _turn_index >= _roster.size():
		return
	var candidate: Variant = _roster[_turn_index].get("unit")
	if not _unit_is_alive(candidate):
		call_deferred("_next_turn")
		return
	active_unit = candidate as Node2D
	active_hero = _roster[_turn_index]["hero"] as HeroData
	active_enemy_data = _roster[_turn_index]["enemy"] as Resource
	_update_indicator()
	if focus_cursor_on_active_unit:
		_focus_cursor()
	active_unit_changed.emit(active_unit, active_hero)
	if active_enemy_data != null:
		enemy_turn_started.emit(active_unit, active_enemy_data)



## Удержать камеру на погибающем бойце до завершения растворения.
## Пока активен этот режим, ход врага не переключается на следующего.
func begin_death_presentation(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	_death_presentation_active = true
	if focus_cursor_on_active_unit:
		_focus_cursor(unit)


## Отпустить камеру после растворения и дополнительной паузы.
## Если ИИ уже запросил конец хода, выполняем его только сейчас.
func end_death_presentation() -> void:
	_death_presentation_active = false
	if _battle_stopped:
		_enemy_turn_end_pending = false
		return
	if _enemy_turn_end_pending:
		_enemy_turn_end_pending = false
		finish_enemy_turn()

func _party_index(hero: HeroData) -> int:
	if party == null:
		return 999
	return party.heroes.find(hero)

func _focus_cursor(unit_override: Node2D = null) -> void:
	var focused: Node2D = unit_override if is_instance_valid(unit_override) else active_unit
	if not is_instance_valid(focused) or _cursor == null:
		return
	var cell_size: int = int(_cursor.get("cell_size"))
	if cell_size <= 0:
		return
	var origin: Vector2 = _cursor.get("grid_origin")
	var first: Vector2i = _cursor.get("first_cell")
	var base: Vector2 = _cursor.get_parent().to_global(origin)
	var offset: Vector2 = focused.global_position - base
	var cell := first + Vector2i(floori(offset.x / float(cell_size)), floori(offset.y / float(cell_size)))
	var min_cell: Vector2i = first
	var grid_size: Vector2i = _cursor.get("grid_size")
	var max_cell: Vector2i = first + grid_size - Vector2i.ONE
	cell = Vector2i(clampi(cell.x, min_cell.x, max_cell.x), clampi(cell.y, min_cell.y, max_cell.y))
	_cursor.set("selected_cell", cell)
	if _cursor.has_method("_update_cursor"):
		_cursor.call("_update_cursor")
	if _cursor.has_signal("cell_changed"):
		_cursor.emit_signal("cell_changed", cell)

func _create_indicator() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	canvas.name = "TurnUI"
	add_child(canvas)

	_panel = PanelContainer.new()
	_panel.name = "TurnIndicator"
	_panel.position = indicator_position
	_panel.custom_minimum_size = Vector2(float(indicator_width), 34)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = indicator_background
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(_panel)

	_label = Label.new()
	_label.name = "TurnText"
	_label.add_theme_color_override("font_color", indicator_text_color)
	_panel.add_child(_label)
	_update_indicator()

func _update_indicator() -> void:
	if _panel == null or _label == null:
		return
	_panel.visible = show_turn_indicator
	if active_enemy_data != null:
		_label.text = "Ход врага: %s" % active_unit.name
	elif active_hero == null:
		_label.text = "Ожидание хода"
	else:
		var speed: int = active_hero.base_stats.speed if active_hero.base_stats != null else 0
		_label.text = "Ход: %s  |  Speed: %d" % [active_hero.hero_name, speed]

func _enemy_int(entry: Resource, keys: Array[String], fallback: int) -> int:
	if entry == null:
		return fallback
	for key in keys:
		for property in entry.get_property_list():
			if String(property["name"]) == key:
				var value: Variant = entry.get(key)
				if value is int or value is float:
					return int(value)
	var stats: Variant = null
	for property in entry.get_property_list():
		if String(property["name"]) == "base_stats":
			stats = entry.get("base_stats")
			break
	if stats is Resource:
		for key in keys:
			for property in (stats as Resource).get_property_list():
				if String(property["name"]) == key:
					return int((stats as Resource).get(key))
	return fallback

## Вызывается из BattleCombat, когда битва завершилась.
func stop_battle() -> void:
	_battle_stopped = true
	_is_switching = true
	if _menu != null and _menu.has_method("close_menu"):
		_menu.call("close_menu")
	active_unit = null
	active_hero = null
	active_enemy_data = null
	_update_indicator()


## Доступность бойца для участия в следующих ходах.
func _unit_is_alive(unit: Variant) -> bool:
	if not is_instance_valid(unit):
		return false
	if not (unit is Node2D):
		return false
	if not unit.is_inside_tree():
		return false
	if bool(unit.get_meta("battle_defeated", false)):
		return false
	if unit.is_in_group(&"battle_enemies"):
		return int(unit.get_meta("hp_current", 1)) > 0
	if party != null:
		for hero in party.heroes:
			if hero != null and hero.hero_name == unit.name:
				return int(hero.hp_current) > 0
	return false
