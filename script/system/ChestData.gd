extends Resource
class_name ChestData

@export_group("Contents")
@export var items: Array[ItemData] = []
@export var gold: int = 0

@export_group("Behavior")
@export var one_time: bool = true
@export var chest_id: String = ""
