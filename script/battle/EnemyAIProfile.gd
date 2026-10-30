@tool
extends Resource
class_name EnemyAIProfile
## Configuration only. Runtime memory lives in BattleEnemyAI, never in this resource.

enum Behavior { SENTRY, PATROL, AGGRESSIVE, PURSUER, TACTICAL }
enum Intelligence { BASIC, TACTICAL, ADVANCED, ELITE }

@export_group("Decision Making")
@export var behavior: Behavior = Behavior.PATROL
@export var intelligence_level: Intelligence = Intelligence.BASIC
@export_range(0.0, 1.0, 0.05) var randomness: float = 0.10

@export_group("Vision And Territory")
@export_range(0, 32, 1) var detection_range: int = 8
@export_range(1, 32, 1) var attack_range: int = 1
@export_range(0, 40, 1) var leash_range: int = 10

@export_group("Patrol")
@export_range(0, 15, 1) var patrol_radius: int = 3
@export_range(0, 24, 1) var patrol_max_steps: int = 3
@export_range(0.0, 1.0, 0.05) var patrol_move_chance: float = 0.75
@export var return_to_post: bool = true

@export_group("Aggro Memory")
@export var remember_attacker: bool = true
@export_range(0, 20, 1) var memory_turns: int = 3
@export_range(0, 40, 1) var pursuit_range: int = 14
@export var retarget_on_hit: bool = true

@export_group("Target Priorities")
@export_range(0.0, 10.0, 0.1) var low_hp_weight: float = 3.0
@export_range(0.0, 10.0, 0.1) var threat_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var distance_weight: float = 1.0

@export_group("Debug")
@export var print_decisions: bool = false
