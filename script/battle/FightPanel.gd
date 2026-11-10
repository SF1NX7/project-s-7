@tool
extends Control
## FightPanel: visual-only HUD, no changes to combat logic.
## Set the actor data from the Inspector now; later call set_side_data() from FightScene.

@export_group("Герой")
@export var hero_name: String = "Макс"
@export_range(1, 999, 1) var hero_level: int = 10
@export_range(1, 99999, 1) var hero_max_hp: int = 100
@export_range(0, 99999, 1) var hero_hp: int = 80
@export_range(0, 99999, 1) var hero_max_mp: int = 100
@export_range(0, 99999, 1) var hero_mp: int = 55
@export var hero_portrait: Texture2D

@export_group("Враг")
@export var enemy_name: String = "Гоблин"
@export_range(1, 999, 1) var enemy_level: int = 8
@export_range(1, 99999, 1) var enemy_max_hp: int = 100
@export_range(0, 99999, 1) var enemy_hp: int = 80
@export_range(0, 99999, 1) var enemy_max_mp: int = 100
@export_range(0, 99999, 1) var enemy_mp: int = 55
@export var enemy_portrait: Texture2D

@export_group("Вертикальные шкалы")
@export_range(8, 64, 1) var bar_width: int = 22
@export_range(40, 300, 1) var bar_height: int = 171
@export_range(0, 8, 1) var border_width: int = 2
@export var border_color: Color = Color("#c9a666")
@export var empty_color: Color = Color("#112234")
@export var mp_color: Color = Color("#2463fc")

@export_group("Цветные слои HP")
@export var use_hp_layers: bool = true
@export_range(1, 10000, 1) var hp_per_layer: int = 100
@export var layer_1_red: Color = Color("#dc2225")
@export var layer_2_gold: Color = Color("#d9aa40")
@export var layer_3_blue: Color = Color("#3575db")
@export var layer_4_purple: Color = Color("#a55cda")
@export var layer_5_green: Color = Color("#38ac76")

@export_group("Оформление портретов")
@export var portrait_border_color: Color = Color("#e0ad52")
@export_range(0, 8, 1) var portrait_border_width: int = 2
@export var portrait_background: Color = Color("#09233b")

var _styles: Dictionary = {}


func _ready() -> void:
    _refresh()


func _process(_delta: float) -> void:
    # Editor preview: Inspector changes are reflected without restarting the scene.
    if Engine.is_editor_hint():
        _refresh()


func set_side_data(
        is_hero: bool,
        character_name: String,
        character_level: int,
        current_hp: int,
        maximum_hp: int,
        current_mp: int,
        maximum_mp: int,
        portrait_texture: Texture2D = null
) -> void:
    if is_hero:
        hero_name = character_name
        hero_level = character_level
        hero_max_hp = maxi(1, maximum_hp)
        hero_hp = clampi(current_hp, 0, hero_max_hp)
        hero_max_mp = maxi(0, maximum_mp)
        hero_mp = clampi(current_mp, 0, hero_max_mp)
        hero_portrait = portrait_texture
    else:
        enemy_name = character_name
        enemy_level = character_level
        enemy_max_hp = maxi(1, maximum_hp)
        enemy_hp = clampi(current_hp, 0, enemy_max_hp)
        enemy_max_mp = maxi(0, maximum_mp)
        enemy_mp = clampi(current_mp, 0, enemy_max_mp)
        enemy_portrait = portrait_texture
    _refresh()


func _refresh() -> void:
    _refresh_side("HeroSide", hero_name, hero_level, hero_hp,
            hero_max_hp, hero_mp, hero_max_mp, hero_portrait)
    _refresh_side("EnemySide", enemy_name, enemy_level, enemy_hp,
            enemy_max_hp, enemy_mp, enemy_max_mp, enemy_portrait)


func _refresh_side(
        side: String, display_name: String, character_level: int,
        current_hp: int, maximum_hp: int, current_mp: int,
        maximum_mp: int, portrait_texture: Texture2D
) -> void:
    var root: Control = get_node_or_null(side) as Control
    if root == null:
        return

    var name_label: Label = root.get_node("NameLabel") as Label
    var level_label: Label = root.get_node("LevelLabel") as Label
    name_label.text = display_name
    level_label.text = "Lv %d" % character_level

    var portrait: TextureRect = root.get_node("PortraitFrame/Portrait") as TextureRect
    var placeholder: Label = root.get_node("PortraitFrame/PortraitPlaceholder") as Label
    portrait.texture = portrait_texture
    placeholder.visible = portrait_texture == null

    var frame: Panel = root.get_node("PortraitFrame") as Panel
    var frame_style: StyleBoxFlat = _get_style(side + "_frame", frame, "panel")
    frame_style.bg_color = portrait_background
    frame_style.border_color = portrait_border_color
    _set_border(frame_style, portrait_border_width)

    var safe_max_hp: int = maxi(1, maximum_hp)
    var safe_hp: int = clampi(current_hp, 0, safe_max_hp)
    var safe_max_mp: int = maxi(0, maximum_mp)
    var safe_mp: int = clampi(current_mp, 0, safe_max_mp)

    var hp_bar: ProgressBar = root.get_node("HPBar") as ProgressBar
    var mp_bar: ProgressBar = root.get_node("MPBar") as ProgressBar
    var hp_value: Label = root.get_node("HPValue") as Label
    var mp_value: Label = root.get_node("MPValue") as Label
    hp_value.text = "%d/%d" % [safe_hp, safe_max_hp]
    mp_value.text = "%d/%d" % [safe_mp, safe_max_mp]

    var hp_ratio: float = float(safe_hp) / float(safe_max_hp)
    var hp_fill_color: Color = layer_1_red
    var hp_under_color: Color = empty_color

    if use_hp_layers:
        var capacity: int = maxi(1, hp_per_layer)
        if safe_max_hp <= capacity:
            # A full bar is 100% even if maximum HP is 5, 50 or 70.
            hp_ratio = float(safe_hp) / float(safe_max_hp)
        elif safe_hp > 0:
            # At exact boundaries: 100=full red, 200=full gold...
            var layer: int = (safe_hp - 1) / capacity
            var inside: int = safe_hp - layer * capacity
            hp_ratio = float(inside) / float(capacity)
            hp_fill_color = _hp_layer_color(layer)
            if layer > 0:
                hp_under_color = _hp_layer_color(layer - 1)
        else:
            hp_ratio = 0.0

    hp_bar.max_value = 100.0
    hp_bar.value = hp_ratio * 100.0
    mp_bar.max_value = 100.0
    mp_bar.value = (100.0 * float(safe_mp) / float(safe_max_mp)) if safe_max_mp > 0 else 0.0

    _style_bar(side + "_hp", hp_bar, hp_fill_color, hp_under_color)
    _style_bar(side + "_mp", mp_bar, mp_color, empty_color)


func _style_bar(key: String, bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
    # Adjust sizes but never alter bar positions or other HUD coordinates.
    bar.size = Vector2(bar_width, bar_height)
    bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
    bar.show_percentage = false

    var background: StyleBoxFlat = _get_style(key + "_background", bar, "background")
    background.bg_color = bg_color
    background.border_color = border_color
    _set_border(background, border_width)

    var fill: StyleBoxFlat = _get_style(key + "_fill", bar, "fill")
    fill.bg_color = fill_color
    _set_border(fill, 0)


func _get_style(key: String, control: Control, style_name: String) -> StyleBoxFlat:
    if _styles.has(key):
        return _styles[key] as StyleBoxFlat
    var style: StyleBoxFlat = StyleBoxFlat.new()
    control.add_theme_stylebox_override(style_name, style)
    _styles[key] = style
    return style


func _set_border(style: StyleBoxFlat, thickness: int) -> void:
    style.border_width_left = thickness
    style.border_width_top = thickness
    style.border_width_right = thickness
    style.border_width_bottom = thickness


func _hp_layer_color(layer: int) -> Color:
    match layer % 5:
        0:
            return layer_1_red
        1:
            return layer_2_gold
        2:
            return layer_3_blue
        3:
            return layer_4_purple
        _:
            return layer_5_green
