extends Resource
class_name DialogueVariant

# One conditional dialogue option for NPCDialogue.
# Put variants in NPCDialogue. The NPC chooses the FIRST variant whose condition matches.

enum ConditionType {
	NONE,
	FLAG_TRUE,
	FLAG_FALSE,
	HAS_ITEM,
	QUEST_STAGE_EQ,
	QUEST_STAGE_GTE,
	QUEST_STAGE_LTE
}

@export_group("Condition")
@export var condition_type: ConditionType = ConditionType.NONE

# Meaning depends on condition_type:
# FLAG_TRUE / FLAG_FALSE: flag key
# HAS_ITEM: ItemData.id, for example hp_small or helm_leather
# QUEST_STAGE_*: quest key
@export var key: String = ""

# Used only by QUEST_STAGE_* conditions.
@export var stage_value: int = 0

@export_group("Dialogue")
@export_multiline var lines: Array[String] = []

@export_group("Effects After This Variant Is Chosen")
@export var set_flags_true: Array[String] = []
@export var set_flags_false: Array[String] = []

# Same indexes:
# set_quest_keys[0] -> set_quest_values[0]
@export var set_quest_keys: Array[String] = []
@export var set_quest_values: Array[int] = []
