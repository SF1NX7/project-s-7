extends Node
class_name GameState

# GameState
# Autoload recommended:
#   Path: res://script/system/GameState.gd
#   Node Name: GameState
#
# Stores quest/story flags and quest stages.
# Your SaveManager saves/restores:
# - flags
# - quests

var flags: Dictionary = {}
var quests: Dictionary = {}


func _ready() -> void:
	add_to_group("game_state")


func get_flag(key: String, default_value: bool = false) -> bool:
	var k: String = key.strip_edges()
	if k == "":
		return default_value
	return bool(flags.get(k, default_value))


func set_flag(key: String, value: bool = true) -> void:
	var k: String = key.strip_edges()
	if k == "":
		return
	flags[k] = value


func clear_flag(key: String) -> void:
	var k: String = key.strip_edges()
	if k == "":
		return
	flags.erase(k)


func get_quest_stage(key: String, default_value: int = 0) -> int:
	var k: String = key.strip_edges()
	if k == "":
		return default_value
	return int(quests.get(k, default_value))


func set_quest_stage(key: String, value: int) -> void:
	var k: String = key.strip_edges()
	if k == "":
		return
	quests[k] = value


func reset_all() -> void:
	flags.clear()
	quests.clear()
