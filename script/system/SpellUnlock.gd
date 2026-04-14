extends Resource
class_name SpellUnlock
# One slot in a branch: what spell + unlock requirements.

@export var enabled: bool = true
@export var spell: SpellData
@export var required_level: int = 1

# Optional special conditions (not enforced yet unless you wire them later).
@export var required_item_id: String = ""
@export var required_flag: String = ""
