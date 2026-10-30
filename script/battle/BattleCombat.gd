extends Node
## Tactical physical combat. Does not own turns, movement or presentation.
## Add a Node named BattleCombat to BattleMap and attach this script.
##
## Enemy current HP is stored on each spawned unit via metadata.
## Hero current HP is stored in its HeroData resource.

signal combat_resolved(attacker: Node2D, target: Node2D, result: Dictionary)
signal unit_defeated(unit: Node2D, is_enemy: bool)
signal battle_ended(victory: bool, reason: String)

## Общие правила смерти и завершения боя находятся в этом же скрипте.
## Отдельные BattleOutcome и BattleDeathEffect не нужны.
@export_group("References")
## Путь к ноде очередности ходов.
@export var turn_path: NodePath = ^"../BattleTurn"
## Путь к контейнеру всех боевых персонажей.
@export var units_path: NodePath = ^"../Units"
## Путь к контроллеру ИИ, чтобы сообщать ему об атаке врага.
@export var enemy_ai_path: NodePath = ^"../BattleEnemyAI"
## Общий ресурс с формулой физического урона.
@export var rules: CombatRules

@export_group("Combat")
## Разрешает физические атаки в бою.
@export var enable_physical_attacks: bool = true

@export_group("Поражение и победа")
## Имя героя-лидера. При его гибели бой немедленно считается проигранным.
@export var party_leader_name: StringName = &"Max"
## Проигрыш сразу после гибели лидера команды.
@export var defeat_on_party_leader_death: bool = true
## Победа, если после смерти врага не осталось живых противников.
@export var victory_on_all_enemies_defeated: bool = true
## Досрочная победа при гибели назначенного командира врагов.
@export var victory_on_enemy_leader_death: bool = true
## ID видов врагов-командиров для этой битвы. Например: ["goblin_chief"].
## Для уникального экземпляра можно назначить метаданные is_battle_leader=true.
@export var enemy_leader_ids: PackedStringArray = PackedStringArray()
## Останавливает очередь ходов при завершении боя.
@export var stop_turns_on_battle_end: bool = true

@export_group("Растворение при смерти")
## Продолжительность исчезновения персонажа в секундах.
@export_range(0.05, 5.0, 0.05) var death_fade_duration: float = 1.35
## Сколько секунд камера даёт себе для приближения к погибающему перед растворением.
@export_range(0.0, 3.0, 0.05) var death_camera_arrival_delay: float = 0.35
## Сколько секунд камера остаётся на месте гибели после исчезновения.
@export_range(0.0, 3.0, 0.05) var death_camera_hold_delay: float = 0.65
## Одновременно с прозрачностью уменьшать размер спрайта.
@export var shrink_on_death: bool = false
## Задержка после исчезновения лидера перед экраном исхода.
@export_range(0.0, 3.0, 0.05) var end_battle_delay: float = 0.45

@export_group("Окно результата")
## Показывать встроенное окно победы и поражения.
@export var show_result_panel: bool = true
## Показывать кнопку перезапуска текущей боевой сцены.
@export var allow_retry: bool = true
## Текст подсказки для ещё не подключённой системы загрузки.
@export_multiline var load_save_hint: String = "Загрузка последнего сохранения пока не подключена."


var _turn: Node
var _units: Node2D
var _enemy_ai: Node
var _rng := RandomNumberGenerator.new()
var _battle_finished: bool = false
var _battle_result: bool = false
var _initial_hero_hp: Dictionary = {}
var _result_layer: CanvasLayer


func _ready() -> void:
    _turn = get_node_or_null(turn_path)
    _units = get_node_or_null(units_path) as Node2D
    _enemy_ai = get_node_or_null(enemy_ai_path)
    _rng.randomize()
    if rules == null:
        rules = CombatRules.new()
    if _turn == null or _units == null:
        push_warning("BattleCombat: set Turn Path and Units Path in Inspector.")
    _capture_initial_hero_hp()


## Returns a result Dictionary: ok, reason, damage, hp_before, hp_after, defeated.
## Does not move actors or advance turns.
func physical_attack(attacker: Node2D, target: Node2D) -> Dictionary:
    var result: Dictionary = {"ok": false, "reason": "", "damage": 0, "hp_before": 0, "hp_after": 0, "defeated": false}
    if _battle_finished:
        result["reason"] = "Битва уже завершена."
        return result
    if not enable_physical_attacks:
        result["reason"] = "Physical attacks disabled."
        return result
    if not is_instance_valid(attacker) or not is_instance_valid(target) or attacker == target:
        result["reason"] = "Invalid participants."
        return result
    if not attacker.is_inside_tree() or not target.is_inside_tree():
        result["reason"] = "Unit is not on the battle map."
        return result
    if _units == null or attacker.get_parent() != _units or target.get_parent() != _units:
        result["reason"] = "Units must be children of Units."
        return result
    if _is_enemy(attacker) == _is_enemy(target):
        result["reason"] = "Friendly fire disabled."
        return result
    var before: int = get_current_hp(target)
    if before <= 0 or get_current_hp(attacker) <= 0:
        result["reason"] = "Dead participant."
        return result

    var attack_value: int = _stat(attacker, "attack")
    var defense_value: int = _stat(target, "defense")
    var damage: int = maxi(rules.minimum_damage, roundi(float(attack_value - defense_value) * rules.physical_multiplier))
    if rules.damage_variation_percent > 0.0:
        var delta: float = rules.damage_variation_percent / 100.0
        damage = maxi(0, roundi(float(damage) * _rng.randf_range(1.0 - delta, 1.0 + delta)))
    if rules.clamp_damage_to_remaining_hp:
        damage = mini(damage, before)
    var after: int = maxi(0, before - damage)
    _set_current_hp(target, after)
    var defeated: bool = after == 0
    result = {"ok": true, "reason": "", "damage": damage, "hp_before": before, "hp_after": after, "defeated": defeated}
    combat_resolved.emit(attacker, target, result)
    if _is_enemy(target) and _enemy_ai != null and _enemy_ai.has_method("notify_enemy_attacked"):
        _enemy_ai.call("notify_enemy_attacked", target, attacker)
    if rules.print_damage_to_output:
        print("[BattleCombat] %s -> %s: -%d HP (%d/%d)" % [attacker.name, target.name, damage, after, get_max_hp(target)])
    if defeated:
        _handle_defeat(target)
    return result

func get_current_hp(unit: Node2D) -> int:
    if not is_instance_valid(unit):
        return 0
    if _is_enemy(unit):
        return maxi(0, int(unit.get_meta("hp_current", get_max_hp(unit))))
    var hero: Resource = _hero_data(unit)
    if hero != null:
        return maxi(0, int(hero.get("hp_current")))
    return 0

func get_max_hp(unit: Node2D) -> int:
    if not is_instance_valid(unit):
        return 0
    if _is_enemy(unit):
        var data: Resource = unit.get_meta("enemy_data", null) as Resource
        return maxi(0, _resource_int(data, "max_hp"))
    var hero: Resource = _hero_data(unit)
    if hero != null:
        var stats: Resource = hero.get("base_stats") as Resource
        return maxi(0, _resource_int(stats, "hp"))
    return 0

func _set_current_hp(unit: Node2D, value: int) -> void:
    var new_value: int = clampi(value, 0, get_max_hp(unit))
    if _is_enemy(unit):
        unit.set_meta("hp_current", new_value)
    else:
        var hero: Resource = _hero_data(unit)
        if hero != null:
            hero.set("hp_current", new_value)

func _stat(unit: Node2D, key: String) -> int:
    if _is_enemy(unit):
        return _resource_int(unit.get_meta("enemy_data", null) as Resource, key)
    var hero: Resource = _hero_data(unit)
    if hero == null:
        return 0
    return _resource_int(hero.get("base_stats") as Resource, key)

func _hero_data(unit: Node2D) -> Resource:
    if _turn == null:
        return null
    var party: Resource = _turn.get("party") as Resource
    if party == null:
        return null
    var heroes: Array = party.get("heroes")
    for hero in heroes:
        if hero is Resource and str(hero.get("hero_name")) == unit.name:
            return hero
    return null

func _resource_int(resource: Resource, key: String) -> int:
    if resource == null:
        return 0
    for property in resource.get_property_list():
        if String(property.get("name", "")) == key:
            return int(resource.get(key))
    return 0

func _is_enemy(unit: Node2D) -> bool:
    return unit.is_in_group(&"battle_enemies")

## Возвращает true, если бой завершён.
func is_battle_finished() -> bool:
    return _battle_finished


func _capture_initial_hero_hp() -> void:
    if _turn == null:
        return
    var party: Resource = _turn.get("party") as Resource
    if party == null:
        return
    for hero in party.get("heroes"):
        if hero is Resource:
            _initial_hero_hp[hero.get_instance_id()] = {"resource": hero, "hp": int(hero.get("hp_current"))}


func _restore_initial_hero_hp() -> void:
    # При повторном запуске восстанавливаем HP перед стартом тестового боя.
    for entry in _initial_hero_hp.values():
        var hero: Resource = entry["resource"] as Resource
        if is_instance_valid(hero):
            hero.set("hp_current", int(entry["hp"]))


func _handle_defeat(unit: Node2D) -> void:
    if not is_instance_valid(unit) or unit.has_meta("battle_defeated"):
        return
    unit.set_meta("battle_defeated", true)
    var enemy: bool = _is_enemy(unit)
    var leader: bool = not enemy and StringName(unit.name) == party_leader_name
    var enemy_leader: bool = enemy and _is_enemy_leader(unit)
    unit_defeated.emit(unit, enemy)

    var terminal: bool = false
    var victory: bool = false
    var message: String = ""
    if leader and defeat_on_party_leader_death:
        terminal = true
        message = "Лидер отряда погиб."
    elif enemy_leader and victory_on_enemy_leader_death:
        terminal = true
        victory = true
        message = "Командир врагов повержен."
    elif enemy and victory_on_all_enemies_defeated and not _has_living_enemies():
        terminal = true
        victory = true
        message = "Все противники повержены."
    elif not enemy and not _has_living_heroes():
        terminal = true
        message = "Отряд потерпел поражение."

    if terminal:
        _battle_finished = true
        _battle_result = victory
        if stop_turns_on_battle_end and _turn != null and _turn.has_method("stop_battle"):
            _turn.call("stop_battle")
    _animate_death_and_remove(unit, terminal, victory, message)


func _is_enemy_leader(unit: Node2D) -> bool:
    if bool(unit.get_meta("is_battle_leader", false)):
        return true
    var entry: Resource = unit.get_meta("enemy_data", null) as Resource
    if entry == null:
        return false
    var enemy_id: String = str(unit.get_meta("enemy_id", ""))
    if enemy_leader_ids.has(enemy_id):
        return true
    for property in entry.get_property_list():
        if str(property.get("name", "")) == "is_battle_leader":
            return bool(entry.get("is_battle_leader"))
    return false


func _has_living_enemies() -> bool:
    if _units == null:
        return false
    for child in _units.get_children():
        var unit := child as Node2D
        if unit != null and unit.is_in_group(&"battle_enemies") and get_current_hp(unit) > 0:
            return true
    return false


func _has_living_heroes() -> bool:
    if _units == null:
        return false
    for child in _units.get_children():
        var unit := child as Node2D
        if unit != null and not _is_enemy(unit) and _hero_data(unit) != null and get_current_hp(unit) > 0:
            return true
    return false


func _animate_death_and_remove(unit: Node2D, terminal: bool, victory: bool, message: String) -> void:
    # Камера фиксируется на погибающем до начала растворения.
    # BattleTurn откладывает переключение, если враг завершил ход в это время.
    if not is_instance_valid(unit):
        if terminal:
            _finish_battle_presentation(victory, message)
        return
    if _turn != null and _turn.has_method("begin_death_presentation"):
        _turn.call("begin_death_presentation", unit)

    if death_camera_arrival_delay > 0.0:
        await get_tree().create_timer(death_camera_arrival_delay).timeout
    if not is_instance_valid(unit):
        if _turn != null and _turn.has_method("end_death_presentation"):
            _turn.call("end_death_presentation")
        if terminal:
            _finish_battle_presentation(victory, message)
        return

    var sprite := unit.get_node_or_null("AnimatedSprite2D") as CanvasItem
    var visual: CanvasItem = sprite if sprite != null else unit as CanvasItem
    if visual != null:
        var tween := create_tween()
        tween.tween_property(visual, "modulate:a", 0.0, death_fade_duration)
        if shrink_on_death and sprite is Node2D:
            tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, death_fade_duration)
        await tween.finished

    if is_instance_valid(unit):
        unit.queue_free()

    # Внимание: задержка после удаления держит камеру на последней клетке.
    if death_camera_hold_delay > 0.0:
        await get_tree().create_timer(death_camera_hold_delay).timeout
    if _turn != null and is_instance_valid(_turn) and _turn.has_method("end_death_presentation"):
        _turn.call("end_death_presentation")
    if terminal:
        _finish_battle_presentation(victory, message)


func _finish_battle_presentation(victory: bool, message: String) -> void:
    if end_battle_delay > 0.0:
        await get_tree().create_timer(end_battle_delay).timeout
    battle_ended.emit(victory, message)
    if show_result_panel:
        _show_battle_result(victory, message)


func _show_battle_result(victory: bool, message: String) -> void:
    if _result_layer != null:
        return
    _result_layer = CanvasLayer.new()
    _result_layer.name = "BattleResultUI"
    _result_layer.layer = 100
    add_child(_result_layer)
    var overlay := ColorRect.new()
    overlay.color = Color(0.02, 0.03, 0.06, 0.83)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _result_layer.add_child(overlay)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(350, 180)
    center.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    panel.add_child(column)
    var title := Label.new()
    title.text = "ПОБЕДА" if victory else "ПОРАЖЕНИЕ"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var reason := Label.new()
    reason.text = message
    reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(reason)
    if allow_retry:
        var retry := Button.new()
        retry.text = "Повторить битву"
        retry.pressed.connect(_retry_battle)
        column.add_child(retry)
    if not victory:
        var load_button := Button.new()
        load_button.text = "Загрузить сохранение (пока недоступно)"
        load_button.disabled = true
        load_button.tooltip_text = load_save_hint
        column.add_child(load_button)


func _retry_battle() -> void:
    _restore_initial_hero_hp()
    get_tree().reload_current_scene()
