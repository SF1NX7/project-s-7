extends Resource
class_name MagicBranch
# One column/branch. Meaning is per-hero (Fire/Heal/Buff/etc).

@export_group("Branch")
@export var branch_name: String = "Branch"
@export var branch_icon: Texture2D
@export_multiline var branch_note: String = ""

@export_group("Levels (1..4)")
@export var levels: Array[SpellUnlock] = []
