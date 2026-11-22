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

@export_group("Magic Visual Effects")
@export var projectile_sheet: Texture2D
@export_range(1, 64, 1) var projectile_frames: int = 4
@export_range(1.0, 60.0, 0.5) var projectile_fps: float = 12.0
@export var impact_sheet: Texture2D
@export_range(1, 64, 1) var impact_frames: int = 4
@export_range(1.0, 60.0, 0.5) var impact_fps: float = 10.0
@export_enum("Projectile", "Target Effect", "Falling", "Full Screen") var visual_mode: int = 0
@export_range(0.1, 8.0, 0.1) var projectile_scale: float = 1.0
@export_range(0.1, 8.0, 0.1) var impact_scale: float = 1.0
@export_range(20.0, 1500.0, 10.0) var projectile_speed: float = 200.0
@export_range(0.0, 150.0, 1.0) var wave_amplitude: float = 12.0
@export_range(0.0, 8.0, 0.5) var wave_count: float = 2.0
@export_range(0.0, 150.0, 1.0) var arc_height: float = 10.0
@export var rotate_along_path: bool = false
@export var cast_offset: Vector2 = Vector2(20, 0)
@export var impact_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 0.9, 0.05) var screen_darkness: float = 0.4
@export_range(0.05, 2.0, 0.05) var darken_duration: float = 0.25
@export_range(0.05, 2.0, 0.05) var target_slide_duration: float = 0.35

func get_damage_roll(rng: RandomNumberGenerator) -> int:
	if damage_max <= damage_min:
		return max(damage_min, 0)
	return rng.randi_range(max(damage_min, 0), max(damage_max, 0))

func get_heal_roll(rng: RandomNumberGenerator) -> int:
	if heal_max <= heal_min:
		return max(heal_min, 0)
	return rng.randi_range(max(heal_min, 0), max(heal_max, 0))
