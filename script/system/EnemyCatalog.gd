@tool
extends Resource
class_name EnemyCatalog
## Central inspector-editable enemy archetype catalog.
@export var enemies: Array[EnemyData] = []


func find_enemy(enemy_id: StringName) -> EnemyData:
	for entry in enemies:
		if entry != null and entry.enemy_id == enemy_id:
			return entry
	return null
