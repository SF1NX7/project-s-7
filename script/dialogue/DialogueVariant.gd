extends Resource
class_name DialogueVariant

# One conditional variant of dialogue.
# NPC will pick the FIRST variant whose condition is met.

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
# Key for flags/quests/items (examples: "met_old_man", "quest_bandits", "item_key_01")
@export var key: String = ""
# Used for QUEST_STAGE_* comparisons
@export var stage_value: int = 0

@export_group("Dialogue")
@export_multiline var lines: Array[String] = []

@export_group("On Select (optional changes)")
# These are optional and you can ignore them for now.
@export var set_flags_true: Array[String] = []
@export var set_flags_false: Array[String] = []
# Set quest stage exactly (key -> value) by parallel arrays (simple inspector-friendly)
@export var set_quest_keys: Array[String] = []
@export var set_quest_values: Array[int] = []
