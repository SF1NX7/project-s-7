extends Resource
class_name ItemUseEffect

@export_group("Consume")
@export var consume_on_use: bool = true

@export_group("Restore")
@export var hp_restore: int = 0
@export var mp_restore: int = 0

@export_group("Other")
@export var xp_gain: int = 0
@export var gold_gain: int = 0

@export_group("Info")
@export_multiline var use_message: String = ""
