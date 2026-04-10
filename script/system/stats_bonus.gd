extends Resource
class_name StatsBonus
# Simple "table" of bonuses editable in Inspector.
# Keep it small at first; you can add more fields later.

@export_group("Primary")
@export var hp: int = 0
@export var mp: int = 0

@export_group("Offense")
@export var attack: int = 0
@export var magic: int = 0

@export_group("Defense")
@export var defense: int = 0
@export var resistance: int = 0

@export_group("Utility")
@export var speed: int = 0
@export var luck: int = 0


func is_zero() -> bool:
	return hp == 0 and mp == 0 and attack == 0 and magic == 0 and defense == 0 and resistance == 0 and speed == 0 and luck == 0


func add(other: StatsBonus) -> StatsBonus:
	# Returns a NEW resource with summed values (doesn't mutate inputs).
	var out := StatsBonus.new()
	if other == null:
		out.hp = hp
		out.mp = mp
		out.attack = attack
		out.magic = magic
		out.defense = defense
		out.resistance = resistance
		out.speed = speed
		out.luck = luck
		return out

	out.hp = hp + other.hp
	out.mp = mp + other.mp
	out.attack = attack + other.attack
	out.magic = magic + other.magic
	out.defense = defense + other.defense
	out.resistance = resistance + other.resistance
	out.speed = speed + other.speed
	out.luck = luck + other.luck
	return out
