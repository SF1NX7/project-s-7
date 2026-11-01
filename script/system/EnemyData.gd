@tool
extends Resource
class_name EnemyData
## One enemy archetype. Set everything in Inspector.

enum AIStyle { AGGRESSIVE, DEFENSIVE, PASSIVE, RANGED, SUPPORT }

@export_group("Identity")
@export var enemy_id: StringName = &"goblin"
@export var display_name: String = "Гоблин"
@export var scene: PackedScene
@export var portrait: Texture2D

@export_group("Base Stats")
@export_range(1, 9999, 1) var max_hp: int = 8
@export_range(0, 9999, 1) var max_mp: int = 0
@export_range(0, 999, 1) var attack: int = 3
@export_range(0, 999, 1) var defense: int = 1
@export_range(0, 999, 1) var speed: int = 1
@export_range(0, 999, 1) var magic: int = 0
@export_range(0, 999, 1) var resistance: int = 0
@export_range(0, 999, 1) var luck: int = 0

@export_group("Tactical Movement")
@export_range(0, 24, 1) var base_movement: int = 4
@export_range(-24, 24, 1) var movement_modifier: int = 0

@export_group("Artificial Intelligence")
@export var ai_style: AIStyle = AIStyle.AGGRESSIVE
@export var ai_profile: EnemyAIProfile
@export_range(0, 30, 1) var detection_range: int = 8
@export_range(1, 20, 1) var attack_range: int = 1
@export_range(0, 30, 1) var leash_range: int = 8

@export_group("Rewards")
@export_range(0, 999999, 1) var experience: int = 5
@export_range(0, 999999, 1) var gold: int = 2

@export_group("Future Drops")
@export var drop_item: Resource
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.0


func get_movement() -> int:
	return maxi(0, base_movement + movement_modifier)
