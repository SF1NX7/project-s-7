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

var active_unit: Node2D
var active_hero: HeroData
var _units: Node2D
var _cursor: Node2D
var _label: Label
var _panel: PanelContainer
var _roster: Array[Dictionary] = []
var _turn_index: int = -1
var _menu: Node
var _is_switching: bool = false

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
            if hero != null and hero.hero_name == unit.name:
                var speed: int = 0
                if hero.base_stats != null:
                    speed = hero.base_stats.speed
                roster.append({"unit": unit, "hero": hero, "speed": speed})
                break
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
    if command != "defend" or _is_switching or active_unit == null:
        return
    if _menu != null and _menu.get("is_open") != true:
        return
    _is_switching = true
    if _menu != null and _menu.has_method("close_menu"):
        _menu.call("close_menu")
    turn_completed.emit(active_unit, active_hero)
    call_deferred("_next_turn")


func _next_turn() -> void:
    if _roster.is_empty():
        _is_switching = false
        return
    # Skip removed / defeated units without changing the order of survivors.
    for i in range(_roster.size()):
        _turn_index = (_turn_index + 1) % _roster.size()
        var candidate := _roster[_turn_index]["unit"] as Node2D
        if is_instance_valid(candidate) and candidate.is_inside_tree():
            _activate_current_turn()
            _is_switching = false
            return
    active_unit = null
    active_hero = null
    _update_indicator()
    _is_switching = false


func _activate_current_turn() -> void:
    if _turn_index < 0 or _turn_index >= _roster.size():
        return
    active_unit = _roster[_turn_index]["unit"] as Node2D
    active_hero = _roster[_turn_index]["hero"] as HeroData
    _update_indicator()
    if focus_cursor_on_active_unit:
        _focus_cursor()
    active_unit_changed.emit(active_unit, active_hero)


func _party_index(hero: HeroData) -> int:
    if party == null:
        return 999
    return party.heroes.find(hero)

func _focus_cursor() -> void:
    if active_unit == null or _cursor == null:
        return
    var cell_size: int = int(_cursor.get("cell_size"))
    if cell_size <= 0:
        return
    var origin: Vector2 = _cursor.get("grid_origin")
    var first: Vector2i = _cursor.get("first_cell")
    var base: Vector2 = _cursor.get_parent().to_global(origin)
    var offset: Vector2 = active_unit.global_position - base
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
    if active_hero == null:
        _label.text = "Ожидание хода"
    else:
        var speed: int = active_hero.base_stats.speed if active_hero.base_stats != null else 0
        _label.text = "Ход: %s  |  Speed: %d" % [active_hero.hero_name, speed]
