@tool
extends Resource
class_name EnemyDropEntry

## An independent item roll in an enemy card.
@export_group("Item Drop")
@export var item: Resource
@export_range(0.0, 1.0, 0.01) var chance: float = 0.25
@export_range(1, 99, 1) var minimum_amount: int = 1
@export_range(1, 99, 1) var maximum_amount: int = 1
