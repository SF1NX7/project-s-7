extends Resource
class_name HeroGrowthProfile
## Настройки индивидуального роста героя. Каждый диапазон включителен.
## Пустое имя означает профиль по умолчанию (если назначен последним).
## Если подходящего этапа нет, используются исходные диапазоны ниже.

@export_group("Этапы развития")
@export var stages: Array[HeroGrowthStage] = []


@export_group("Герой")
@export var hero_name: String = ""

@export_group("Здоровье и мана")
@export_range(0, 100, 1) var hp_min: int = 1
@export_range(0, 100, 1) var hp_max: int = 3
@export_range(0, 100, 1) var mp_min: int = 0
@export_range(0, 100, 1) var mp_max: int = 1

@export_group("Атака и магия")
@export_range(0, 100, 1) var attack_min: int = 0
@export_range(0, 100, 1) var attack_max: int = 2
@export_range(0, 100, 1) var magic_min: int = 0
@export_range(0, 100, 1) var magic_max: int = 1

@export_group("Защита")
@export_range(0, 100, 1) var defense_min: int = 0
@export_range(0, 100, 1) var defense_max: int = 1
@export_range(0, 100, 1) var resistance_min: int = 0
@export_range(0, 100, 1) var resistance_max: int = 1

@export_group("Скорость и удача")
@export_range(0, 100, 1) var speed_min: int = 0
@export_range(0, 100, 1) var speed_max: int = 1
@export_range(0, 100, 1) var luck_min: int = 0
@export_range(0, 100, 1) var luck_max: int = 1


func roll_growth(rng: RandomNumberGenerator) -> Dictionary:
	var changes: Dictionary = {}
	for key in ["hp", "mp", "attack", "magic", "defense", "resistance", "speed", "luck"]:
		var lower: int = maxi(0, int(get(key + "_min")))
		var upper: int = maxi(lower, int(get(key + "_max")))
		var value: int = rng.randi_range(lower, upper)
		if value > 0:
			changes[key] = value
	return changes

## Возвращает активный этап для НОВОГО уровня героя.
## При равном Priority отдаёт предпочтение более позднему Start Level.
func stage_for(hero: Resource, reached_level: int) -> HeroGrowthStage:
	var best: HeroGrowthStage = null
	for stage in stages:
		if stage == null or not stage.matches(hero, reached_level):
			continue
		if best == null or stage.priority > best.priority or (stage.priority == best.priority and stage.start_level >= best.start_level):
			best = stage
	return best


func roll_growth_for_level(rng: RandomNumberGenerator, hero: Resource, reached_level: int) -> Dictionary:
	var active_stage: HeroGrowthStage = stage_for(hero, reached_level)
	if active_stage != null:
		return active_stage.roll_growth(rng, reached_level)
	## Backward compatible: use original min/max values if no stage matches.
	return roll_growth(rng)
