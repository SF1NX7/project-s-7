extends Resource
class_name NPCDialogue

# A pack of dialogue variants for a single NPC.
# In NPC inspector you will assign ONE .tres of this type.

@export_group("Identity")
@export var npc_id: String = "" # optional unique id (e.g. "old_man_01")

@export_group("Variants (top = highest priority)")
@export var variants: Array[DialogueVariant] = []

@export_group("Fallback")
@export_multiline var default_lines: Array[String] = [
	"Привет."
]
