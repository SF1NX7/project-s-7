extends Node
## Battle map hover UI. Attach to a child Node named BattleHover.
## Does not control turns, actions, or movement.

@export_group("Connections")
@export var cursor_path: NodePath = ^"../BattleCursor"
@export var units_path: NodePath = ^"../Units"
@export var movement_path: NodePath = ^"../BattleMove"
@export var turn_path: NodePath = ^"../BattleTurn"
@export var combat_path: NodePath = ^"../BattleCombat"
@export var party: PartyData = preload("res://data/items/party_data.tres")

@export_group("Highlight")
@export var highlight_enabled: bool = true
@export var highlight_color: Color = Color(1.0, 0.86, 0.35, 1.0)
@export_range(0.0, 1.0, 0.01) var highlight_strength: float = 0.55
@export_range(0.0, 12.0, 0.1) var pulse_speed: float = 3.0

@export_group("Info Panel")
@export var show_panel: bool = true
@export_range(80, 320, 1) var panel_width: int = 200
@export_range(48, 220, 1) var panel_height: int = 92
@export_range(0, 80, 1) var panel_margin: int = 10
@export_range(24, 96, 1) var portrait_size: int = 64
@export var panel_background: Color = Color(0.09, 0.14, 0.25, 0.94)
@export var text_color: Color = Color.WHITE

var _cursor: Node2D
var _units: Node2D
var _movement: Node
var _turn: Node
var _hovered: Node2D
var _hovered_sprite: CanvasItem
var _original_modulate: Color = Color.WHITE
var _elapsed: float = 0.0
var _last_movement_mode: bool = false
var _hud: PanelContainer
var _portrait: TextureRect
var _name: Label
var _hp: Label
var _mp: Label


func _ready() -> void:
    _cursor = get_node_or_null(cursor_path) as Node2D
    _units = get_node_or_null(units_path) as Node2D
    _movement = get_node_or_null(movement_path)
    _turn = get_node_or_null(turn_path)
    var combat: Node = get_node_or_null(combat_path)
    if combat != null and combat.has_signal("combat_resolved"):
        combat.connect("combat_resolved", Callable(self, "_on_combat_resolved"))
    if combat != null and combat.has_signal("unit_defeated"):
        combat.connect("unit_defeated", Callable(self, "_on_unit_defeated"))
    if _turn != null and _turn.has_signal("active_unit_changed"):
        _turn.connect("active_unit_changed", Callable(self, "_on_active_turn_unit_changed"))
    if _cursor == null or _units == null:
        push_error("BattleHover: Check Cursor Path and Units Path in Inspector.")
        set_process(false)
        return
    _build_hud()
    if _cursor.has_signal("cell_changed"):
        _cursor.connect("cell_changed", Callable(self, "_on_cell_changed"))
    call_deferred("_refresh_hover")


func _process(delta: float) -> void:
    var movement_now: bool = _movement != null and _movement.get("_movement_mode") == true
    if movement_now != _last_movement_mode:
        _last_movement_mode = movement_now
        _refresh_hover()
    if _hovered_sprite == null or not is_instance_valid(_hovered_sprite):
        return
    _elapsed += delta
    if highlight_enabled:
        var wave: float = (sin(_elapsed * pulse_speed * TAU) + 1.0) * 0.5
        var amount: float = highlight_strength * (0.55 + wave * 0.45)
        _hovered_sprite.modulate = _original_modulate.lerp(highlight_color, amount)


func _on_cell_changed(_cell: Vector2i) -> void:
    _refresh_hover()


func _on_active_turn_unit_changed(_unit: Node2D, _hero: HeroData) -> void:
    _refresh_hover()


func _refresh_hover() -> void:
    if not is_instance_valid(_cursor) or not is_instance_valid(_units):
        return
    var cell_size: int = int(_cursor.get("cell_size"))
    var first_cell: Vector2i = _cursor.get("first_cell")
    var selected_cell: Vector2i = _cursor.get("selected_cell")
    var grid_origin: Vector2 = _cursor.get("grid_origin")

    # Logical cell position is independent of the cursor's visual sliding.
    # Grid coordinates are relative to the cursor parent, just like cursor.position.
    var cell_local: Vector2 = grid_origin + Vector2(selected_cell - first_cell) * float(cell_size)
    var cell_world: Vector2 = _cursor.get_parent().to_global(cell_local)
    var cell_rect := Rect2(cell_world, Vector2.ONE * float(cell_size))
    var target: Node2D = null
    var in_movement_mode: bool = _movement != null and _movement.get("_movement_mode") == true
    if _turn != null and _turn.get("active_enemy_data") != null:
        var enemy_active := _turn.get("active_unit") as Node2D
        if is_instance_valid(enemy_active):
            target = enemy_active
    elif in_movement_mode:
        var active: Node2D = _movement.get("_unit") as Node2D
        if is_instance_valid(active):
            target = active
    if not in_movement_mode and target == null:
        for child in _units.get_children():
            var unit := child as Node2D
            if unit == null:
                continue
            # Characters occupy the cell under their feet, regardless of sprite height.
            if cell_rect.grow(0.01).has_point(unit.global_position):
                target = unit
                break
    if target != _hovered:
        _clear_highlight()
        _hovered = target
        if _hovered != null:
            _hovered_sprite = _hovered.get_node_or_null("AnimatedSprite2D") as CanvasItem
            if _hovered_sprite == null:
                _hovered_sprite = _hovered.get_node_or_null("Sprite2D") as CanvasItem
            if _hovered_sprite != null:
                _original_modulate = _hovered_sprite.modulate
            _elapsed = 0.0
    _cursor.set("cursor_visible", not in_movement_mode and target == null)
    _cursor.queue_redraw()
    _update_panel()


func _clear_highlight() -> void:
    if _hovered_sprite != null and is_instance_valid(_hovered_sprite):
        _hovered_sprite.modulate = _original_modulate
    _hovered_sprite = null


func _update_panel() -> void:
    _hud.visible = show_panel and _hovered != null
    if _hovered == null:
        return

    if _hovered.is_in_group(&"battle_enemies"):
        var enemy_data: Resource = _hovered.get_meta("enemy_data", null) as Resource
        if enemy_data != null:
            _portrait.texture = _enemy_property(enemy_data, &"portrait", null) as Texture2D
            _name.text = str(_enemy_property(enemy_data, &"display_name", _hovered.name))
            var max_hp: int = int(_enemy_property(enemy_data, &"max_hp", 0))
            var max_mp: int = int(_enemy_property(enemy_data, &"max_mp", 0))
            var current_hp: int = int(_hovered.get_meta("hp_current", max_hp))
            var current_mp: int = int(_hovered.get_meta("mp_current", max_mp))
            _hp.text = "HP: %d / %d" % [current_hp, max_hp]
            _mp.text = "MP: %d / %d" % [current_mp, max_mp]
        else:
            _portrait.texture = null
            _name.text = _hovered.name
            _hp.text = ""
            _mp.text = ""
        return

    # Current prototype: Max is the only battle unit spawned.
    # Other units will need their own HeroData / EnemyData connection later.
    var hero: HeroData = null
    if party != null:
        for candidate in party.heroes:
            if candidate != null and candidate.hero_name == _hovered.name:
                hero = candidate
                break
    if hero == null:
        _portrait.texture = null
        _name.text = _hovered.name
        _hp.text = ""
        _mp.text = ""
        return
    _portrait.texture = hero.portrait
    _name.text = hero.hero_name
    var max_hp: int = 0
    var max_mp: int = 0
    if hero.base_stats != null:
        max_hp = hero.base_stats.hp
        max_mp = hero.base_stats.mp
    _hp.text = "HP: %d / %d" % [hero.hp_current, max_hp]
    _mp.text = "MP: %d / %d" % [hero.mp_current, max_mp]


func _enemy_property(enemy_data: Resource, property_name: StringName, default_value: Variant) -> Variant:
    for property in enemy_data.get_property_list():
        if StringName(property["name"]) == property_name:
            return enemy_data.get(property_name)
    return default_value


func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HoverUI"
    layer.layer = 20
    add_child(layer)

    var root := Control.new()
    root.name = "Overlay"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    # CanvasLayer children added dynamically require viewport-sized anchor parent.
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _hud = PanelContainer.new()
    _hud.name = "InfoPanel"
    _hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _hud.offset_left = -float(panel_margin + panel_width)
    _hud.offset_right = -float(panel_margin)
    _hud.offset_top = float(panel_margin)
    _hud.offset_bottom = float(panel_margin + panel_height)
    _hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = panel_background
    style.border_color = Color(0.74, 0.66, 0.44, 1.0)
    style.set_border_width_all(2)
    style.set_content_margin_all(6)
    _hud.add_theme_stylebox_override("panel", style)
    root.add_child(_hud)

    var content := HBoxContainer.new()
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_theme_constant_override("separation", 7)
    _hud.add_child(content)
    _portrait = TextureRect.new()
    _portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
    _portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(_portrait)

    var column := VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(column)
    for field in ["name", "hp", "mp"]:
        var label := Label.new()
        label.add_theme_color_override("font_color", text_color)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        column.add_child(label)
        match field:
            "name": _name = label
            "hp": _hp = label
            "mp": _mp = label
    _hud.visible = false


func _exit_tree() -> void:
    _clear_highlight()


func _on_combat_resolved(_attacker: Node2D, _target: Node2D, _result: Dictionary) -> void:
    if _hud != null:
        _update_panel()

func _on_unit_defeated(_unit: Node2D, _is_enemy: bool) -> void:
    call_deferred("_refresh_hover")
