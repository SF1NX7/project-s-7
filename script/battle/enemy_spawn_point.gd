@tool
extends Marker2D
class_name EnemySpawnPoint
## Configure an individual enemy spawn marker.

@export_group("Enemy Spawn Settings")
@export var spawn_enabled: bool = true
@export var enemy_id: StringName = &"goblin"
## Optional direct enemy card. When empty, Enemy ID is resolved in the catalog.
@export var enemy_data: EnemyData
