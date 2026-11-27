@tool
extends Resource
class_name HeroGrowthStage

## Этап развития одного героя. Значения прироста применяются при достижении нового уровня.
## Все сохранённые поля прежних карточек сохранены для совместимости.

enum Condition { LEVEL, CLASS, STORY_FLAG, LEVEL_AND_CLASS, LEVEL_AND_STORY_FLAG }

@export_group("01. Когда действует этап")
@export var enabled: bool = true
@export var display_name: String = "Новый этап"
@export_enum("По уровню", "По классу", "По сюжетному событию", "Уровень и класс", "Уровень и событие") var condition: int = Condition.LEVEL:
	set(value):
		condition = value
		if Engine.is_editor_hint():
			notify_property_list_changed()

@export_range(1, 999, 1) var start_level: int = 1
## 0 означает, что этап действует до максимального уровня.
@export_range(0, 999, 1) var end_level: int = 0

@export_group("02. МАНА — прирост за уровень")
## Например 1 и 2 означают случайный прирост от 1 до 2 MP каждый уровень.
@export_range(0, 100, 1) var mp_min: int = 0
@export_range(0, 100, 1) var mp_max: int = 1

@export_group("03. МАНА — постепенное ускорение")
## Необязательно. Позволяет постепенно увеличивать оба значения MP Min/Max.
@export var mp_acceleration_enabled: bool = false:
	set(value):
		mp_acceleration_enabled = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Раз в сколько достигнутых уровней увеличивать прирост MP.
@export_range(1, 100, 1) var mp_every_levels: int = 5
## На сколько увеличивать нижнюю и верхнюю границы прироста за каждый шаг.
@export_range(0, 100, 1) var mp_add_per_step: int = 1
## Максимальный добавочный MP за уровень. 0 = без лимита.
@export_range(0, 100, 1) var mp_max_extra: int = 4

@export_group("04. Здоровье — прирост за уровень")
@export_range(0, 100, 1) var hp_min: int = 1
@export_range(0, 100, 1) var hp_max: int = 3

@export_group("05. Атака и магия — прирост")
@export_range(0, 100, 1) var attack_min: int = 0
@export_range(0, 100, 1) var attack_max: int = 2
@export_range(0, 100, 1) var magic_min: int = 0
@export_range(0, 100, 1) var magic_max: int = 1

@export_group("06. Защита — прирост")
@export_range(0, 100, 1) var defense_min: int = 0
@export_range(0, 100, 1) var defense_max: int = 1
@export_range(0, 100, 1) var resistance_min: int = 0
@export_range(0, 100, 1) var resistance_max: int = 1

@export_group("07. Скорость и удача — прирост")
@export_range(0, 100, 1) var speed_min: int = 0
@export_range(0, 100, 1) var speed_max: int = 1
@export_range(0, 100, 1) var luck_min: int = 0
@export_range(0, 100, 1) var luck_max: int = 1

@export_group("08. Дополнительно — класс, сюжет, приоритет")
## Для класса: точное совпадение с HeroData.profession_name.
@export var required_class: String = ""
## Для сюжета: флаг из временных метаданных героя (интеграция сюжетных флагов позже).
@export var required_story_flag: StringName = &""
## При совпадении двух этапов приоритет имеет этап с большим числом.
@export_range(-1000, 1000, 1) var priority: int = 0


func _validate_property(property: Dictionary) -> void:
	## Не показываем опции, которые не относятся к выбранному условию этапа.
	var name: String = String(property.get("name", ""))
	var class_needed: bool = condition == Condition.CLASS or condition == Condition.LEVEL_AND_CLASS
	var flag_needed: bool = condition == Condition.STORY_FLAG or condition == Condition.LEVEL_AND_STORY_FLAG
	var acceleration_option: bool = name == "mp_every_levels" or name == "mp_add_per_step" or name == "mp_max_extra"
	if (name == "required_class" and not class_needed) or (name == "required_story_flag" and not flag_needed) or (acceleration_option and not mp_acceleration_enabled):
		## Убираем из Inspector, но сохраняем значение в .tres.
		property["usage"] = int(property["usage"]) & ~PROPERTY_USAGE_EDITOR


func matches(hero: Resource, reached_level: int) -> bool:
	if not enabled or reached_level < start_level:
		return false
	if end_level > 0 and reached_level > end_level:
		return false
	if condition == Condition.CLASS or condition == Condition.LEVEL_AND_CLASS:
		if hero == null or required_class.is_empty():
			return false
		if str(hero.get("profession_name")) != required_class:
			return false
	if condition == Condition.STORY_FLAG or condition == Condition.LEVEL_AND_STORY_FLAG:
		if hero == null or String(required_story_flag).is_empty():
			return false
		var flags: Variant = hero.get_meta("s7_story_flags", {})
		if flags is Dictionary:
			if not bool(flags.get(required_story_flag, false)):
				return false
		elif flags is Array:
			if not flags.has(required_story_flag) and not flags.has(String(required_story_flag)):
				return false
		else:
			return false
	return true


func roll_growth(rng: RandomNumberGenerator, reached_level: int = -1) -> Dictionary:
	var changes: Dictionary = {}
	var bonus_mp: int = 0
	if mp_acceleration_enabled and reached_level >= start_level:
		var steps: int = floori(float(reached_level - start_level) / float(maxi(1, mp_every_levels)))
		bonus_mp = steps * maxi(0, mp_add_per_step)
		if mp_max_extra > 0:
			bonus_mp = mini(bonus_mp, mp_max_extra)
	for key in ["hp", "mp", "attack", "magic", "defense", "resistance", "speed", "luck"]:
		var lower: int = maxi(0, int(get(key + "_min")))
		var upper: int = maxi(lower, int(get(key + "_max")))
		if key == "mp":
			lower += bonus_mp
			upper += bonus_mp
		var value: int = rng.randi_range(lower, upper)
		if value > 0:
			changes[key] = value
	return changes
