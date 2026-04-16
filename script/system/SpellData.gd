extends Resource
class_name SpellData
# One spell definition (create .tres resources from this).

enum Element {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	EARTH,
	WIND,
	WATER,
	LIGHT,
	DARK,
}

enum EffectType {
	DAMAGE,
	HEAL,
	BUFF,
	DEBUFF,
	REVIVE,
	UTILITY,
}

@export_group("Identity")
@export var id: String = ""
@export var title: String = "Spell"
@export_multiline var description: String = ""

@export_group("Visual")
@export var icon: Texture2D

@export_group("Rules")
@export var element: Element = Element.NONE
@export var effect_type: EffectType = EffectType.DAMAGE
@export var mp_cost: int = 0

@export_group("Numbers")
# For DAMAGE spells you can use damage_min/max.
# For HEAL spells you can use heal_min/max (optional).
@export var damage_min: int = 0
@export var damage_max: int = 0

@export var heal_min: int = 0
@export var heal_max: int = 0

@export var accuracy: int = 100
@export var range_tiles: int = 0
@export var area_radius: int = 0

func get_damage_roll(rng: RandomNumberGenerator) -> int:
	if damage_max <= damage_min:
		return max(damage_min, 0)
	return rng.randi_range(max(damage_min, 0), max(damage_max, 0))

func get_heal_roll(rng: RandomNumberGenerator) -> int:
	if heal_max <= heal_min:
		return max(heal_min, 0)
	return rng.randi_range(max(heal_min, 0), max(heal_max, 0))
