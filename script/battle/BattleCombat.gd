extends Node
## Tactical physical combat. Does not own turns, movement or presentation.
## Add a Node named BattleCombat to BattleMap and attach this script.
##
## Enemy current HP is stored on each spawned unit via metadata.
## Hero current HP is stored in its HeroData resource.

signal combat_resolved(attacker: Node2D, target: Node2D, result: Dictionary)
signal unit_defeated(unit: Node2D, is_enemy: bool)

@export_group("References")
@export var turn_path: NodePath = ^"../BattleTurn"
@export var units_path: NodePath = ^"../Units"
@export var enemy_ai_path: NodePath = ^"../BattleEnemyAI"
@export var rules: CombatRules

@export_group("Combat")
@export var enable_physical_attacks: bool = true
@export var remove_defeated_enemies: bool = true
@export var remove_defeated_heroes: bool = false

var _turn: Node
var _units: Node2D
var _enemy_ai: Node
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _turn = get_node_or_null(turn_path)
    _units = get_node_or_null(units_path) as Node2D
    _enemy_ai = get_node_or_null(enemy_ai_path)
    _rng.randomize()
    if rules == null:
        rules = CombatRules.new()
    if _turn == null or _units == null:
        push_warning("BattleCombat: set Turn Path and Units Path in Inspector.")

## Returns a result Dictionary: ok, reason, damage, hp_before, hp_after, defeated.
## Does not move actors or advance turns.
func physical_attack(attacker: Node2D, target: Node2D) -> Dictionary:
    var result: Dictionary = {"ok": false, "reason": "", "damage": 0, "hp_before": 0, "hp_after": 0, "defeated": false}
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
        unit_defeated.emit(target, _is_enemy(target))
        if (_is_enemy(target) and remove_defeated_enemies) or (not _is_enemy(target) and remove_defeated_heroes):
            target.queue_free()
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
