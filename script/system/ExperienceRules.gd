@tool
extends Resource
class_name ExperienceRules

## Central rules for HERO experience. XP is per hero, and carries over on level-up.

@export_group("Experience: Actions")
@export_range(0, 10000, 1) var xp_per_hit: int = 1
@export_range(0, 10000, 1) var xp_per_dodge: int = 1
@export_range(0, 10000, 1) var xp_per_counter: int = 1
@export_range(0, 10000, 1) var xp_per_heal: int = 1
## +1 XP per this amount of actual damage, up to the cap.
@export_range(1, 9999, 1) var damage_per_bonus_xp: int = 5
@export_range(0, 1000, 1) var max_damage_bonus_xp: int = 3
## +1 XP per this amount of actually restored HP.
@export_range(1, 9999, 1) var healing_per_bonus_xp: int = 10
@export_range(0, 1000, 1) var max_healing_bonus_xp: int = 3
@export var use_enemy_kill_experience: bool = true

@export_group("Level Up")
## Needed XP to go from level 1 to level 2.
@export_range(1, 1000000, 1) var level_one_requirement: int = 100
## Example: 1.20 = 20% more XP for each next level.
@export_range(1.0, 4.0, 0.01) var requirement_growth: float = 1.20
@export_range(2, 999, 1) var maximum_level: int = 99
@export var carry_over_experience: bool = true

@export_group("Level Difference: XP Multiplier")
@export var scale_xp_by_level_difference: bool = true
## When enemy is stronger, XP is boosted per level difference.
@export_range(0.0, 1.0, 0.05) var bonus_per_stronger_level: float = 0.15
@export_range(1.0, 5.0, 0.05) var maximum_stronger_multiplier: float = 1.75
## When enemy is weaker, XP decreases by this factor per level.
@export_range(0.0, 1.0, 0.05) var weaker_level_factor: float = 0.75
## After this many level differences, XP can become zero.
@export_range(0, 99, 1) var zero_xp_if_enemy_weaker_by: int = 6
## 0 allows truly trivial enemies to yield no XP.
@export_range(0, 1000, 1) var minimum_scaled_xp: int = 0

@export_group("Level Up: Debug")
@export var print_level_ups: bool = true


func xp_requirement_for_level(level: int) -> int:
	var level_index: int = maxi(0, level - 1)
	return maxi(1, roundi(float(level_one_requirement) * pow(requirement_growth, level_index)))


func xp_multiplier(hero_level: int, enemy_level: int) -> float:
	if not scale_xp_by_level_difference:
		return 1.0
	var difference: int = enemy_level - hero_level
	if difference >= 0:
		return minf(maximum_stronger_multiplier, 1.0 + float(difference) * bonus_per_stronger_level)
	if -difference >= zero_xp_if_enemy_weaker_by and zero_xp_if_enemy_weaker_by > 0:
		return 0.0
	return pow(weaker_level_factor, -difference)


func scaled_xp(raw_xp: int, hero_level: int, enemy_level: int) -> int:
	if raw_xp <= 0:
		return 0
	return maxi(minimum_scaled_xp, roundi(float(raw_xp) * xp_multiplier(hero_level, enemy_level)))


func xp_for_hit(actual_damage: int, hero_level: int, enemy_level: int, counter: bool = false) -> int:
	if actual_damage <= 0:
		return 0
	var bonus: int = mini(max_damage_bonus_xp, floori(float(actual_damage) / float(damage_per_bonus_xp)))
	var raw: int = xp_per_hit + bonus
	if counter:
		raw += xp_per_counter
	return scaled_xp(raw, hero_level, enemy_level)


func xp_for_dodge(hero_level: int, enemy_level: int) -> int:
	return scaled_xp(xp_per_dodge, hero_level, enemy_level)


func xp_for_kill(enemy_experience: int, hero_level: int, enemy_level: int) -> int:
	if not use_enemy_kill_experience:
		return 0
	return scaled_xp(enemy_experience, hero_level, enemy_level)


func xp_for_healing(actual_healed: int, hero_level: int, reference_level: int) -> int:
	if actual_healed <= 0:
		return 0
	var bonus: int = mini(max_healing_bonus_xp, floori(float(actual_healed) / float(healing_per_bonus_xp)))
	return scaled_xp(xp_per_heal + bonus, hero_level, reference_level)


func grant_experience(hero: Resource, amount: int) -> int:
	## Returns number of levels gained. HeroData already contains level, xp, xp_to_next.
	if hero == null or amount <= 0:
		return 0
	var current_level: int = maxi(1, int(hero.get("level")))
	if current_level >= maximum_level:
		return 0
	var current_xp: int = maxi(0, int(hero.get("xp"))) + amount
	var threshold: int = xp_requirement_for_level(current_level)
	var levels_gained: int = 0
	while current_level < maximum_level and current_xp >= threshold:
		if carry_over_experience:
			current_xp -= threshold
		else:
			current_xp = 0
		current_level += 1
		levels_gained += 1
		threshold = xp_requirement_for_level(current_level)
	if current_level >= maximum_level:
		current_xp = 0
	hero.set("level", current_level)
	hero.set("xp", current_xp)
	hero.set("xp_to_next", threshold)
	if levels_gained > 0 and print_level_ups:
		print("S7 LEVEL UP: ", hero.get("hero_name"), " +", levels_gained, " -> Lv.", current_level)
	return levels_gained
