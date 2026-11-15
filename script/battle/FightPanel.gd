@tool
extends Control
## FightPanel: отдельный HUD для сцены столкновения.
## HP/MP отображаются нодами TextureProgressBar. Все текстуры,
## Nine Patch, цвета MP, рамки и размеры редактируются на самих полосках.
## Пока данные тестовые; позже FightScene сможет вызвать set_side_data().

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

@export_group("Многослойное HP (оба бойца)")
@export var use_hp_layers: bool = true
@export_range(1, 10000, 1) var hp_per_layer: int = 100
@export var layer_1_red: Color = Color("#dc2225")
@export var layer_2_gold: Color = Color("#d9aa40")
@export var layer_3_blue: Color = Color("#3575db")
@export var layer_4_purple: Color = Color("#a55cda")
@export var layer_5_green: Color = Color("#38ac76")

@export_group("Портреты: данные персонажей")
## Перетащи HeroData/EnemyData .tres для проверки эмоций в редакторе.
## В игре можно назначить ресурсы через set_side_portraits_from_data().
@export var hero_portrait_data: Resource
@export var enemy_portrait_data: Resource

@export_group("Предпросмотр эмоций")
## Только просмотр в редакторе; на поведение боёв не влияет.
@export_enum("Idle", "Attack", "Hit", "Victory", "Defeat") var preview_hero_emotion: int = 0
@export_enum("Idle", "Attack", "Hit", "Victory", "Defeat") var preview_enemy_emotion: int = 0

enum PortraitEmotion { IDLE, ATTACK, HIT, VICTORY, DEFEAT }

var _hero_emotion: PortraitEmotion = PortraitEmotion.IDLE
var _enemy_emotion: PortraitEmotion = PortraitEmotion.IDLE



# Цвет MP, цвет рамок, текстуры, Nine Patch и геометрия находятся
# в Inspector у HeroSide/HPBar, HeroSide/MPBar, EnemySide/HPBar, EnemySide/MPBar.
# HPBar.tint_progress управляется цветом текущего слоя (выше).


func _ready() -> void:
    _refresh()


func _process(_delta: float) -> void:
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
        if portrait_texture != null:
            hero_portrait = portrait_texture
    else:
        enemy_name = character_name
        enemy_level = character_level
        enemy_max_hp = maxi(1, maximum_hp)
        enemy_hp = clampi(current_hp, 0, enemy_max_hp)
        enemy_max_mp = maxi(0, maximum_mp)
        enemy_mp = clampi(current_mp, 0, enemy_max_mp)
        if portrait_texture != null:
            enemy_portrait = portrait_texture
    _refresh()


# ТРИГГЕРЫ ДЛЯ FIGHTSCENE
# Внешний боевой контроллер вызывает их в нужный момент анимации.
# Пока они готовы к подключению, но НЕ встраиваются в чужую боевую логику.

func set_side_portraits_from_data(is_hero: bool, data: Resource) -> void:
    if is_hero:
        hero_portrait_data = data
    else:
        enemy_portrait_data = data
    _refresh()


func set_side_emotion(is_hero: bool, emotion: PortraitEmotion) -> void:
    if is_hero:
        _hero_emotion = emotion
    else:
        _enemy_emotion = emotion
    _refresh()


func trigger_attack(is_hero: bool) -> void:
    set_side_emotion(is_hero, PortraitEmotion.ATTACK)


func trigger_hit(is_hero: bool) -> void:
    set_side_emotion(is_hero, PortraitEmotion.HIT)


func trigger_victory(is_hero: bool) -> void:
    set_side_emotion(is_hero, PortraitEmotion.VICTORY)


func trigger_defeat(is_hero: bool) -> void:
    set_side_emotion(is_hero, PortraitEmotion.DEFEAT)


func trigger_idle(is_hero: bool) -> void:
    set_side_emotion(is_hero, PortraitEmotion.IDLE)


func reset_emotions() -> void:
    _hero_emotion = PortraitEmotion.IDLE
    _enemy_emotion = PortraitEmotion.IDLE
    _refresh()


func _portrait_for_side(is_hero: bool) -> Texture2D:
    var data: Resource = hero_portrait_data if is_hero else enemy_portrait_data
    # Enemy Portrait Data может ссылаться на реестр с Array[EnemyData],
    # а не на один EnemyData. В таком случае берём первый ресурс из списка.
    # HeroData и одиночный EnemyData продолжают работать как раньше.
    data = _resolve_portrait_data(data)
    var fallback: Texture2D = hero_portrait if is_hero else enemy_portrait
    var emotion: int = (
            preview_hero_emotion if is_hero else preview_enemy_emotion
    ) if Engine.is_editor_hint() else (
            _hero_emotion if is_hero else _enemy_emotion
    )

    # Обычный портрет из HeroData/EnemyData имеет имя portrait.
    var idle: Texture2D = _resource_texture(data, "portrait")
    if idle == null:
        idle = _resource_texture(data, "portrait_idle")
    if idle == null:
        idle = fallback

    var field: String = ""
    match emotion:
        PortraitEmotion.ATTACK:
            field = "portrait_attack"
        PortraitEmotion.HIT:
            field = "portrait_hit"
        PortraitEmotion.VICTORY:
            field = "portrait_victory"
        PortraitEmotion.DEFEAT:
            field = "portrait_defeat"

    if not field.is_empty():
        var expression: Texture2D = _resource_texture(data, field)
        if expression != null:
            return expression
    return idle



func _resolve_portrait_data(data: Resource) -> Resource:
    if data == null:
        return null

    for property_info: Dictionary in data.get_property_list():
        if String(property_info.get("name", "")) != "enemies":
            continue
        var entries: Variant = data.get("enemies")
        if entries is Array:
            for entry in entries:
                if entry is Resource:
                    return entry as Resource
        return null

    return data


func _resource_texture(data: Resource, key: String) -> Texture2D:
    if data == null:
        return null
    for entry: Dictionary in data.get_property_list():
        if String(entry.get("name", "")) == key:
            return data.get(key) as Texture2D
    return null


func _refresh() -> void:
    _refresh_side("HeroSide", hero_name, hero_level, hero_hp,
            hero_max_hp, hero_mp, hero_max_mp,
            _portrait_for_side(true))
    _refresh_side("EnemySide", enemy_name, enemy_level, enemy_hp,
            enemy_max_hp, enemy_mp, enemy_max_mp,
            _portrait_for_side(false))


func _refresh_side(
        side_path: String,
        display_name: String,
        character_level: int,
        current_hp: int,
        maximum_hp: int,
        current_mp: int,
        maximum_mp: int,
        portrait_texture: Texture2D
) -> void:
    var side: Control = get_node_or_null(side_path) as Control
    if side == null:
        return

    var name_label: Label = side.get_node_or_null("NameLabel") as Label
    var level_label: Label = side.get_node_or_null("LevelLabel") as Label
    var portrait: TextureRect = side.get_node_or_null("Portrait") as TextureRect
    var hp_bar: TextureProgressBar = side.get_node_or_null("HPBar") as TextureProgressBar
    var mp_bar: TextureProgressBar = side.get_node_or_null("MPBar") as TextureProgressBar
    var hp_label: Label = side.get_node_or_null("HPValue") as Label
    var mp_label: Label = side.get_node_or_null("MPValue") as Label

    if name_label != null:
        name_label.text = display_name
    if level_label != null:
        level_label.text = "Lv %d" % character_level
    # Если портрет задан непосредственно в TextureRect, он сохраняется.
    if portrait != null and portrait_texture != null:
        portrait.texture = portrait_texture

    var safe_max_hp: int = maxi(1, maximum_hp)
    var safe_hp: int = clampi(current_hp, 0, safe_max_hp)
    var safe_max_mp: int = maxi(0, maximum_mp)
    var safe_mp: int = clampi(current_mp, 0, safe_max_mp)

    if hp_label != null:
        hp_label.text = str(safe_hp)
    if mp_label != null:
        mp_label.text = str(safe_mp)

    # Центрируем числа и подписи по фактическому положению столбиков.
    # Вертикальные координаты и оформление нод остаются редактируемыми.
    _center_label_over_bar(hp_label, hp_bar)
    _center_label_over_bar(mp_label, mp_bar)
    _center_label_over_bar(side.get_node_or_null("HPTitle") as Label, hp_bar)
    _center_label_over_bar(side.get_node_or_null("MPTitle") as Label, mp_bar)

    if hp_bar != null:
        _ensure_default_border(hp_bar)
        var progress_ratio: float = float(safe_hp) / float(safe_max_hp)
        var active_color: Color = layer_1_red
        var under_color: Color = Color(0.055, 0.11, 0.18, 0.95)

        if use_hp_layers and safe_max_hp > hp_per_layer and safe_hp > 0:
            # Ровно 100/200/... = заполненный нижний слой, а не пустой верхний.
            var capacity: int = maxi(1, hp_per_layer)
            var layer_index: int = floori(float(safe_hp - 1) / float(capacity))
            var inside_layer: int = safe_hp - layer_index * capacity
            progress_ratio = float(inside_layer) / float(capacity)
            active_color = _hp_layer_color(layer_index)
            if layer_index > 0:
                under_color = _hp_layer_color(layer_index - 1)
        elif not use_hp_layers:
            active_color = layer_1_red

        hp_bar.max_value = 100.0
        hp_bar.value = progress_ratio * 100.0
        hp_bar.tint_progress = active_color
        # Только для многослойного HP: под текущим слоем виден предыдущий.
        # Для одного слоя пустая часть использует обычный оттенок.
        hp_bar.tint_under = under_color

    if mp_bar != null:
        _ensure_default_border(mp_bar)
        mp_bar.max_value = 100.0
        mp_bar.value = (
                100.0 * float(safe_mp) / float(safe_max_mp)
                if safe_max_mp > 0 else 0.0
        )
        # MP tint_progress / tint_under редактируются на самой MPBar.


func _center_label_over_bar(label: Label, bar: TextureProgressBar) -> void:
    if label == null or bar == null:
        return
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.position.x = bar.position.x + (bar.size.x - label.size.x) / 2.0


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


func _ensure_default_border(bar: TextureProgressBar) -> void:
    # Предустановка рамки. TextureOver можно свободно заменить своим
    # ресурсом на конкретной ноде TextureProgressBar.
    if bar.texture_over != null:
        return

    # Белая рамка с прозрачным центром. Окраска — Texture > Tint Over.
    # 22x171 соответствует текущему размеру исходных полосок.
    # Nine Patch Stretch (2px) сохраняет контур при изменении размера.
    var width_px: int = 22
    var height_px: int = 171
    var border_px: int = 2
    var image: Image = Image.create_empty(
            width_px, height_px, false, Image.FORMAT_RGBA8
    )
    image.fill(Color(0, 0, 0, 0))
    for y in range(height_px):
        for x in range(width_px):
            if (x < border_px or x >= width_px - border_px
                    or y < border_px or y >= height_px - border_px):
                image.set_pixel(x, y, Color.WHITE)
    bar.texture_over = ImageTexture.create_from_image(image)
