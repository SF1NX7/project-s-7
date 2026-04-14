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

@export_group("Numbers (optional)")
@export var power: int = 0
@export var accuracy: int = 100
@export var range_tiles: int = 0
@export var area_radius: int = 0
