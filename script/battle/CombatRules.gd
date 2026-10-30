@tool
extends Resource
class_name CombatRules
## Shared combat balance. Assign in BattleCombat Inspector.

@export_group("Physical Damage")
@export_range(0, 100, 1) var minimum_damage: int = 1
@export_range(0.0, 10.0, 0.05) var physical_multiplier: float = 1.0
@export_range(0.0, 100.0, 1.0) var damage_variation_percent: float = 0.0

@export_group("Safety")
@export var clamp_damage_to_remaining_hp: bool = true

@export_group("Debug")
@export var print_damage_to_output: bool = true
