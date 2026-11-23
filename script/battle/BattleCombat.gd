extends Node
## Tactical physical combat. Does not own turns, movement or presentation.
## Add a Node named BattleCombat to BattleMap and attach this script.
##
## Enemy current HP is stored on each spawned unit via metadata.
## Hero current HP is stored in its HeroData resource.

signal combat_resolved(attacker: Node2D, target: Node2D, result: Dictionary)
signal exchange_planned(exchange: Dictionary)
signal unit_defeated(unit: Node2D, is_enemy: bool)
signal battle_ended(victory: bool, reason: String)
## Emitted after each enemy death reward is added to existing inventory service.
signal enemy_rewards_granted(enemy_name: String, gold_amount: int, items: Array)

const RETURN_PIXEL_TRANSITION: PackedScene = preload("res://scene/battle/PixelTransition.tscn")

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

@export_group("Experience and Loot")
## The shared XP balance preset. Edit the .tres file, not combat scripts.
@export var experience_rules: ExperienceRules = preload("res://data/battle_rules/ExperienceRules.tres")
## Gold and drops are taken from each EnemyData card; one roll per dead unit.
@export var award_enemy_loot: bool = true

@export_group("Предрасчёт столкновения")
## При подключённом FightPreviewBridge откладывать применение HP до конца анимаций.
@export var staged_exchanges_enabled: bool = true
## Шанс уворота цели (проценты). 0 — отключено.
@export_range(0.0, 100.0, 0.5, "suffix:%") var dodge_chance: float = 0.0
## Шанс критического удара (проценты). 0 — отключено.
@export_range(0.0, 100.0, 0.5, "suffix:%") var critical_chance: float = 0.0
## Множитель урона критического удара.
@export_range(1.0, 4.0, 0.1) var critical_multiplier: float = 1.5
## Шанс одного контрудара живой цели.
@export_range(0.0, 100.0, 0.5, "suffix:%") var counter_chance: float = 0.0
## Шанс одного дополнительного удара первого атакующего.
@export_range(0.0, 100.0, 0.5, "suffix:%") var extra_attack_chance: float = 0.0


@export_group("Удача и вероятности")
## Включает личный бонус LUCK поверх базовых шансов из раздела «Предрасчёт столкновения».
## Если выключено, используются только базовые шансы, как в прежней версии.
@export var use_luck_for_chances: bool = true
## Дополнительный шанс уклонения за 1 LUCK защищающегося, в процентных пунктах.
@export_range(0.0, 5.0, 0.05, "suffix:%") var dodge_per_luck: float = 0.15
## Дополнительный шанс критического удара за 1 LUCK атакующего.
@export_range(0.0, 5.0, 0.05, "suffix:%") var critical_per_luck: float = 0.10
## Дополнительный шанс контратаки за 1 LUCK защищающегося.
@export_range(0.0, 5.0, 0.05, "suffix:%") var counter_per_luck: float = 0.15
## Дополнительный шанс повторной атаки за 1 LUCK первоначального атакующего.
@export_range(0.0, 5.0, 0.05, "suffix:%") var extra_attack_per_luck: float = 0.10

@export_group("Combat")
## Разрешает физические атаки в бою.
@export var enable_physical_attacks: bool = true

@export_group("Magic Combat")
## Temporary Stage 3 formula: spell roll + caster magic - target resistance.
@export var magic_use_stats: bool = true
@export_range(0, 999, 1) var magic_xp_per_hit: int = 1
## Use the defeated enemy's existing Experience reward.
@export var magic_use_enemy_experience: bool = true

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

@export_group("Pixel Death — враги")
@export var pixel_death_enabled: bool = true
@export var pixel_death_use_on_fight_scene: bool = true
@export var pixel_death_use_on_tactical_map: bool = true
@export_range(0.05, 5.0, 0.05, "suffix:s") var pixel_death_duration: float = 0.9
## Размер блока в пикселях исходного кадра.
@export_range(1, 32, 1, "suffix:px") var pixel_death_pixel_size: int = 4
@export_range(1, 16, 1, "suffix:px") var pixel_death_map_pixel_size: int = 2
## Разлёт относительно масштаба спрайта, в локальных пикселях.
@export_range(0.0, 160.0, 1.0, "suffix:px") var pixel_death_scatter_strength: float = 28.0
@export_range(0.0, 80.0, 1.0, "suffix:px") var pixel_death_map_scatter_strength: float = 12.0
@export_range(0.0, 1.0, 0.05) var pixel_death_fade_strength: float = 0.7
@export var pixel_death_flash_before_dissolve: bool = true
@export_range(0.0, 3.0, 0.05, "suffix:s") var pixel_death_hold_after_death: float = 0.2

const ENEMY_PIXEL_DEATH = preload("res://script/battle/enemy_pixel_death.gd")

@export_group("Окно результата")
## Показывать встроенное окно победы и поражения.
@export var show_result_panel: bool = true
## Показывать кнопку перезапуска текущей боевой сцены.
@export var allow_retry: bool = true
## Текст подсказки для ещё не подключённой системы загрузки.
@export_multiline var load_save_hint: String = "Загрузка последнего сохранения пока не подключена."

@export_group("Возврат после победы")
## Сцена глобальной карты. Укажи фактический World_1.tscn из своего проекта.
@export_file("*.tscn") var victory_world_scene: String = ""
## Автоматически вернуться на глобальную карту после показа победы.
@export var return_after_victory: bool = true
## Сколько секунд держать надпись ПОБЕДА перед возвратом на карту.
@export_range(0.5, 15.0, 0.1, "suffix:s") var victory_panel_duration: float = 3.0
## Кнопка возврата на карту в окне победы.
@export var show_return_button: bool = true

@export_group("Пиксельный переход после боя")
## Включить пиксельное затемнение при выходе с экрана победы.
@export var pixel_return_enabled: bool = true
## Время закрытия и открытия экрана в секундах (каждая фаза).
@export_range(0.1, 3.0, 0.05, "suffix:s") var pixel_return_duration: float = 0.5
## Размер блоков пиксельного эффекта.
@export_range(2.0, 64.0, 1.0, "suffix:px") var pixel_return_size: float = 8.0
## Цвет пиксельного затемнения.
@export var pixel_return_color: Color = Color.BLACK


var _turn: Node
var _units: Node2D
var _enemy_ai: Node
var _rng := RandomNumberGenerator.new()
var _battle_finished: bool = false
var _battle_result: bool = false
var _initial_hero_hp: Dictionary = {}
var _result_layer: CanvasLayer
var _result_buttons: Array[Button] = []
var _result_selected_index: int = 0
var _result_previous_pause: bool = false
var _result_previous_process_mode: ProcessMode = Node.PROCESS_MODE_INHERIT
var _return_transition_started: bool = false
var _pending_exchange: Dictionary = {}
var _magic_committing: bool = false



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
## Вызывается после подтверждения Attack. Все броски RNG выполняются здесь.
## При активном мосте HP и смерть применяются после визуального воспроизведения.
func physical_attack(attacker: Node2D, target: Node2D) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "damage": 0, "hp_before": 0, "hp_after": 0, "defeated": false}
	if _battle_finished or not enable_physical_attacks:
		result["reason"] = "Битва завершена или атаки отключены."
		return result
	if not _pending_exchange.is_empty():
		result["reason"] = "Предыдущее столкновение ещё воспроизводится."
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
	var first_hp: int = get_current_hp(attacker)
	var second_hp: int = get_current_hp(target)
	if first_hp <= 0 or second_hp <= 0:
		result["reason"] = "Dead participant."
		return result

	var actions: Array[Dictionary] = []
	var virtual_hp: Dictionary = {attacker.get_instance_id(): first_hp, target.get_instance_id(): second_hp}
	_plan_strike(attacker, target, "attack", virtual_hp, actions)
	# Ни контратака, ни дополнительный удар не допускаются после гибели участника.
	if _still_fighting(attacker, target, virtual_hp) and _roll_percent(_effective_chance(counter_chance, target, counter_per_luck)):
		_plan_strike(target, attacker, "counter", virtual_hp, actions)
	if _still_fighting(attacker, target, virtual_hp) and _roll_percent(_effective_chance(extra_attack_chance, attacker, extra_attack_per_luck)):
		_plan_strike(attacker, target, "extra", virtual_hp, actions)

	var after_first: int = int(virtual_hp[attacker.get_instance_id()])
	var after_second: int = int(virtual_hp[target.get_instance_id()])
	var primary_damage: int = int(actions[0].get("damage", 0))
	result = {
		"ok": true,
		"reason": "",
		"damage": primary_damage,
		"hp_before": second_hp,
		"hp_after": after_second,
		"defeated": after_second == 0,
		"actions": actions,
		"attacker_hp_after": after_first,
		"staged": true
	}
	_pending_exchange = {"attacker": attacker, "target": target, "result": result}
	# Если мост ещё не установлен — сохраняем старое безопасное поведение.
	if staged_exchanges_enabled and not exchange_planned.get_connections().is_empty():
		exchange_planned.emit(_pending_exchange.duplicate(true))
	else:
		commit_pending_exchange()
	return result


## Лечение расходником: только планирование, без мгновенного изменения HP.
## Используется BattleTurn после подтверждения цели. FightScene показывает результат,
## а commit_pending_exchange() выполняет фактическое изменение ровно один раз.
func use_healing_item(attacker: Node2D, target: Node2D, item: ItemData) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": ""}
	if _battle_finished or not _pending_exchange.is_empty():
		result["reason"] = "Боевое действие уже выполняется."
		return result
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		result["reason"] = "Нет участника действия."
		return result
	if not attacker.is_inside_tree() or not target.is_inside_tree():
		result["reason"] = "Участники отсутствуют на карте."
		return result
	if _units == null or attacker.get_parent() != _units or target.get_parent() != _units:
		result["reason"] = "Участники не находятся среди боевых юнитов."
		return result
	if _is_enemy(attacker) != _is_enemy(target):
		result["reason"] = "Нельзя лечить противника этим предметом."
		return result
	if get_current_hp(attacker) <= 0 or get_current_hp(target) <= 0:
		result["reason"] = "Нельзя применить предмет к павшему персонажу."
		return result
	if item == null or not item.usable_in_battle or item.use_effect == null:
		result["reason"] = "Предмет недоступен в бою."
		return result
	var effect: ItemUseEffect = item.use_effect
	if effect.hp_restore <= 0:
		result["reason"] = "У предмета нет лечебного эффекта HP."
		return result
	var service: Node = get_node_or_null("/root/Inventory_Service")
	if service == null or not (service.get("items") as Array).has(item):
		result["reason"] = "Предмет отсутствует в инвентаре."
		return result
	var hp_before: int = get_current_hp(target)
	var hp_max: int = get_max_hp(target)
	var hp_after: int = clampi(hp_before + effect.hp_restore, 0, hp_max)
	var healed: int = hp_after - hp_before
	if healed <= 0:
		result["reason"] = "Здоровье цели уже полное."
		return result
	var xp: int = maxi(0, effect.xp_gain)
	if experience_rules != null:
		var healer: Resource = _hero_data(attacker)
		if healer != null:
			var healer_level: int = maxi(1, _resource_int(healer, "level"))
			xp = experience_rules.xp_for_healing(healed, healer_level, healer_level)
	result = {
		"ok": true, "reason": "", "kind": "item_heal",
		"hp_before": hp_before, "hp_after": hp_after,
		"healed": healed, "xp_gain": xp,
		"actions": [{
			"kind": "item_heal",
			"source_name": _unit_name(attacker),
			"target_name": _unit_name(target),
			"item_name": item.title.strip_edges(),
			"heal": healed, "xp_gain": xp
		}]
	}
	_pending_exchange = {
		"kind": "item_heal", "attacker": attacker, "target": target,
		"item": item, "result": result
	}
	if staged_exchanges_enabled and not exchange_planned.get_connections().is_empty():
		exchange_planned.emit(_pending_exchange.duplicate(true))
	else:
		commit_pending_exchange()
	return result


## Базовый шанс задаётся в Inspector; LUCK персонажа добавляет небольшой бонус.
## Если у StatsBonus пока нет свойства luck, бонус героя будет равен нулю.
func _effective_chance(base_chance: float, unit: Node2D, bonus_per_luck: float) -> float:
	if not use_luck_for_chances:
		return clampf(base_chance, 0.0, 100.0)
	var luck: int = maxi(0, _stat(unit, "luck"))
	return clampf(base_chance + float(luck) * bonus_per_luck, 0.0, 100.0)


func _roll_percent(chance: float) -> bool:
	return chance > 0.0 and _rng.randf() * 100.0 < chance


func _still_fighting(a: Node2D, b: Node2D, virtual_hp: Dictionary) -> bool:
	return int(virtual_hp.get(a.get_instance_id(), 0)) > 0 and int(virtual_hp.get(b.get_instance_id(), 0)) > 0


func _plan_strike(source: Node2D, victim: Node2D, kind: String, virtual_hp: Dictionary, actions: Array[Dictionary]) -> void:
	var victim_id: int = victim.get_instance_id()
	var before: int = int(virtual_hp.get(victim_id, 0))
	if before <= 0:
		return
	var missed: bool = _roll_percent(_effective_chance(dodge_chance, victim, dodge_per_luck))
	var critical: bool = not missed and _roll_percent(_effective_chance(critical_chance, source, critical_per_luck))
	var damage: int = 0
	if not missed:
		var attack_value: int = _stat(source, "attack")
		var defense_value: int = _stat(victim, "defense")
		damage = maxi(rules.minimum_damage, roundi(float(attack_value - defense_value) * rules.physical_multiplier))
		if rules.damage_variation_percent > 0.0:
			var delta: float = rules.damage_variation_percent / 100.0
			damage = maxi(0, roundi(float(damage) * _rng.randf_range(1.0 - delta, 1.0 + delta)))
		if critical:
			damage = roundi(float(damage) * critical_multiplier)
		if rules.clamp_damage_to_remaining_hp:
			damage = mini(damage, before)
	var after: int = maxi(0, before - damage)
	virtual_hp[victim_id] = after
	actions.append({
		"kind": kind, "source_is_enemy": _is_enemy(source),
		"source_name": _unit_name(source), "target_name": _unit_name(victim),
		"damage": damage, "dodged": missed, "critical": critical,
		"hp_before": before, "hp_after": after, "defeated": after == 0
	})


func _unit_name(unit: Node2D) -> String:
	if _is_enemy(unit):
		var data: Resource = unit.get_meta("enemy_data", null) as Resource
		if data != null:
			var label: Variant = data.get("display_name")
			if label != null and str(label) != "":
				return str(label)
	return str(unit.name)


## Применяется ровно один раз после завершения FightScene.
## Умирающие ноды не удаляются до этого момента.
## Stage 3: plan all targets before changing HP or MP.
## The ordered actions are also the future FightScene presentation queue.
func plan_magic_damage(attacker: Node2D, spell: SpellData, targets: Array[Node2D]) -> Dictionary:
	var failure: Dictionary = {"ok": false, "reason": "Магия недоступна."}
	if _battle_finished or not _pending_exchange.is_empty():
		failure["reason"] = "Боевое действие уже выполняется."
		return failure
	if not is_instance_valid(attacker) or _units == null or attacker.get_parent() != _units or _is_enemy(attacker):
		return failure
	var hero: Resource = _hero_data(attacker)
	if hero == null or get_current_hp(attacker) <= 0 or spell == null or spell.effect_type != SpellData.EffectType.DAMAGE:
		return failure
	var mp_before: int = get_current_mp(attacker)
	var cost: int = maxi(0, spell.mp_cost)
	if mp_before < cost:
		failure["reason"] = "Недостаточно MP."
		return failure
	var actions: Array[Dictionary] = []
	var seen: Dictionary = {}
	var total_damage: int = 0
	var total_xp: int = 0
	var defeated_count: int = 0
	for target in targets:
		if not is_instance_valid(target) or target.get_parent() != _units or not _is_enemy(target):
			continue
		var ident: int = target.get_instance_id()
		if seen.has(ident) or target.has_meta("battle_defeated"):
			continue
		seen[ident] = true
		var before: int = get_current_hp(target)
		if before <= 0:
			continue
		var missed: bool = not _roll_percent(float(clampi(spell.accuracy, 0, 100)))
		var damage: int = 0
		if not missed:
			damage = spell.get_damage_roll(_rng)
			if magic_use_stats:
				damage += _stat(attacker, "magic") - _stat(target, "resistance")
			damage = clampi(damage, 0, before)
		var after: int = before - damage
		var defeated: bool = after == 0
		var enemy_resource: Resource = target.get_meta("enemy_data", null) as Resource
		var hero_level: int = _resource_int(hero, "level")
		var enemy_level: int = maxi(1, _resource_int(enemy_resource, "level"))
		var xp: int = 0
		if experience_rules != null:
			xp = experience_rules.xp_for_hit(damage, hero_level, enemy_level)
		else:
			xp = maxi(0, magic_xp_per_hit) if damage > 0 else 0
		if defeated:
			defeated_count += 1
			if magic_use_enemy_experience:
				var kill_exp: int = maxi(0, _resource_int(enemy_resource, "experience"))
				if experience_rules != null:
					xp += experience_rules.xp_for_kill(kill_exp, hero_level, enemy_level)
				else:
					xp += kill_exp
		total_damage += damage
		total_xp += xp
		actions.append({
			"kind": "magic_damage", "target": target,
			"source_name": _unit_name(attacker), "target_name": _unit_name(target),
			"spell_name": spell.title, "damage": damage, "dodged": missed,
			"hp_before": before, "hp_after": after, "hp_max": get_max_hp(target),
			"defeated": defeated, "xp_gain": xp
		})
	if actions.is_empty():
		failure["reason"] = "Нет доступных противников."
		return failure
	var result: Dictionary = {
		"ok": true, "kind": "magic_damage", "reason": "", "spell_name": spell.title,
		"mp_before": mp_before, "mp_after": mp_before - cost, "mp_cost": cost,
		"damage": total_damage, "xp_gain": total_xp, "defeated_count": defeated_count,
		"actions": actions
	}
	_pending_exchange = {"kind": "magic_damage", "attacker": attacker, "spell": spell, "result": result}
	return result


## Stage 3 executes on the tactical map. Stage 4 can reuse the plan after FightScene.
## Keep the pending action locked until all death presentations have completed.
func commit_pending_magic() -> void:
	if str(_pending_exchange.get("kind", "")) != "magic_damage" or _magic_committing:
		return
	_magic_committing = true
	var attacker: Node2D = _pending_exchange.get("attacker") as Node2D
	var result: Dictionary = _pending_exchange.get("result", {})
	if not is_instance_valid(attacker):
		_pending_exchange = {}
		_magic_committing = false
		return
	var hero: Resource = _hero_data(attacker)
	if hero == null:
		_pending_exchange = {}
		_magic_committing = false
		return
	var actions: Array = result.get("actions", [])
	hero.set("mp_current", int(result["mp_after"]))
	var defeated_units: Array[Node2D] = []
	var leader_defeated: bool = false
	var actual_xp: int = 0
	print("S7 MAGIC: ", _unit_name(attacker), " casts ", result["spell_name"], "; MP ", result["mp_before"], " -> ", result["mp_after"])
	# Apply ALL HP before checking victory or running death animations.
	for action in actions:
		var target: Node2D = action.get("target") as Node2D
		if not is_instance_valid(target):
			continue
		_set_current_hp(target, int(action["hp_after"]))
		actual_xp += int(action["xp_gain"])
		if bool(action["defeated"]):
			defeated_units.append(target)
			leader_defeated = leader_defeated or _is_enemy_leader(target)
	_grant_hero_xp(hero, actual_xp)
	for action in actions:
		var target: Node2D = action.get("target") as Node2D
		if not is_instance_valid(target):
			continue
		var unit_result: Dictionary = action.duplicate()
		unit_result["ok"] = true
		unit_result["actions"] = [action]
		combat_resolved.emit(attacker, target, unit_result)
		if int(action["damage"]) > 0 and get_current_hp(target) > 0 and _enemy_ai != null and _enemy_ai.has_method("notify_enemy_attacked"):
			_enemy_ai.call("notify_enemy_attacked", target, attacker)
		print("S7 MAGIC TARGET: ", action["target_name"], " | damage ", action["damage"], " | HP ", action["hp_before"], " -> ", action["hp_after"], " | miss ", action["dodged"], " | defeated ", action["defeated"])
	print("S7 MAGIC RESULT: EXP +", actual_xp, "; defeated ", defeated_units.size())
	# Mark every casualty first. Camera and pixel effects run sequentially.
	for target in defeated_units:
		if is_instance_valid(target):
			target.set_meta("battle_defeated", true)
			_grant_enemy_loot(target)
			unit_defeated.emit(target, true)
	var message: String = ""
	if leader_defeated and victory_on_enemy_leader_death:
		message = "Командир врагов повержен."
	elif victory_on_all_enemies_defeated and not _has_living_enemies():
		message = "Все противники повержены."
	for target in defeated_units:
		if is_instance_valid(target):
			await _animate_death_and_remove(target, false, false, "")
	_pending_exchange = {}
	_magic_committing = false
	if not message.is_empty():
		_battle_finished = true
		_battle_result = true
		if stop_turns_on_battle_end and _turn != null and _turn.has_method("stop_battle"):
			_turn.call("stop_battle")
		await _finish_battle_presentation(true, message)


func commit_pending_exchange() -> void:
	if str(_pending_exchange.get("kind", "")) == "magic_damage":
		return
	if _pending_exchange.is_empty():
		return
	var exchange: Dictionary = _pending_exchange
	_pending_exchange = {}
	var attacker: Node2D = exchange.get("attacker") as Node2D
	var target: Node2D = exchange.get("target") as Node2D
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		push_warning("BattleCombat: невозможно применить результат: юнит уже удалён.")
		return
	var result: Dictionary = exchange.get("result", {})
	if str(exchange.get("kind", "")) == "item_heal":
		var item: ItemData = exchange.get("item") as ItemData
		var service: Node = get_node_or_null("/root/Inventory_Service")
		if item == null or service == null:
			push_warning("BattleCombat: лечение отменено — предмет или инвентарь недоступен.")
			return
		# Списание и HP происходят только здесь. Повторный commit безопасен:
		# _pending_exchange уже сброшен перед входом в эту ветку.
		if bool(item.use_effect.consume_on_use):
			var item_key: String = item.id.strip_edges()
			if item_key.is_empty() and not item.resource_path.is_empty():
				item_key = item.resource_path.get_file().get_basename()
			if item_key.is_empty() or not bool(service.call("remove_item_id", item_key)):
				push_warning("BattleCombat: лечение отменено — не удалось списать предмет.")
				return
		_set_current_hp(target, int(result.get("hp_after", get_current_hp(target))))
		var hero: Resource = _hero_data(attacker)
		var gained_xp: int = int(result.get("xp_gain", 0))
		if hero != null:
			_grant_hero_xp(hero, gained_xp)
		combat_resolved.emit(attacker, target, result)
		return
	_set_current_hp(attacker, int(result.get("attacker_hp_after", get_current_hp(attacker))))
	_set_current_hp(target, int(result.get("hp_after", get_current_hp(target))))
	_award_physical_action_xp(attacker, target, result.get("actions", []))
	# Совместимый сигнал — после применения итогового состояния.
	combat_resolved.emit(attacker, target, result)
	if _is_enemy(target) and _enemy_ai != null and _enemy_ai.has_method("notify_enemy_attacked"):
		_enemy_ai.call("notify_enemy_attacked", target, attacker)
	if rules.print_damage_to_output:
		print("[BattleCombat] exchange complete: ", attacker.name, " -> ", target.name)
	if get_current_hp(target) <= 0:
		_handle_defeat(target)
	if get_current_hp(attacker) <= 0 and not _battle_finished:
		_handle_defeat(attacker)


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

## Текущее MP персонажа на тактической карте (только чтение).
func get_current_mp(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return 0
	var maximum: int = get_max_mp(unit)
	if _is_enemy(unit):
		# Враги, у которых mp_current ещё не задан, начинают с полного MP.
		return clampi(int(unit.get_meta("mp_current", maximum)), 0, maximum)
	var hero: Resource = _hero_data(unit)
	if hero != null:
		return clampi(_resource_int(hero, "mp_current"), 0, maximum)
	return 0


## Максимальное MP из EnemyData или базовых характеристик героя.
func get_max_mp(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return 0
	if _is_enemy(unit):
		var data: Resource = unit.get_meta("enemy_data", null) as Resource
		return maxi(0, _resource_int(data, "max_mp"))
	var hero: Resource = _hero_data(unit)
	if hero != null:
		var stats: Resource = hero.get("base_stats") as Resource
		return maxi(0, _resource_int(stats, "mp"))
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

## Add XP to the specific hero and apply level thresholds only once on commit.
func _grant_hero_xp(hero: Resource, gained: int) -> void:
	if hero == null or gained <= 0:
		return
	if experience_rules != null:
		experience_rules.grant_experience(hero, gained)
	else:
		hero.set("xp", _resource_int(hero, "xp") + gained)


## Physical attacks are planned as an array; each successful dodge and counter has its own owner.
func _award_physical_action_xp(attacker: Node2D, target: Node2D, actions: Array) -> void:
	if experience_rules == null:
		return
	for action in actions:
		if not (action is Dictionary):
			continue
		var source: Node2D = attacker if bool(action.get("source_is_enemy", false)) == _is_enemy(attacker) else target
		var victim: Node2D = attacker if source == target else target
		if not is_instance_valid(source) or not is_instance_valid(victim):
			continue
		var is_miss: bool = bool(action.get("dodged", false))
		var enemy_unit: Node2D = source if _is_enemy(source) else victim
		var enemy_data: Resource = enemy_unit.get_meta("enemy_data", null) as Resource
		var enemy_level: int = maxi(1, _resource_int(enemy_data, "level"))
		if is_miss and not _is_enemy(victim):
			var dodger: Resource = _hero_data(victim)
			if dodger != null:
				_grant_hero_xp(dodger, experience_rules.xp_for_dodge(maxi(1, _resource_int(dodger, "level")), enemy_level))
		elif not is_miss and not _is_enemy(source):
			var hero: Resource = _hero_data(source)
			if hero == null:
				continue
			var current_level: int = maxi(1, _resource_int(hero, "level"))
			var amount: int = experience_rules.xp_for_hit(int(action.get("damage", 0)), current_level, enemy_level, str(action.get("kind", "")) == "counter")
			if bool(action.get("defeated", false)) and _is_enemy(victim):
				amount += experience_rules.xp_for_kill(_resource_int(enemy_data, "experience"), current_level, enemy_level)
			_grant_hero_xp(hero, amount)


## A defeated enemy pays rewards exactly once even if death animations are repeated.
func _grant_enemy_loot(enemy_unit: Node2D) -> void:
	if not award_enemy_loot or not is_instance_valid(enemy_unit) or not _is_enemy(enemy_unit):
		return
	if enemy_unit.has_meta("s7_rewards_processed"):
		return
	enemy_unit.set_meta("s7_rewards_processed", true)
	var enemy_data: Resource = enemy_unit.get_meta("enemy_data", null) as Resource
	if enemy_data == null:
		return
	var service: Node = get_node_or_null("/root/Inventory_Service")
	if service == null:
		service = get_node_or_null("/root/InventoryService")
	if service == null:
		push_warning("BattleCombat: Inventory_Service not found; gold and loot were not awarded.")
		return
	var guaranteed_gold: int = maxi(0, _resource_int(enemy_data, "gold"))
	var bonus_gold: int = 0
	if _rng.randf() < float(enemy_data.get("bonus_gold_chance")):
		var minimum: int = maxi(0, int(enemy_data.get("bonus_gold_min")))
		var maximum: int = maxi(minimum, int(enemy_data.get("bonus_gold_max")))
		bonus_gold = _rng.randi_range(minimum, maximum)
	var gold_amount: int = guaranteed_gold + bonus_gold
	if gold_amount > 0 and service.has_method("add_gold"):
		service.call("add_gold", gold_amount)
	var gained_items: Array = []
	if service.has_method("add_item"):
		var drops: Array = enemy_data.get("item_drops")
		for entry in drops:
			if not (entry is EnemyDropEntry):
				continue
			if entry.item == null or _rng.randf() >= clampf(entry.chance, 0.0, 1.0):
				continue
			var lower: int = maxi(1, entry.minimum_amount)
			var upper: int = maxi(lower, entry.maximum_amount)
			var amount: int = _rng.randi_range(lower, upper)
			for index in range(amount):
				service.call("add_item", entry.item)
				gained_items.append(entry.item)
		# Support old enemy cards using the original one-item drop fields.
		var old_item: Resource = enemy_data.get("drop_item") as Resource
		var old_chance: float = clampf(float(enemy_data.get("drop_chance")), 0.0, 1.0)
		if old_item != null and _rng.randf() < old_chance:
			service.call("add_item", old_item)
			gained_items.append(old_item)
	enemy_rewards_granted.emit(_unit_name(enemy_unit), gold_amount, gained_items)
	print("S7 LOOT: ", _unit_name(enemy_unit), " | gold +", gold_amount, " | items +", gained_items.size())


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
	if enemy:
		_grant_enemy_loot(unit)
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


## Shared visual effect. Returns false when disabled or no frame is available.
func play_enemy_pixel_death(sprite: AnimatedSprite2D, closeup: bool) -> bool:
	if not pixel_death_enabled or not is_instance_valid(sprite):
		return false
	if closeup and not pixel_death_use_on_fight_scene:
		return false
	if not closeup and not pixel_death_use_on_tactical_map:
		return false
	var effect = ENEMY_PIXEL_DEATH.new()
	sprite.add_child(effect)
	# FightScene is always processing even when BattleMap is paused.
	if closeup:
		effect.process_mode = Node.PROCESS_MODE_ALWAYS
	var settings: Dictionary = {
		"duration": pixel_death_duration,
		"pixel_size": pixel_death_pixel_size if closeup else pixel_death_map_pixel_size,
		"scatter": pixel_death_scatter_strength if closeup else pixel_death_map_scatter_strength,
		"fade": pixel_death_fade_strength,
		"flash": pixel_death_flash_before_dissolve,
		"hold": pixel_death_hold_after_death
	}
	return await effect.play(sprite, settings)


func _animate_death_and_remove(unit: Node2D, terminal: bool, victory: bool, message: String) -> void:
	# Камера фиксируется на погибающем до начала растворения.
	# BattleTurn откладывает переключение, если враг завершил ход в это время.
	if not is_instance_valid(unit):
		if terminal:
			_finish_battle_presentation(victory, message)
		return
	if _turn != null and _turn.has_method("begin_death_presentation"):
		_turn.call("begin_death_presentation", unit)

	# The tactical effect must not be consumed under the FightScene fade.
	var use_pixel_effect: bool = _is_enemy(unit) and pixel_death_enabled and pixel_death_use_on_tactical_map
	if use_pixel_effect:
		while is_inside_tree() and (get_tree().paused or has_meta("s7_fight_preview_closing")):
			await get_tree().process_frame
	if death_camera_arrival_delay > 0.0:
		await get_tree().create_timer(death_camera_arrival_delay, not use_pixel_effect).timeout
	if not is_instance_valid(unit):
		if _turn != null and _turn.has_method("end_death_presentation"):
			_turn.call("end_death_presentation")
		if terminal:
			_finish_battle_presentation(victory, message)
		return

	var sprite := unit.get_node_or_null("AnimatedSprite2D") as CanvasItem
	var visual: CanvasItem = sprite if sprite != null else unit as CanvasItem
	var pixel_played: bool = false
	if use_pixel_effect and sprite is AnimatedSprite2D:
		pixel_played = await play_enemy_pixel_death(sprite as AnimatedSprite2D, false)
	if not pixel_played and is_instance_valid(visual):
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
	# Отмечаем одноразовую встречу только после победы (не при поражении).
	if victory:
		var return_context: Node = get_node_or_null("/root/BattleReturnContext")
		if return_context != null and return_context.has_method("mark_current_encounter_victorious"):
			return_context.call("mark_current_encounter_victorious")
	battle_ended.emit(victory, message)
	if show_result_panel:
		_show_battle_result(victory, message)
	if victory and return_after_victory:
		if _has_return_destination():
			_auto_return_to_world()
		else:
			push_warning("BattleCombat: нет сохранённого места встречи и не назначена запасная сцена.")


func _show_battle_result(victory: bool, message: String) -> void:
	if _result_layer != null:
		return
	_result_layer = CanvasLayer.new()
	_result_layer.name = "BattleResultUI"
	_result_layer.layer = 100
	# Окно остаётся активным даже при остановке остальных боевых нод.
	_result_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_result_buttons.clear()
	_result_selected_index = 0
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
	if victory and show_return_button:
		var return_button := Button.new()
		return_button.text = "Вернуться на карту"
		return_button.disabled = not _has_return_destination()
		return_button.pressed.connect(_return_to_world)
		column.add_child(return_button)
		_result_buttons.append(return_button)
	if allow_retry:
		var retry := Button.new()
		retry.text = "Повторить битву"
		retry.pressed.connect(_retry_battle)
		column.add_child(retry)
		_result_buttons.append(retry)
	if not victory:
		var load_button := Button.new()
		load_button.text = "Загрузить сохранение (пока недоступно)"
		load_button.disabled = true
		load_button.tooltip_text = load_save_hint
		column.add_child(load_button)
		_result_buttons.append(load_button)
	# Блокируем курсор, BattleMove, BattleHover и остальные игровые обработчики ввода.
	# Обрабатываем клавиатуру только в окне результата.
	_result_previous_pause = get_tree().paused
	_result_previous_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_focus_result_button(0)


## W/A и S/D переключают пункт результата; E/Enter подтверждают выбор.
func _input(event: InputEvent) -> void:
	if _result_layer == null or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
	match key:
		KEY_W, KEY_A, KEY_UP, KEY_LEFT:
			get_viewport().set_input_as_handled()
			_focus_result_button(_result_selected_index - 1)
		KEY_S, KEY_D, KEY_DOWN, KEY_RIGHT:
			get_viewport().set_input_as_handled()
			_focus_result_button(_result_selected_index + 1)
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _result_selected_index >= 0 and _result_selected_index < _result_buttons.size():
				var selected_button: Button = _result_buttons[_result_selected_index]
				if is_instance_valid(selected_button) and not selected_button.disabled:
					selected_button.pressed.emit()


func _focus_result_button(requested_index: int) -> void:
	if _result_buttons.is_empty():
		return
	var count: int = _result_buttons.size()
	for step in range(count):
		var index: int = posmod(requested_index + step, count)
		var button: Button = _result_buttons[index]
		if is_instance_valid(button) and not button.disabled and button.visible:
			_result_selected_index = index
			button.grab_focus()
			return


func _resume_game_after_result() -> void:
	get_tree().paused = _result_previous_pause
	process_mode = _result_previous_process_mode




func _retry_battle() -> void:
	_resume_game_after_result()
	_restore_initial_hero_hp()
	get_tree().reload_current_scene()


## Автоматический переход после того, как игрок увидит окно победы.
func _auto_return_to_world() -> void:
	await get_tree().create_timer(victory_panel_duration).timeout
	if is_inside_tree() and _battle_finished and _battle_result:
		_return_to_world()


## Сначала возвращаемся в сохранённую точку встречи, иначе используем запасную сцену.
func _has_return_destination() -> bool:
	var context: Node = get_node_or_null("/root/BattleReturnContext")
	if context != null and bool(context.call("has_context")):
		return true
	return not victory_world_scene.is_empty()

## Переход после выбора пункта в окне победы: затемнение -> восстановление -> открытие.
## Пиксельный эффект создаётся в корне, чтобы не исчезнуть при смене карты.
func _return_to_world() -> void:
	if _return_transition_started:
		return
	if not _has_return_destination():
		push_warning("BattleCombat: не сохранена точка встречи и не назначена запасная сцена.")
		return
	_return_transition_started = true
	_perform_return_transition()


func _perform_return_transition() -> void:
	if not pixel_return_enabled:
		_resume_game_after_result()
		_change_to_saved_world()
		return

	var tree: SceneTree = get_tree()
	var transition: CanvasLayer = RETURN_PIXEL_TRANSITION.instantiate() as CanvasLayer
	if transition == null:
		push_error("BattleCombat: невозможно создать PixelTransition.")
		_return_transition_started = false
		return

	transition.layer = 120
	transition.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(transition)
	var cover: ColorRect = transition.get_node_or_null("Cover") as ColorRect
	if cover == null or not (cover.material is ShaderMaterial):
		push_error("BattleCombat: у PixelTransition нет Cover с ShaderMaterial.")
		transition.queue_free()
		_return_transition_started = false
		return

	var material: ShaderMaterial = cover.material.duplicate() as ShaderMaterial
	cover.material = material
	material.set_shader_parameter("pixel_size", pixel_return_size)
	material.set_shader_parameter("dissolve_color", pixel_return_color)
	material.set_shader_parameter("progress", 0.0)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP

	# Единственный Tween принадлежит SceneTree, а не удаляемой BattleCombat.
	# Он продолжит работать после change_scene_to_file().
	var duration: float = maxf(pixel_return_duration, 0.05)
	var sequence: Tween = tree.create_tween()
	sequence.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	sequence.tween_method(
		func(value: float) -> void: material.set_shader_parameter("progress", value),
		0.0, 1.0, duration
	)
	# ЭТОТ callback выполняется ДО удаления BattleCombat.
	sequence.tween_callback(_switch_world_under_pixel_cover)
	# После переключения сцены не обращаемся к self, get_tree() или _set_transition_progress.
	# CanvasLayer добавлен к root и переживает смену текущей сцены.
	sequence.tween_interval(0.12)
	sequence.tween_method(
		func(value: float) -> void: material.set_shader_parameter("progress", value),
		1.0, 0.0, duration
	)
	sequence.tween_callback(func() -> void: transition.queue_free())


## Вызывается один раз на закрытом экране, пока BattleCombat ещё существует.
func _switch_world_under_pixel_cover() -> void:
	_resume_game_after_result()
	var error: Error = _change_to_saved_world()
	if error != OK:
		push_error("BattleCombat: ошибка перехода на карту: %s" % str(error))
		_return_transition_started = false


## Меняет сцену ровно тем же способом, что и раньше, без потери точки встречи.
func _change_to_saved_world() -> Error:
	var context: Node = get_node_or_null("/root/BattleReturnContext")
	if context != null and context.has_method("has_context") and bool(context.call("has_context")):
		var result: Error = context.call("return_to_saved_world")
		return result
	if victory_world_scene.is_empty():
		push_warning("BattleCombat: не сохранена точка встречи и не назначена запасная сцена.")
		return ERR_DOES_NOT_EXIST
	if not ResourceLoader.exists(victory_world_scene):
		push_error("BattleCombat: сцена глобальной карты не найдена: " + victory_world_scene)
		return ERR_FILE_NOT_FOUND
	return get_tree().change_scene_to_file(victory_world_scene)


func _set_transition_progress(value: float, material: ShaderMaterial) -> void:
	material.set_shader_parameter("progress", value)
